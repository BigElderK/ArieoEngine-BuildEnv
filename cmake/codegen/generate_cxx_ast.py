#!/usr/bin/env python3
"""
Generate C++ AST JSON using clang and post-process to extract annotation strings.
This script runs clang to generate AST JSON, then parses the source file to extract
annotation text from METADATA() macros at the locations indicated by AnnotateAttr nodes.
"""

import json
import os
import sys
import subprocess
import re
import hashlib
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple


# Type conversion table from C++ native types to other languages
TYPE_CONVERSION_TABLE = {
    # Integer types
    "std::int8_t": {"csharp": "sbyte", "rust": "i8"},
    "std::uint8_t": {"csharp": "byte", "rust": "u8"},
    "std::int16_t": {"csharp": "Int16", "rust": "i16"},
    "std::uint16_t": {"csharp": "UInt16", "rust": "u16"},
    "std::int32_t": {"csharp": "Int32", "rust": "i32"},
    "std::uint32_t": {"csharp": "UInt32", "rust": "u32"},
    "std::int64_t": {"csharp": "Int64", "rust": "i64"},
    "std::uint64_t": {"csharp": "UInt64", "rust": "u64"},
    "int": {"csharp": "int", "rust": "i32"},
    "unsigned int": {"csharp": "uint", "rust": "u32"},
    "long": {"csharp": "long", "rust": "i64"},
    "unsigned long": {"csharp": "ulong", "rust": "u64"},
    "long long": {"csharp": "long", "rust": "i64"},
    "unsigned long long": {"csharp": "ulong", "rust": "u64"},
    "short": {"csharp": "short", "rust": "i16"},
    "unsigned short": {"csharp": "ushort", "rust": "u16"},
    "char": {"csharp": "sbyte", "rust": "i8"},
    "unsigned char": {"csharp": "byte", "rust": "u8"},
    
    # Floating point types
    "float": {"csharp": "float", "rust": "f32"},
    "double": {"csharp": "double", "rust": "f64"},
    
    # Boolean type
    "bool": {"csharp": "bool", "rust": "bool"},
    
    # Size types
    "size_t": {"csharp": "ulong", "rust": "usize"},
    "std::size_t": {"csharp": "ulong", "rust": "usize"},
    
    # Void type
    "void": {"csharp": "void", "rust": "()"},
}


def convert_type_to_target_language(native_type: str, target_language: str) -> str:
    """
    Convert C++ native type to target language type.
    
    Args:
        native_type: C++ type (e.g., "std::int32_t")
        target_language: Target language ("csharp" or "rust")
    
    Returns:
        Converted type or the original type if no mapping exists
    """
    if native_type in TYPE_CONVERSION_TABLE:
        return TYPE_CONVERSION_TABLE[native_type].get(target_language, native_type)
    return native_type


def convert_function_name_to_wit_format(name: str) -> str:
    """
    Convert function name to WASM WIT format.
    Removes underscores and adds dashes before uppercase letters.
    
    Args:
        name: Function name (e.g., "DoSomething1")
    
    Returns:
        WIT format name (e.g., "do-something1")
    """
    result = []
    
    for i, ch in enumerate(name):
        # Skip underscores
        if ch == '_':
            continue
        
        # Add dash before uppercase letters (except at the start)
        if ch.isupper() and result:
            result.append('-')
        
        # Convert to lowercase and add
        result.append(ch.lower())
    
    return ''.join(result)


def convert_wit_to_cxx_namespace(wit_full_name: str) -> str:
    """
    Convert WIT format to C++ namespace format.
    Example: "arieo:sample/i-sample" -> "arieo::sample::i_sample"
    
    Args:
        wit_full_name: WIT format name (e.g., "arieo:sample/i-sample")
    
    Returns:
        C++ namespace format (e.g., "arieo::sample::i_sample")
    """
    # Replace ':' and '/' with '::'
    result = wit_full_name.replace(':', '::').replace('/', '::')
    # Replace dashes with underscores
    result = result.replace('-', '_')
    return result


def convert_wit_to_cxx_function_name(wit_function_name: str) -> str:
    """
    Convert WIT format function name to C++ PascalCase format.
    Example: "do-somthing1" -> "DoSomthing1"
    
    Args:
        wit_function_name: WIT format function name (e.g., "do-somthing1")
    
    Returns:
        C++ PascalCase function name (e.g., "DoSomthing1")
    """
    # Split by dash
    parts = wit_function_name.split('-')
    # Capitalize first letter of each part and join
    result = ''.join(part.capitalize() for part in parts)
    return result


def convert_wit_to_cxx_script_full_interface_name(wit_full_interface_name: str) -> str:
    """
    Convert WIT full interface name to C++ script format with :: prefix.
    Example: "arieo:sample/i-sample" -> "::arieo::sample::i_sample"
    
    Args:
        wit_full_interface_name: WIT format name (e.g., "arieo:sample/i-sample")
    
    Returns:
        C++ script format with :: prefix (e.g., "::arieo::sample::i_sample")
    """
    # Replace ':' and '/' with '::'
    result = wit_full_interface_name.replace(':', '::').replace('/', '::')
    # Replace dashes with underscores
    result = result.replace('-', '_')
    # Add :: prefix
    if not result.startswith('::'):
        result = '::' + result
    return result


