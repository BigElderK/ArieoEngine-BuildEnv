cmake_minimum_required(VERSION 3.31)

function(arieo_generate_interface_code target_project)
    set(oneValueArgs
        SCRIPT_PACKAGE_NAME
        ROOT_NAMESPACE
        AST_GENERATE_FOLDER
        NATIVE_CODE_GENERATE_FOLDER
        WASM_WIT_GENERATE_FOLDER
        WASM_CXX_SCRIPT_GENERATE_FOLDER
        WASM_CSHARP_SCRIPT_GENERATE_FOLDER
        WASM_RUST_SCRIPT_GENERATE_FOLDER
    )

    set(multiValueArgs
        EXTRA_INCLUDE_FOLDERS
        INTERFACE_HEADERS
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN}
    )

    if(NOT DEFINED ARGUMENT_INTERFACE_HEADERS)
        return()
    endif()
    
    # Add base and core include directories first (for common types/macros and arieo::core)
    if(NOT DEFINED ENV{ARIEO_CORE_PACKAGE_INSTALL_FOLDER})
        message(FATAL_ERROR "ARIEO_CORE_PACKAGE_INSTALL_FOLDER environment variable not defined. Required for interface AST generation.")
    endif()
    
    if(NOT DEFINED ENV{ARIEO_PACKAGE_BUILD_HOST_PRESET})
        message(FATAL_ERROR "ARIEO_PACKAGE_BUILD_HOST_PRESET environment variable not defined. Required for interface AST generation.")
    endif()
    
    if(NOT DEFINED ENV{ARIEO_PACKAGE_BUILD_TYPE})
        message(FATAL_ERROR "ARIEO_PACKAGE_BUILD_TYPE environment variable not defined. Required for interface AST generation.")
    endif()
    
    # Build include directories list
    set(extra_include_dirs)
    # Add extra include folders
    foreach(inc_dir ${ARGUMENT_EXTRA_INCLUDE_FOLDERS})
        list(APPEND extra_include_dirs "${inc_dir}")
    endforeach()
    
    # Add all other interface include directories to help resolve cross-interface dependencies
    file(GLOB interface_dirs "${CMAKE_CURRENT_LIST_DIR}/../*/public/include")
    foreach(interface_dir ${interface_dirs})
        if(EXISTS ${interface_dir})
            list(APPEND extra_include_dirs "${interface_dir}")
        endif()
    endforeach()

    # Use CMAKE_CXX_COMPILER if it's clang, otherwise search for clang++
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(CLANG_EXECUTABLE ${CMAKE_CXX_COMPILER})
    else()
        find_program(CLANG_EXECUTABLE NAMES clang++ clang)
    endif()
    
    if(NOT DEFINED CLANG_EXECUTABLE)
        message(FATAL_ERROR "CLANG_EXECUTABLE not found, skipping interface AST generation for ${target_project}")
    endif()

    # Determine output directory for AST files
    if(NOT DEFINED ARGUMENT_AST_GENERATE_FOLDER)
        message(FATAL_ERROR "AST_GENERATE_FOLDER must be specified for interface project ${target_project}")
    endif()
    
    # Create AST output directory
    file(MAKE_DIRECTORY ${ARGUMENT_AST_GENERATE_FOLDER})
    
    # Collect output JSON files and create custom commands
    set(output_generated_files)
    foreach(header_file ${ARGUMENT_INTERFACE_HEADERS})
        # Get the directory and basename of the header file
        get_filename_component(header_dir ${header_file} DIRECTORY)
        get_filename_component(header_basename ${header_file} NAME_WE)
        
        # Get relative path from public include folder to preserve directory structure
        file(RELATIVE_PATH rel_path "${CMAKE_CURRENT_SOURCE_DIR}/public/include" "${header_file}")
        get_filename_component(rel_dir "${rel_path}" DIRECTORY)
        
        # Set output path in AST directory
        if(rel_dir STREQUAL "")
            set(output_json "${ARGUMENT_AST_GENERATE_FOLDER}/${header_basename}.ast.json")
        else()
            file(MAKE_DIRECTORY "${ARGUMENT_AST_GENERATE_FOLDER}/${rel_dir}")
            set(output_json "${ARGUMENT_AST_GENERATE_FOLDER}/${rel_dir}/${header_basename}.ast.json")
        endif()
        list(APPEND output_generated_files ${output_json})
        
        # Prepare include arguments for Python script (space-separated list)
        set(python_includes)
        foreach(inc_dir ${extra_include_dirs})
            list(APPEND python_includes "${inc_dir}")
        endforeach()
        
        # Add custom command to generate AST JSON using Python script
        # The script runs clang and post-processes to extract annotation strings
        set(PYTHON_SCRIPT "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/generate_cxx_ast.py")
        set(GENERATE_INTERFACE_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/xxx.interface.json.mustache")
        set(GENERATE_INTERFACE_INFO_H_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/xxx.interface_info.h.mustache")
        set(GENERATE_INTERFACE_WIT_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/xxx.interface.wit.mustache")
        set(GENERATE_WASM_H_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/xxx.wasm.h.mustache")
        set(GENERATE_WASM_CS_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/xxx.wasm.cs.mustache")
        set(GENERATE_WASM_RS_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/xxx.wasm.rs.mustache")
        
        # SCRIPT_PACKAGE_NAME is required
        if(NOT DEFINED ARGUMENT_SCRIPT_PACKAGE_NAME)
            message(FATAL_ERROR "SCRIPT_PACKAGE_NAME must be specified for interface project ${target_project}")
        endif()
        
        # ROOT_NAMESPACE is required (used as AST filter)
        if(NOT DEFINED ARGUMENT_ROOT_NAMESPACE)
            message(FATAL_ERROR "ROOT_NAMESPACE must be specified for interface project ${target_project}")
        endif()
        
        # message(FATAL_ERROR "python \"${PYTHON_SCRIPT}\" \"${CLANG_EXECUTABLE}\" \"${header_file}\" \"${output_json}\" \"${ARGUMENT_ROOT_NAMESPACE}\" \"${ARGUMENT_SCRIPT_PACKAGE_NAME}\" ${python_includes}")

        add_custom_command(
            OUTPUT ${output_json}
            COMMAND ${CMAKE_COMMAND} -E echo "Generating AST for ${header_basename}.h..."
            COMMAND python "${PYTHON_SCRIPT}" "${CLANG_EXECUTABLE}" "${header_file}" "${output_json}" "${ARGUMENT_ROOT_NAMESPACE}" "${ARGUMENT_SCRIPT_PACKAGE_NAME}" ${python_includes}
            COMMAND ${CMAKE_COMMAND} -E echo "Successfully generated ${output_json}"
            DEPENDS ${header_file} "${PYTHON_SCRIPT}"
            COMMENT "Generating ${header_basename}.ast.json with annotations from ${header_basename}.h"
        )
        
        # Generate simplified interface JSON using mustache template
        set(interface_ast_json "${ARGUMENT_AST_GENERATE_FOLDER}/${rel_dir}/${header_basename}.interface.json")
        list(APPEND output_generated_files ${interface_ast_json})
        
        find_program(MUSTACHE_EXECUTABLE NAMES mustache)
        if(NOT DEFINED MUSTACHE_EXECUTABLE)
            message(FATAL_ERROR "MUSTACHE_EXECUTABLE not found, required for interface code generation for ${target_project}")
        endif()

        add_custom_command(
            OUTPUT ${interface_ast_json}
            COMMAND ${CMAKE_COMMAND} -E echo "Generating interface JSON for ${header_basename}..."
            COMMAND ${MUSTACHE_EXECUTABLE} "${output_json}" "${GENERATE_INTERFACE_MUSTACHE_TEMPLATE}" > "${interface_ast_json}"
            COMMAND ${CMAKE_COMMAND} -E echo "Successfully generated ${interface_ast_json}"
            DEPENDS ${output_json} "${GENERATE_INTERFACE_MUSTACHE_TEMPLATE}"
            COMMENT "Generating ${header_basename}.interface.json from AST using mustache template"
        )
        
        # Generate interface_info.h using mustache template to NATIVE_CODE_GENERATE_FOLDER
        if(DEFINED ARGUMENT_NATIVE_CODE_GENERATE_FOLDER)
            # Determine output directory for native code
            set(native_output_dir "${ARGUMENT_NATIVE_CODE_GENERATE_FOLDER}")
            file(MAKE_DIRECTORY "${native_output_dir}")
            
            # Set output path in native code directory
            if(rel_dir STREQUAL "")
                set(interface_info_h "${native_output_dir}/${header_basename}.interface_info.h")
            else()
                file(MAKE_DIRECTORY "${native_output_dir}/${rel_dir}")
                set(interface_info_h "${native_output_dir}/${rel_dir}/${header_basename}.interface_info.h")
            endif()
            list(APPEND output_generated_files ${interface_info_h})
            
            add_custom_command(
                OUTPUT ${interface_info_h}
                COMMAND ${CMAKE_COMMAND} -E echo "Generating interface_info.h for ${header_basename}..."
                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_ast_json}" "${GENERATE_INTERFACE_INFO_H_MUSTACHE_TEMPLATE}" > "${interface_info_h}"
                COMMAND ${CMAKE_COMMAND} -E echo "Successfully generated ${interface_info_h}"
                DEPENDS ${interface_ast_json} "${GENERATE_INTERFACE_INFO_H_MUSTACHE_TEMPLATE}"
                COMMENT "Generating ${header_basename}.interface_info.h from interface JSON using mustache template"
            )
        endif()
        
        # Generate interface.wit file using mustache template to WASM_WIT_GENERATE_FOLDER
        if(DEFINED ARGUMENT_WASM_WIT_GENERATE_FOLDER)
            # Determine output directory for WIT files
            set(wit_output_dir "${ARGUMENT_WASM_WIT_GENERATE_FOLDER}")
            file(MAKE_DIRECTORY "${wit_output_dir}")
            
            # Set output path in WIT directory (flat structure, no subdirectories)
            set(interface_wit "${wit_output_dir}/${header_basename}.interface.wit")
            list(APPEND output_generated_files ${interface_wit})
            
            add_custom_command(
                OUTPUT ${interface_wit}
                COMMAND ${CMAKE_COMMAND} -E echo "Generating WIT interface for ${header_basename}..."
                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_ast_json}" "${GENERATE_INTERFACE_WIT_MUSTACHE_TEMPLATE}" > "${interface_wit}"
                COMMAND ${CMAKE_COMMAND} -E echo "Successfully generated ${interface_wit}"
                DEPENDS ${interface_ast_json} "${GENERATE_INTERFACE_WIT_MUSTACHE_TEMPLATE}"
                COMMENT "Generating ${header_basename}.interface.wit from interface JSON using mustache template"
            )
        endif()
        
        # Generate C++ wrapper header file using mustache template to WASM_CXX_SCRIPT_GENERATE_FOLDER
        if(DEFINED ARGUMENT_WASM_CXX_SCRIPT_GENERATE_FOLDER)
            # Determine output directory for C++ wrapper files
            set(wasm_cxx_output_dir "${ARGUMENT_WASM_CXX_SCRIPT_GENERATE_FOLDER}")
            file(MAKE_DIRECTORY "${wasm_cxx_output_dir}")
            
            # Set output path in C++ wrapper directory (flat structure, no subdirectories)
            set(wasm_cxx_h "${wasm_cxx_output_dir}/${header_basename}.wasm.h")
            list(APPEND output_generated_files ${wasm_cxx_h})
            
            add_custom_command(
                OUTPUT ${wasm_cxx_h}
                COMMAND ${CMAKE_COMMAND} -E echo "Generating C++ WASM wrapper for ${header_basename}..."
                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_ast_json}" "${GENERATE_WASM_H_MUSTACHE_TEMPLATE}" > "${wasm_cxx_h}"
                COMMAND ${CMAKE_COMMAND} -E echo "Successfully generated ${wasm_cxx_h}"
                DEPENDS ${interface_ast_json} "${GENERATE_WASM_H_MUSTACHE_TEMPLATE}"
                COMMENT "Generating ${header_basename}.wasm.h from interface JSON using mustache template"
            )
        endif()
        
        # Generate C# wrapper file using mustache template to WASM_CSHARP_SCRIPT_GENERATE_FOLDER
        if(DEFINED ARGUMENT_WASM_CSHARP_SCRIPT_GENERATE_FOLDER)
            # Determine output directory for C# wrapper files
            set(wasm_csharp_output_dir "${ARGUMENT_WASM_CSHARP_SCRIPT_GENERATE_FOLDER}")
            file(MAKE_DIRECTORY "${wasm_csharp_output_dir}")
            
            # Set output path in C# wrapper directory (flat structure, no subdirectories)
            set(wasm_csharp_cs "${wasm_csharp_output_dir}/${header_basename}.wasm.cs")
            list(APPEND output_generated_files ${wasm_csharp_cs})
            
            add_custom_command(
                OUTPUT ${wasm_csharp_cs}
                COMMAND ${CMAKE_COMMAND} -E echo "Generating C# WASM wrapper for ${header_basename}..."
                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_ast_json}" "${GENERATE_WASM_CS_MUSTACHE_TEMPLATE}" > "${wasm_csharp_cs}"
                COMMAND ${CMAKE_COMMAND} -E echo "Successfully generated ${wasm_csharp_cs}"
                DEPENDS ${interface_ast_json} "${GENERATE_WASM_CS_MUSTACHE_TEMPLATE}"
                COMMENT "Generating ${header_basename}.wasm.cs from interface JSON using mustache template"
            )
        endif()
        
        # Generate Rust wrapper file using mustache template to WASM_RUST_SCRIPT_GENERATE_FOLDER
        if(DEFINED ARGUMENT_WASM_RUST_SCRIPT_GENERATE_FOLDER)
            # Determine output directory for Rust wrapper files
            set(wasm_rust_output_dir "${ARGUMENT_WASM_RUST_SCRIPT_GENERATE_FOLDER}")
            file(MAKE_DIRECTORY "${wasm_rust_output_dir}")
            
            # Set output path in Rust wrapper directory (flat structure, no subdirectories)
            set(wasm_rust_rs "${wasm_rust_output_dir}/${header_basename}.wasm.rs")
            list(APPEND output_generated_files ${wasm_rust_rs})
            
            add_custom_command(
                OUTPUT ${wasm_rust_rs}
                COMMAND ${CMAKE_COMMAND} -E echo "Generating Rust WASM wrapper for ${header_basename}..."
                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_ast_json}" "${GENERATE_WASM_RS_MUSTACHE_TEMPLATE}" > "${wasm_rust_rs}"
                COMMAND ${CMAKE_COMMAND} -E echo "Successfully generated ${wasm_rust_rs}"
                DEPENDS ${interface_ast_json} "${GENERATE_WASM_RS_MUSTACHE_TEMPLATE}"
                COMMENT "Generating ${header_basename}.wasm.rs from interface JSON using mustache template"
            )
        endif()
    endforeach()
    
    # Create a custom target that depends on all JSON files
    add_custom_target(
        ${target_project}_codegen ALL
        DEPENDS ${output_generated_files}
        COMMENT "Generating interface AST files for ${target_project}"
    )

    # Add dependency from interface target to reflection generation target
    add_dependencies(${target_project} ${target_project}_codegen)

    list(LENGTH ARGUMENT_INTERFACE_HEADERS header_count)
    message(STATUS "Interface AST generation enabled for ${target_project} (${header_count} headers) using clang: ${CLANG_EXECUTABLE}")
endfunction()