def convert_wit_to_csharp_full_interface_name(wit_full_interface_name: str) -> str:
    """
    Convert WIT full interface name to C# format.
    Example: "arieo:sample/i-sample" -> "ApplicationWorld.wit.imports.arieo.sample.ISampleInterop"
    
    Args:
        wit_full_interface_name: WIT format name (e.g., "arieo:sample/i-sample")
    
    Returns:
        C# format (e.g., "ApplicationWorld.wit.imports.arieo.sample.ISampleInterop")
    """
    # Split by '/'
    parts = wit_full_interface_name.split('/')
    if len(parts) != 2:
        return wit_full_interface_name
    
    # First part: replace ':' with '.'
    namespace_part = parts[0].replace(':', '.')
    
    # Second part: convert to PascalCase and add "Interop" suffix
    interface_part = parts[1]
    # Split by dash and capitalize each part
    interface_name_parts = interface_part.split('-')
    interface_name = ''.join(part.capitalize() for part in interface_name_parts)
    interface_name += 'Interop'
    
    # Combine with prefix
    result = f"ApplicationWorld.wit.imports.{namespace_part}.{interface_name}"
    return result


def convert_wit_to_rust_full_interface_name(wit_full_interface_name: str) -> str:
    """
    Convert WIT full interface name to Rust format.
    Example: "arieo:sample/i-sample" -> "crate::arieo::sample::i_sample"
    
    Args:
        wit_full_interface_name: WIT format name (e.g., "arieo:sample/i-sample")
    
    Returns:
        Rust format (e.g., "crate::arieo::sample::i_sample")
    """
    # Replace ':' and '/' with '::'
    result = wit_full_interface_name.replace(':', '::').replace('/', '::')
    # Replace dashes with underscores
    result = result.replace('-', '_')
    # Add crate:: prefix
    if not result.startswith('crate::'):
        result = 'crate::' + result
    return result


def convert_wit_to_rust_function_name(wit_function_name: str) -> str:
    """
    Convert WIT format function name to Rust snake_case format.
    Example: "do-somthing1" -> "do_somthing1"
    
    Args:
        wit_function_name: WIT format function name (e.g., "do-somthing1")
    
    Returns:
        Rust snake_case function name (e.g., "do_somthing1")
    """
    # Replace dashes with underscores and ensure lowercase
    result = wit_function_name.replace('-', '_').lower()
    return result


def convert_package_name_to_cxx_namespace(package_name: str) -> str:
    """
    Convert WIT package name to C++ namespace format.
    Example: "arieo:sample" -> "::arieo::sample"
    
    Args:
        package_name: WIT package name (e.g., "arieo:sample")
    
    Returns:
        C++ namespace format (e.g., "::arieo::sample")
    """
    # Replace ':' with '::'
    result = package_name.replace(':', '::')
    # Add :: prefix
    if not result.startswith('::'):
        result = '::' + result
    return result


def convert_package_name_to_csharp_namespace(package_name: str) -> str:
    """
    Convert WIT package name to C# namespace format.
    Example: "arieo:sample" -> "ApplicationWorld.wit.imports.arieo.sample"
    
    Args:
        package_name: WIT package name (e.g., "arieo:sample")
    
    Returns:
        C# namespace format (e.g., "ApplicationWorld.wit.imports.arieo.sample")
    """
    # Replace ':' with '.'
    namespace_part = package_name.replace(':', '.')
    # Add prefix
    result = f"ApplicationWorld.wit.imports.{namespace_part}"
    return result


def convert_package_name_to_rust_namespace(package_name: str) -> str:
    """
    Convert WIT package name to Rust namespace format.
    Example: "arieo:sample" -> "crate::arieo::sample"
    
    Args:
        package_name: WIT package name (e.g., "arieo:sample")
    
    Returns:
        Rust namespace format (e.g., "crate::arieo::sample")
    """
    # Replace ':' with '::'
    result = package_name.replace(':', '::')
    # Add crate:: prefix
    if not result.startswith('crate::'):
        result = 'crate::' + result
    return result


def convert_method_name_to_rust_snake_case(method_name: str) -> str:
    """
    Convert C++ method name to Rust snake_case format.
    Handles mixed case like "doSomthing_1" -> "do_somthing_1"
    
    Args:
        method_name: C++ method name (e.g., "doSomthing_1")
    
    Returns:
        Rust snake_case method name (e.g., "do_somthing_1")
    """
    import re
    # Insert underscore before uppercase letters that follow lowercase letters
    result = re.sub(r'([a-z])([A-Z])', r'\1_\2', method_name)
    # Convert to lowercase
    result = result.lower()
    return result


def convert_interface_name_to_wit_format(package_name: str, interface_name: str) -> str:
    """
    Convert interface name to WASM WIT format.
    Returns package_name/interface_name format (e.g., "arieo:sample/i-sample")
    
    Args:
        package_name: Package name (e.g., "arieo:sample")
        interface_name: Interface name (e.g., "ISample")
    
    Returns:
        WIT format interface path (e.g., "arieo:sample/i-sample")
    """
    result = []
    
    # Add package_name as-is (no processing)
    result.append(package_name)
    
    # Add separator
    result.append('/')
    
    # Process interface_name
    # Convert to lowercase with dashes before uppercase letters
    for i, ch in enumerate(interface_name):
        # Skip underscores
        if ch == '_':
            continue
        
        # Add dash before uppercase letters (except right after the separator)
        if ch.isupper() and result and result[-1] != '/':
            result.append('-')
        
        # Convert to lowercase and add
        result.append(ch.lower())
    
    return ''.join(result)


def calculate_function_checksum(func_name: str, parameters: List[Tuple[str, str]]) -> int:
    """
    Calculate 64-bit checksum for a function based on its signature.
    
    Args:
        func_name: Name of the function
        parameters: List of (param_type, param_name) tuples
    
    Returns:
        64-bit integer checksum
    """
    # Build signature string: function_name(param1_type:param1_name, param2_type:param2_name, ...)
    signature_parts = [func_name, "("]
    
    for i, (param_type, param_name) in enumerate(parameters):
        if i > 0:
            signature_parts.append(", ")
        signature_parts.append(f"{param_type}:{param_name}")
    
    signature_parts.append(")")
    signature = "".join(signature_parts)
    
    # Calculate 64-bit hash using SHA256 (deterministic, first 8 bytes)
    hash_bytes = hashlib.sha256(signature.encode('utf-8')).digest()[:8]
    return int.from_bytes(hash_bytes, byteorder='little', signed=False)


def calculate_interface_checksum(interface_name: str, function_checksums: List[int]) -> int:
    """
    Calculate 64-bit checksum for an interface based on its name and function checksums.
    
    Args:
        interface_name: Name of the interface
        function_checksums: List of function checksums (sorted for consistency)
    
    Returns:
        64-bit integer checksum
    """
    # Sort function checksums to ensure consistent ordering
    sorted_checksums = sorted(function_checksums)
    
    # Build interface signature: interface_name{checksum1,checksum2,...}
    signature = f"{interface_name}{{{','.join(str(c) for c in sorted_checksums)}}}"
    
    # Calculate 64-bit hash using SHA256 (deterministic, first 8 bytes)
    hash_bytes = hashlib.sha256(signature.encode('utf-8')).digest()[:8]
    return int.from_bytes(hash_bytes, byteorder='little', signed=False)


def calculate_name_hash(name: str) -> int:
    """
    Calculate 64-bit hash for a fully qualified name.
    
    Args:
        name: Fully qualified name (e.g., "::Arieo::Interface::Sample::ISample")
    
    Returns:
        64-bit integer hash
    """
    # Calculate 64-bit hash using SHA256 (deterministic, first 8 bytes)
    hash_bytes = hashlib.sha256(name.encode('utf-8')).digest()[:8]
    return int.from_bytes(hash_bytes, byteorder='little', signed=False)


def add_function_checksums_recursive(node: Any) -> None:
    """
    Recursively traverse JSON structure and add checksum to CXXMethodDecl nodes.
    Function checksum is calculated from: function name + parameter types + parameter names.
    Adds 'function_checksum' field to each CXXMethodDecl node.
    
    Args:
        node: JSON data (dict, list, or primitive)
    """
    if isinstance(node, dict):
        kind = node.get("kind")
        
        # Add checksum to CXXMethodDecl (member functions)
        if kind == "CXXMethodDecl":
            func_name = node.get("name", "")
            params = []
            
            # Extract parameters from inner array
            if "inner" in node and isinstance(node["inner"], list):
                for item in node["inner"]:
                    if isinstance(item, dict) and item.get("kind") == "ParmVarDecl":
                        param_name = item.get("name", "")
                        param_type = ""
                        if "type" in item and isinstance(item["type"], dict):
                            param_type = item["type"].get("qualType", "")
                        params.append((param_type, param_name))
            
            # Calculate and store function checksum in the node
            func_checksum = calculate_function_checksum(func_name, params)
            node["function_checksum"] = func_checksum
        
        # Recursively process all values
        for value in node.values():
            add_function_checksums_recursive(value)
    
    elif isinstance(node, list):
        # Recursively process list items
        for item in node:
            add_function_checksums_recursive(item)


def add_interface_checksums_recursive(node: Any) -> None:
    """
    Recursively traverse JSON structure and add checksum to CXXRecordDecl nodes.
    Interface checksum is calculated from: interface name + all function checksums.
    Adds 'interface_checksum' field to each CXXRecordDecl node.
    Must be called after add_function_checksums_recursive().
    
    Args:
        node: JSON data (dict, list, or primitive)
    """
    if isinstance(node, dict):
        kind = node.get("kind")
        
        # Add checksum to CXXRecordDecl (interface classes)
        if kind == "CXXRecordDecl":
            interface_name = node.get("name", "")
            function_checksums = []
            
            # Extract function checksums from inner array
            if "inner" in node and isinstance(node["inner"], list):
                for item in node["inner"]:
                    if isinstance(item, dict) and item.get("kind") == "CXXMethodDecl":
                        func_checksum = item.get("function_checksum")
                        if func_checksum:
                            function_checksums.append(func_checksum)
            
            # Calculate and store interface checksum in the node
            interface_checksum = calculate_interface_checksum(interface_name, function_checksums)
            node["interface_checksum"] = interface_checksum
        
        # Recursively process all values
        for value in node.values():
            add_interface_checksums_recursive(value)
    
    elif isinstance(node, list):
        # Recursively process list items
        for item in node:
            add_interface_checksums_recursive(item)


def run_clang_ast_dump(
    clang_executable: str,
    source_file: str,
    include_dirs: List[str],
    output_file: str,
    include_files: List[str] = None,
    std: str = "c++20",
    ast_filter: Optional[str] = None
) -> bool:
    """
    Run clang to generate AST JSON from a C++ header file.
    
    Args:
        clang_executable: Path to clang++ executable
        source_file: Path to the header file to parse
        include_dirs: List of include directories
        include_files: List of files to include before processing source
        output_file: Path to output JSON file
        std: C++ standard version (default: c++20)
        ast_filter: Optional AST filter pattern (e.g., "Arieo::Interface")
    
    Returns:
        True if successful, False otherwise
    """
    # Check if clang-cl is being used - we don't support it
    if "clang-cl" in os.path.basename(clang_executable).lower():
        print(f"ERROR: clang-cl detected ({clang_executable}), but only regular clang/clang++ is supported.", file=sys.stderr)
        print("Please set CLANG_FOR_CODEGEN to a regular clang executable path.", file=sys.stderr)
        return False
    
    # Default include_files to empty list if not provided
    if include_files is None:
        include_files = []
    
    # Regular clang/clang++ uses GCC-style command line options
    cmd = [
        clang_executable,
        "-x", "c++-header",
        "-std=" + std,  # Enable C++20: -std=c++20
        "-w",  # Disable warnings
        "-Wno-error",
        "-fsyntax-only",
        "-Xclang", "-ast-dump=json",
        "-Xclang", "-detailed-preprocessing-record",
    ]
    
    # Add AST filter if specified
    if ast_filter:
        cmd.extend(["-Xclang", f"-ast-dump-filter={ast_filter}"])
    
    # Debug: Print the number of include directories
    print(f"Number of include directories: {len(include_dirs)}")
    print(f"Compiler type: clang/clang++ (GCC-compatible)")
    
    # Add include directories (GCC style: -I path)
    for inc_dir in include_dirs:
        cmd.extend(["-I", inc_dir])
        print(f"  Include: {inc_dir}")
    
    # Add include files (files to include before processing source)
    for inc_file in include_files:
        cmd.extend(["-include", inc_file])
        print(f"  Pre-include: {inc_file}")
    
    # Add source file
    cmd.append(source_file)
    
    try:
        print(f"Running clang with {len(include_dirs)} include paths...")
        print(f"Command: {clang_executable} -x c++-header -std={std} [+{len(include_dirs)} -I flags] {source_file}")
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False
        )
        
        # Print stderr if there are any errors or warnings
        if result.stderr:
            print(f"Clang stderr output:", file=sys.stderr)
            print(result.stderr, file=sys.stderr)
        
        # Check if clang command failed
        if result.returncode != 0:
            error_msg = f"Clang command failed with return code {result.returncode}"
            if result.stderr:
                error_msg += f"\nStderr: {result.stderr}"
            raise RuntimeError(error_msg)
        
        # Write output to file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(result.stdout)
        
        return True
    except subprocess.SubprocessError as e:
        print(f"Error running clang subprocess: {e}", file=sys.stderr)
        raise
    except Exception as e:
        print(f"Error running clang: {e}", file=sys.stderr)
        raise


def extract_annotation_text(source_file: str, line: int, col: int) -> Optional[str]:
    """
    Extract annotation text from METADATA() macro at the specified location.
    
    Args:
        source_file: Path to the source file
        line: Line number (1-based)
        col: Column number (1-based)
    
    Returns:
        The annotation string (e.g., "EXPORT_TO_SCRIPT") or None if not found
    """
    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        if line < 1 or line > len(lines):
            return None
        
        # Get the line content (convert to 0-based index)
        line_content = lines[line - 1]
        
        # Look for METADATA(xxx) pattern around the specified column
        # Pattern: METADATA(annotation_text)
        match = re.search(r'METADATA\s*\(\s*([A-Za-z0-9_]+)\s*\)', line_content)
        if match:
            return match.group(1)
        
        return None
    except Exception as e:
        print(f"Error reading source file {source_file} at line {line}: {e}", file=sys.stderr)
        return None


def add_annotation_strings_recursive(node: Dict[str, Any], source_file: str) -> None:
    """
    Recursively traverse AST JSON and add annotation strings to AnnotateAttr nodes.
    
    Args:
        node: AST node dictionary
        source_file: Path to the source file for extracting annotation text
    """
    if not isinstance(node, dict):
        return
    
    # If this is an AnnotateAttr node, extract and add the annotation string
    if node.get("kind") == "AnnotateAttr":
        # Try to get the expansion location (where the macro is used)
        range_begin = node.get("range", {}).get("begin", {})
        
        # Check if there's an expansionLoc (macro expansion location)
        expansion_loc = range_begin.get("expansionLoc", {})
        if expansion_loc:
            # Use the expansion location (where METADATA() is written)
            line = expansion_loc.get("line")
            col = expansion_loc.get("col")
            file_path = expansion_loc.get("file")
        else:
            # Fallback to direct location if no expansion
            line = range_begin.get("line")
            col = range_begin.get("col")
            file_path = range_begin.get("file")
        
        # Only extract if the location is in the target source file
        if line and col and file_path:
            # Normalize paths for comparison
            import os
            file_path_norm = os.path.normpath(file_path)
            source_file_norm = os.path.normpath(source_file)
            
            if file_path_norm == source_file_norm:
                annotation_text = extract_annotation_text(source_file, line, col)
                if annotation_text:
                    node["annotation"] = annotation_text
    
    # Recursively process inner nodes
    if "inner" in node and isinstance(node["inner"], list):
        for child in node["inner"]:
            add_annotation_strings_recursive(child, source_file)


def add_last_flags_recursive(data: Any) -> None:
    """
    Recursively traverse JSON structure and add 'last' and 'first' flags to array items.
    The 'last' flag marks the last item of each 'kind' within an array.
    The 'first' flag marks the first item of each 'kind' within an array.
    For CXXMethodDecl nodes, also considers isImplicit field for grouping.
    This is used for mustache template comma handling ({{^last}},{{/last}} or {{^first}},{{/first}}).
    
    Args:
        data: JSON data (dict, list, or primitive)
    """
    if isinstance(data, dict):
        # Process all values in the dictionary
        for key, value in data.items():
            if isinstance(value, list) and len(value) > 0:
                # Group items by their 'kind' field, and for CXXMethodDecl also by isImplicit
                kind_groups: Dict[str, List[int]] = {}
                for i, item in enumerate(value):
                    if isinstance(item, dict):
                        kind = item.get("kind", "_no_kind")
                        
                        # For CXXMethodDecl, create separate groups based on isImplicit
                        if kind == "CXXMethodDecl":
                            is_implicit = item.get("isImplicit", False)
                            group_key = f"{kind}+isImplicit={is_implicit}"
                        else:
                            group_key = kind
                        
                        if group_key not in kind_groups:
                            kind_groups[group_key] = []
                        kind_groups[group_key].append(i)
                
                # Mark the first and last items in each kind group
                for group_key, indices in kind_groups.items():
                    if indices:
                        first_index = indices[0]
                        last_index = indices[-1]
                        if isinstance(value[first_index], dict):
                            value[first_index]["first"] = True
                        if isinstance(value[last_index], dict):
                            value[last_index]["last"] = True
                
                # Set first=false and last=false for all other items
                for i, item in enumerate(value):
                    if isinstance(item, dict):
                        if "first" not in item:
                            item["first"] = False
                        if "last" not in item:
                            item["last"] = False
                    # Recursively process array items
                    add_last_flags_recursive(item)
            else:
                # Recursively process non-array values
                add_last_flags_recursive(value)
    elif isinstance(data, list):
        # Process each item in the list
        for item in data:
            add_last_flags_recursive(item)


def add_wit_format_names_recursive(node: Any, package_name: Optional[str], root_namespace: Optional[str] = None, namespace_stack: List[str] = None, parent_interface_qualified_name: Optional[str] = None, parent_wit_interface_fullname: Optional[str] = None, parent_witgen_cxx_interface_fullname: Optional[str] = None, parent_witgen_csharp_interface_fullname: Optional[str] = None, parent_witgen_rust_interface_fullname: Optional[str] = None, parent_wasm_cxx_interface_fullname: Optional[str] = None, parent_wasm_csharp_interface_name: Optional[str] = None, parent_wasm_rust_interface_fullname: Optional[str] = None) -> None:
    """
    Recursively traverse AST JSON and add WIT format names to interface and function nodes.
    
    Args:
        node: AST node (dict, list, or primitive)
        package_name: Package name for generating WIT interface paths
        root_namespace: Root namespace to prepend to full qualified names
        namespace_stack: Stack of namespace names for building full qualified names
        parent_interface_qualified_name: Full qualified name of parent interface (for function name hashing)
        parent_wit_full_interface_name: WIT format name of parent interface
    """
    if namespace_stack is None:
        namespace_stack = []
    
    if isinstance(node, dict):
        kind = node.get("kind")
        
        # Track namespace hierarchy
        if kind == "NamespaceDecl":
            namespace_name = node.get("name")
            if namespace_name:
                namespace_stack.append(namespace_name)
        
        # Add WIT format interface name to CXXRecordDecl (interface classes)
        if kind == "CXXRecordDecl" and package_name:
            interface_name = node.get("name")
            if interface_name:
                wit_interface_fullname = convert_interface_name_to_wit_format(package_name, interface_name)
                node["wit_interface_fullname"] = wit_interface_fullname
                # Extract just the interface part (after the /)
                wit_interface_name = wit_interface_fullname.split('/')[-1] if '/' in wit_interface_fullname else wit_interface_fullname
                node["wit_interface_name"] = wit_interface_name
                
                # Generate WIT-based C++ full interface name (e.g., "::arieo::sample::i_sample")
                witgen_cxx_interface_fullname = convert_wit_to_cxx_script_full_interface_name(wit_interface_fullname)
                node["witgen_cxx_interface_fullname"] = witgen_cxx_interface_fullname
                
                # Convert WIT full interface name to C++ script format with :: prefix
                # Use the actual C++ namespace and interface name instead of WIT conversion
                if root_namespace and interface_name:
                    cxx_script_interface_fullname = root_namespace + "::" + interface_name
                else:
                    cxx_script_interface_fullname = convert_wit_to_cxx_script_full_interface_name(wit_interface_fullname)
                node["wasm_cxx_interface_fullname"] = cxx_script_interface_fullname
                # Extract just the interface name (last part after ::)
                cxx_script_interface_name = cxx_script_interface_fullname.split('::')[-1]
                node["wasm_cxx_interface_name"] = cxx_script_interface_name
                
                # Convert WIT full interface name to C# format
                csharp_interface_fullname = convert_wit_to_csharp_full_interface_name(wit_interface_fullname)
                node["witgen_csharp_interface_fullname"] = csharp_interface_fullname
                # Use the actual interface name (preserve case like ISample)
                node["wasm_csharp_interface_name"] = interface_name
                
                # Generate WIT-based Rust full interface name (e.g., "crate::arieo::sample::i_sample")
                witgen_rust_interface_fullname = convert_wit_to_rust_full_interface_name(wit_interface_fullname)
                node["witgen_rust_interface_fullname"] = witgen_rust_interface_fullname
                
                # Convert WIT full interface name to Rust format
                # Use the actual interface name instead of WIT conversion
                if root_namespace and interface_name:
                    # Convert C++ namespace to Rust module path: Arieo::Interface::Sample -> crate::arieo::interface::sample
                    rust_namespace_path = 'crate::' + root_namespace.replace('::', '::').lower()
                    rust_interface_fullname = rust_namespace_path + '::' + interface_name
                else:
                    rust_interface_fullname = convert_wit_to_rust_full_interface_name(wit_interface_fullname)
                node["wasm_rust_interface_fullname"] = rust_interface_fullname
                # Use the actual interface name (preserve case like ISample)
                node["wasm_rust_interface_name"] = interface_name
                
                # Add namespace fields from root_namespace
                if root_namespace:
                    # C++ script namespace (same as root_namespace with ::)
                    node["wasm_cxx_namespace_fullname"] = root_namespace
                    
                    # .NET script namespace (replace :: with .)
                    node["wasm_dotnet_script_namespace_fullname"] = root_namespace.replace('::', '.')
                    
                    # Rust script namespace (lowercase and replace :: with .)
                    node["wasm_rust_namespace_fullname"] = root_namespace.replace('::', '.').lower()
                
                # Build full qualified name from root_namespace only
                # (namespace_stack would duplicate parts already in root_namespace)
                if root_namespace:
                    full_qualified_name = "::" + root_namespace + "::" + interface_name
                    node["full_qualified_name"] = full_qualified_name
                    # Calculate interface name hash from full qualified name
                    interface_name_hash = calculate_name_hash(full_qualified_name)
                    node["interface_name_hash"] = interface_name_hash
                    node["interface_id"] = interface_name_hash
                    # Pass these to child methods  
                    parent_interface_qualified_name = full_qualified_name
                    parent_wit_interface_fullname = wit_interface_fullname
                    parent_witgen_cxx_interface_fullname = witgen_cxx_interface_fullname
                    parent_witgen_csharp_interface_fullname = csharp_interface_fullname
                    parent_witgen_rust_interface_fullname = witgen_rust_interface_fullname
                    parent_wasm_cxx_interface_fullname = cxx_script_interface_fullname
                    parent_wasm_csharp_interface_name = interface_name
                    parent_wasm_rust_interface_fullname = rust_interface_fullname
        
        # Add WIT format function name to CXXMethodDecl (member functions)
        if kind == "CXXMethodDecl":
            func_name = node.get("name")
            if func_name:
                wit_func_name = convert_function_name_to_wit_format(func_name)
                node["wit_function_name"] = wit_func_name
                
                # Convert WIT function name to witgen format for each language
                # These represent the function names in WIT-generated code
                witgen_cxx_func_name = convert_wit_to_cxx_function_name(wit_func_name)
                node["witgen_cxx_function_name"] = witgen_cxx_func_name
                if parent_witgen_cxx_interface_fullname:
                    node["witgen_cxx_function_fullname"] = parent_witgen_cxx_interface_fullname + "::" + witgen_cxx_func_name
                
                # C# uses the same PascalCase function name format as C++
                witgen_csharp_func_name = witgen_cxx_func_name
                node["witgen_csharp_function_name"] = witgen_csharp_func_name
                if parent_witgen_csharp_interface_fullname:
                    node["witgen_csharp_function_fullname"] = parent_witgen_csharp_interface_fullname + "." + witgen_csharp_func_name
                
                # Rust uses snake_case for function names
                witgen_rust_func_name = convert_wit_to_rust_function_name(wit_func_name)
                node["witgen_rust_function_name"] = witgen_rust_func_name
                if parent_witgen_rust_interface_fullname:
                    node["witgen_rust_function_fullname"] = parent_witgen_rust_interface_fullname + "::" + witgen_rust_func_name
                
                # Script-exposed function names (use the original C++ function name)
                node["wasm_cxx_function_name"] = func_name
                if parent_wasm_cxx_interface_fullname:
                    node["wasm_cxx_function_fullname"] = parent_wasm_cxx_interface_fullname + "::" + func_name
                    
                node["wasm_csharp_function_name"] = func_name
                if parent_wasm_csharp_interface_name:
                    node["wasm_csharp_function_fullname"] = parent_wasm_csharp_interface_name + "." + func_name
                
                # Generate Rust wrapper method name by converting C++ method name to snake_case
                # This handles names like "doSomthing_1" -> "do_somthing_1"
                rust_wrapper_method_name = convert_method_name_to_rust_snake_case(func_name)
                node["rust_wrapper_method_name"] = rust_wrapper_method_name
                    
                node["wasm_rust_function_name"] = rust_wrapper_method_name
                if parent_wasm_rust_interface_fullname:
                    node["wasm_rust_function_fullname"] = parent_wasm_rust_interface_fullname + "::" + rust_wrapper_method_name
                
                # Store parent interface's WIT name and convert to C++ namespace format
                if parent_wit_interface_fullname:
                    node["wit_interface_fullname"] = parent_wit_interface_fullname
                    # Convert WIT format to C++ namespace format
                    cxx_namespace = convert_wit_to_cxx_namespace(parent_wit_interface_fullname)
                    node["cxx_namespace"] = cxx_namespace
                    # Convert function name to C++ format
                    cxx_function = wit_func_name.replace('-', '_')
                    if cxx_function:
                        cxx_function = cxx_function[0].upper() + cxx_function[1:]
                    node["cxx_function_name"] = cxx_function
                
                # Calculate function name hash from parent interface qualified name + function name
                if parent_interface_qualified_name:
                    full_function_qualified_name = parent_interface_qualified_name + "::" + func_name
                    function_name_hash = calculate_name_hash(full_function_qualified_name)
                    node["function_name_hash"] = function_name_hash
                    node["function_id"] = function_name_hash
                
                # Calculate function checksum based on name and parameters
                params = []
                if "inner" in node and isinstance(node["inner"], list):
                    for child in node["inner"]:
                        if isinstance(child, dict) and child.get("kind") == "ParmVarDecl":
                            param_name = child.get("name", "")
                            param_type = ""
                            if "type" in child and isinstance(child["type"], dict):
                                param_type = child["type"].get("qualType", "")
                            params.append((param_type, param_name))
                
                func_checksum = calculate_function_checksum(func_name, params)
                node["function_checksum"] = func_checksum
        
        # Recursively process all values
        for value in node.values():
            add_wit_format_names_recursive(value, package_name, root_namespace, namespace_stack.copy(), parent_interface_qualified_name, parent_wit_interface_fullname, parent_witgen_cxx_interface_fullname, parent_witgen_csharp_interface_fullname, parent_witgen_rust_interface_fullname, parent_wasm_cxx_interface_fullname, parent_wasm_csharp_interface_name, parent_wasm_rust_interface_fullname)
    
    elif isinstance(node, list):
        # Recursively process list items
        for item in node:
            add_wit_format_names_recursive(item, package_name, root_namespace, namespace_stack.copy(), parent_interface_qualified_name, parent_wit_interface_fullname, parent_witgen_cxx_interface_fullname, parent_witgen_csharp_interface_fullname, parent_witgen_rust_interface_fullname, parent_wasm_cxx_interface_fullname, parent_wasm_csharp_interface_name, parent_wasm_rust_interface_fullname)


def add_interface_checksums_recursive(node: Any) -> None:
    """
    Recursively traverse AST and add checksums to CXXRecordDecl (interface classes).
    This must be called after add_wit_format_names_recursive so function checksums are available.
    
    Args:
        node: AST node (dict, list, or primitive)
    """
    if isinstance(node, dict):
        kind = node.get("kind")
        
        # Calculate interface checksum for CXXRecordDecl
        if kind == "CXXRecordDecl":
            interface_name = node.get("name")
            if interface_name:
                # Collect function checksums from all CXXMethodDecl children
                function_checksums = []
                if "inner" in node and isinstance(node["inner"], list):
                    for child in node["inner"]:
                        if isinstance(child, dict) and child.get("kind") == "CXXMethodDecl":
                            func_checksum = child.get("function_checksum")
                            if func_checksum:
                                function_checksums.append(func_checksum)
                
                # Calculate interface checksum
                interface_checksum = calculate_interface_checksum(interface_name, function_checksums)
                node["interface_checksum"] = interface_checksum
        
        # Recursively process all values
        for value in node.values():
            add_interface_checksums_recursive(value)
    
    elif isinstance(node, list):
        # Recursively process list items
        for item in node:
            add_interface_checksums_recursive(item)


def extract_method_signature_details(node: Any) -> None:
    """
    Extract return type and parameters from CXXMethodDecl nodes and add them as proper fields.
    Parses the type.qualType field and inner ParmVarDecl children.
    
    Args:
        node: AST node (dict, list, or primitive)
    """
    if isinstance(node, dict):
        kind = node.get("kind")
        
        # Process CXXMethodDecl to extract signature details
        if kind == "CXXMethodDecl":
            # Extract return type from the function type signature
            # Format: "return_type (param_type1, param_type2, ...)"
            type_info = node.get("type", {})
            if isinstance(type_info, dict):
                qual_type = type_info.get("qualType", "")
                if qual_type:
                    # Parse the return type (everything before the opening parenthesis)
                    paren_idx = qual_type.find('(')
                    if paren_idx > 0:
                        return_type = qual_type[:paren_idx].strip()
                        node["native_return_type"] = return_type
                        node["csharp_return_type"] = convert_type_to_target_language(return_type, "csharp")
                        node["rust_return_type"] = convert_type_to_target_language(return_type, "rust")
                        # Keep legacy returnType for backward compatibility
                        node["returnType"] = return_type
            
            # Extract parameters from inner array
            parameters = []
            if "inner" in node and isinstance(node["inner"], list):
                for child in node["inner"]:
                    if isinstance(child, dict) and child.get("kind") == "ParmVarDecl":
                        param_name = child.get("name", "")
                        param_type_info = child.get("type", {})
                        if isinstance(param_type_info, dict):
                            native_type = param_type_info.get("qualType", "")
                            param = {
                                "name": param_name,
                                "native_type": native_type,
                                "csharp_type": convert_type_to_target_language(native_type, "csharp"),
                                "rust_type": convert_type_to_target_language(native_type, "rust"),
                                "desugaredType": param_type_info.get("desugaredQualType", "")
                            }
                            parameters.append(param)
            
            # Add parameters array to method node
            node["parameters"] = parameters
        
        # Recursively process all values
        for value in node.values():
            extract_method_signature_details(value)
    
    elif isinstance(node, list):
        # Recursively process list items
        for item in node:
            extract_method_signature_details(item)


def post_process_ast_json(
    ast_json_file: str,
    source_file: str,
    output_file: Optional[str] = None,
    root_namespace: Optional[str] = None,
    package_name: Optional[str] = None
) -> bool:
    """
    Post-process AST JSON to add annotation strings from source file.
    
    Args:
        ast_json_file: Path to the AST JSON file generated by clang
        source_file: Path to the original source file
        output_file: Path to output file (if None, overwrites input file)
        root_namespace: Optional root namespace to include in the output JSON
        package_name: Optional package name for WIT format generation
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # Load AST JSON (handle multiple JSON objects from clang output)
        with open(ast_json_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Parse all JSON objects from clang output (may be multiple when filtered namespace appears in multiple files)
        decoder = json.JSONDecoder()
        json_objects = []
        idx = 0
        while idx < len(content):
            # Skip whitespace
            while idx < len(content) and content[idx].isspace():
                idx += 1
            if idx >= len(content):
                break
            # Parse next JSON object
            try:
                obj, end_idx = decoder.raw_decode(content, idx)
                json_objects.append(obj)
                idx += end_idx
            except json.JSONDecodeError:
                break
        
        if not json_objects:
            raise ValueError("No valid JSON objects found in AST output")
        
        # Merge all JSON objects into one by combining their "inner" arrays
        ast_data = json_objects[0]
        if len(json_objects) > 1:
            # Ensure first object has "inner" array
            if "inner" not in ast_data:
                ast_data["inner"] = []
            # Merge inner arrays from all other objects
            for obj in json_objects[1:]:
                if "inner" in obj and isinstance(obj["inner"], list):
                    ast_data["inner"].extend(obj["inner"])
        
        # Add annotation strings recursively
        add_annotation_strings_recursive(ast_data, source_file)
        
        # Add WIT format names and function checksums to CXXRecordDecl (interface) and CXXMethodDecl (functions)
        add_wit_format_names_recursive(ast_data, package_name, root_namespace)
        
        # Extract method signature details (return type and parameters)
        extract_method_signature_details(ast_data)
        
        # Add 'last' flags to all arrays for mustache template comma handling (must be after extraction)
        add_last_flags_recursive(ast_data)
        
        # Add interface checksums based on function checksums
        add_interface_checksums_recursive(ast_data)
        
        # Add root_namespace and package name at the beginning if provided
        ordered_data = {}
        if root_namespace:
            ordered_data["root_namespace"] = root_namespace
            # Add root-level namespace variants
            ordered_data["root_namespace_dotnet"] = root_namespace.replace('::', '.')
            ordered_data["root_namespace_rust"] = root_namespace.replace('::', '.').lower()
            # Add namespace last part (just the final segment)
            ordered_data["root_namespace_last"] = root_namespace.split('::')[-1]
            ordered_data["root_namespace_dotnet_last"] = root_namespace.split('::')[-1]
            ordered_data["root_namespace_rust_last"] = root_namespace.split('::')[-1].lower()
        if package_name:
            ordered_data["package_name"] = package_name
            # Add WIT package namespace (same as package_name)
            ordered_data["wit_package_name"] = package_name
            # Add witgen namespace fields for each language
            ordered_data["witgen_cxx_namespace_fullname"] = convert_package_name_to_cxx_namespace(package_name)
            ordered_data["witgen_dotnet_namespace_fullname"] = convert_package_name_to_csharp_namespace(package_name)
            ordered_data["witgen_rust_namespace_fullname"] = convert_package_name_to_rust_namespace(package_name)
        ordered_data.update(ast_data)
        ast_data = ordered_data
        
        # Write back to file
        output_path = output_file or ast_json_file
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(ast_data, f, indent=2)
        
        print(f"Successfully post-processed AST JSON: {output_path}")
        return True
    except Exception as e:
        print(f"Error post-processing AST JSON: {e}", file=sys.stderr)
        return False


def main():
    """
    Main entry point for the script.
    
    Usage:
        python generate_cxx_ast.py --clang-executable=<clang_executable> --source-file=<source_file> --output-file=<output_file> --root-namespace=<root_namespace> --package-name=<package_name> [--include-file=<include_file>] [--include-dir=<include_dir>]
    
    Example:
        python generate_cxx_ast.py --clang-executable=clang++ --source-file=sample.h --output-file=sample.ast.json --root-namespace="Arieo::Interface::Sample" --package-name="arieo:sample" --include-file=file1.h --include-file=file2.h --include-dir=/usr/include --include-dir=/usr/local/include
    """
    parser = argparse.ArgumentParser(
        description='Generate C++ AST JSON using clang and post-process to extract annotation strings.',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    # Required arguments
    parser.add_argument('--clang-executable', required=True,
                        help='Path to clang/clang++ executable')
    parser.add_argument('--source-file', required=True,
                        help='Path to the C++ header file to parse')
    parser.add_argument('--output-file', required=True,
                        help='Path to output AST JSON file')
    parser.add_argument('--root-namespace', required=True,
                        help='Root namespace to filter AST (e.g., "Arieo::Interface::Sample")')
    parser.add_argument('--package-name', required=True,
                        help='Package name for the interface (e.g., "arieo:sample")')
    
    # Optional repeatable arguments
    parser.add_argument('--include-file', action='append', dest='include_files', default=[],
                        help='File to pre-include with -include flag (can be specified multiple times)')
    parser.add_argument('--include-dir', action='append', dest='include_dirs', default=[],
                        help='Include directory to add with -I flag (can be specified multiple times)')
    
    args = parser.parse_args()
    
    # Step 1: Run clang to generate AST JSON
    print(f"Generating AST JSON from {args.source_file}...")
    success = run_clang_ast_dump(
        clang_executable=args.clang_executable,
        source_file=args.source_file,
        include_dirs=args.include_dirs,
        output_file=args.output_file,
        include_files=args.include_files,
        ast_filter=args.root_namespace
    )
    
    # Always continue to post-processing, even if clang had issues
    
    # Step 2: Post-process to add annotation strings
    print(f"Post-processing AST JSON to extract annotations...")
    success = post_process_ast_json(
        ast_json_file=args.output_file,
        source_file=args.source_file,
        root_namespace=args.root_namespace,
        package_name=args.package_name
    )
    
    # Ignore post-processing errors as well
    print("Done!")


if __name__ == "__main__":
    main()
