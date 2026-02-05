cmake_minimum_required(VERSION 3.31)

function(arieo_interface_project target_project)
    set(oneValueArgs 
        ALIAS
        MODULE_CONFIG_FILE
        AST_GENERATE_FOLDER
        NATIVE_CODE_GENERATE_FOLDER
        WASM_WIT_GENERATE_FOLDER
        WASM_CXX_SCRIPT_GENERATE_FOLDER
        WASM_CSHARP_SCRIPT_GENERATE_FOLDER
        WASM_RUST_SCRIPT_GENERATE_FOLDER
        SCRIPT_PACKAGE_NAME
        ROOT_NAMESPACE
    )

    set(multiValueArgs 
        PUBLIC_INCLUDE_FOLDERS
        SOURCES
        PACKAGES
        PRIVATE_INCLUDE_FOLDERS
        PRIVATE_LIB_FOLDERS
        INTERFACES
        LIBS
        EXTERNAL_LIBS
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})

    # Create target
    add_library(${target_project} INTERFACE)
    
    if(DEFINED ARGUMENT_ALIAS)
        add_library(${ARGUMENT_ALIAS} ALIAS ${target_project})
    endif()

    foreach(ARGUMENT_PACKAGE IN LISTS ARGUMENT_PACKAGES)
        find_package(${ARGUMENT_PACKAGE} REQUIRED)
    endforeach()

    # Add libs
    if(DEFINED ARGUMENT_LIBS)
        target_link_libraries(
            ${target_project} 
            INTERFACE
                ${ARGUMENT_LIBS}
        )
    endif()

    # Add interfaces
    if(DEFINED ARGUMENT_INTERFACES)
        target_link_libraries(
            ${target_project} 
            INTERFACE
                ${ARGUMENT_INTERFACES}
        )
    endif()

    # Set include directories
    target_include_directories(
        ${target_project}
        INTERFACE 
            ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS}
    )

    # Generate interfaces.json for interface projects
    # Find all header files in public include folders
    set(interface_headers)
    foreach(include_folder ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS})
        file(GLOB_RECURSE headers "${include_folder}/*.h" "${include_folder}/*.hpp")
        list(APPEND interface_headers ${headers})
    endforeach()
    
    # Remove generated files from the list (to avoid processing .generated.h files)
    # list(FILTER interface_headers EXCLUDE REGEX "\\.generated\\.(h|hpp)$")
    
    # Remove duplicates from the list
    list(REMOVE_DUPLICATES interface_headers)

    if(interface_headers)
        # Find Python interpreter
        find_package(Python3 COMPONENTS Interpreter QUIET)
        if(NOT Python3_FOUND)
            find_program(PYTHON_EXECUTABLE python)
            if(NOT PYTHON_EXECUTABLE)
                find_program(PYTHON_EXECUTABLE python3)
            endif()
            if(NOT PYTHON_EXECUTABLE)
                message(WARNING "Python not found, skipping interface generation for ${target_project}")
            else()
                set(Python3_EXECUTABLE ${PYTHON_EXECUTABLE})
            endif()
        endif()

        if(Python3_EXECUTABLE OR Python3_FOUND)
            # Build include directories list
            set(include_dirs)
            
            # Add base and core include directories first (for common types/macros)
            get_filename_component(ENGINE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
            set(base_include_dir "${ENGINE_ROOT}/00_base/public/include")
            set(core_include_dir "${ENGINE_ROOT}/01_core/public/include")

            if(EXISTS ${base_include_dir})
                list(APPEND include_dirs "${base_include_dir}")
            else()
                message(FATAL_ERROR "Base include directory not found at ${base_include_dir}")
            endif()

            if(EXISTS ${core_include_dir})
                list(APPEND include_dirs "${core_include_dir}")
            else()
                message(FATAL_ERROR "Core include directory not found at ${core_include_dir}")
            endif()
            
            # Add project's public include folders
            foreach(inc_dir ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS})
                list(APPEND include_dirs "${inc_dir}")
            endforeach()
            
            # Add all other interface include directories to help resolve cross-interface dependencies
            file(GLOB interface_dirs "${CMAKE_CURRENT_LIST_DIR}/../*/public/include")
            foreach(interface_dir ${interface_dirs})
                if(EXISTS ${interface_dir})
                    list(APPEND include_dirs "${interface_dir}")
                endif()
            endforeach()

            # Use CMAKE_CXX_COMPILER if it's clang, otherwise search for clang++
            if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
                set(CLANG_EXECUTABLE ${CMAKE_CXX_COMPILER})
            else()
                find_program(CLANG_EXECUTABLE NAMES clang++ clang)
            endif()
            
            if(CLANG_EXECUTABLE)
                # Determine output directory for AST files
                if(NOT DEFINED ARGUMENT_AST_GENERATE_FOLDER)
                    message(FATAL_ERROR "AST_GENERATE_FOLDER must be specified for interface project ${target_project}")
                endif()
                set(ast_output_dir "${ARGUMENT_AST_GENERATE_FOLDER}")
                
                # Create AST output directory
                file(MAKE_DIRECTORY ${ast_output_dir})
                
                # Collect output JSON files and create custom commands
                set(output_json_files)
                foreach(header_file ${interface_headers})
                    # Get the directory and basename of the header file
                    get_filename_component(header_dir ${header_file} DIRECTORY)
                    get_filename_component(header_basename ${header_file} NAME_WE)
                    
                    # Get relative path from public include folder to preserve directory structure
                    file(RELATIVE_PATH rel_path "${CMAKE_CURRENT_SOURCE_DIR}/public/include" "${header_file}")
                    get_filename_component(rel_dir "${rel_path}" DIRECTORY)
                    
                    # Set output path in AST directory
                    if(rel_dir STREQUAL "")
                        set(output_json "${ast_output_dir}/${header_basename}.ast.json")
                    else()
                        file(MAKE_DIRECTORY "${ast_output_dir}/${rel_dir}")
                        set(output_json "${ast_output_dir}/${rel_dir}/${header_basename}.ast.json")
                    endif()
                    list(APPEND output_json_files ${output_json})
                    
                    # Prepare include arguments for Python script (space-separated list)
                    set(python_includes)
                    foreach(inc_dir ${include_dirs})
                        list(APPEND python_includes "${inc_dir}")
                    endforeach()
                    
                    # Add custom command to generate AST JSON using Python script
                    # The script runs clang and post-processes to extract annotation strings
                    set(PYTHON_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/../../codegen/generate_cxx_ast.py")
                    set(GENERATE_INTERFACE_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/../../codegen/xxx.interface.json.mustache")
                    set(GENERATE_INTERFACE_INFO_H_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/../../codegen/xxx.interface_info.h.mustache")
                    set(GENERATE_INTERFACE_WIT_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/../../codegen/xxx.interface.wit.mustache")
                    set(GENERATE_WASM_H_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/../../codegen/xxx.wasm.h.mustache")
                    set(GENERATE_WASM_CS_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/../../codegen/xxx.wasm.cs.mustache")
                    set(GENERATE_WASM_RS_MUSTACHE_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/../../codegen/xxx.wasm.rs.mustache")
                    
                    # SCRIPT_PACKAGE_NAME is required
                    if(NOT DEFINED ARGUMENT_SCRIPT_PACKAGE_NAME)
                        message(FATAL_ERROR "SCRIPT_PACKAGE_NAME must be specified for interface project ${target_project}")
                    endif()
                    set(package_name_arg "${ARGUMENT_SCRIPT_PACKAGE_NAME}")
                    
                    # ROOT_NAMESPACE is required (used as AST filter)
                    if(NOT DEFINED ARGUMENT_ROOT_NAMESPACE)
                        message(FATAL_ERROR "ROOT_NAMESPACE must be specified for interface project ${target_project}")
                    endif()
                    set(root_namespace_arg "${ARGUMENT_ROOT_NAMESPACE}")
                    
                    add_custom_command(
                        OUTPUT ${output_json}
                        COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_SOURCE_DIR}
                            python "${PYTHON_SCRIPT}" "${CLANG_EXECUTABLE}" "${header_file}" "${output_json}" "${root_namespace_arg}" "${package_name_arg}" ${python_includes}
                        DEPENDS ${header_file} "${PYTHON_SCRIPT}"
                        COMMENT "Generating ${header_basename}.ast.json with annotations from ${header_basename}.h"
                    )
                    
                    # Generate simplified interface JSON using mustache template
                    set(interface_json "${ast_output_dir}/${rel_dir}/${header_basename}.interface.json")
                    list(APPEND output_json_files ${interface_json})
                    
                    find_program(MUSTACHE_EXECUTABLE NAMES mustache)
                    if(MUSTACHE_EXECUTABLE)
                        add_custom_command(
                            OUTPUT ${interface_json}
                            COMMAND ${MUSTACHE_EXECUTABLE} "${output_json}" "${GENERATE_INTERFACE_MUSTACHE_TEMPLATE}" > "${interface_json}"
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
                            list(APPEND output_json_files ${interface_info_h})
                            
                            add_custom_command(
                                OUTPUT ${interface_info_h}
                                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_json}" "${GENERATE_INTERFACE_INFO_H_MUSTACHE_TEMPLATE}" > "${interface_info_h}"
                                DEPENDS ${interface_json} "${GENERATE_INTERFACE_INFO_H_MUSTACHE_TEMPLATE}"
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
                            list(APPEND output_json_files ${interface_wit})
                            
                            add_custom_command(
                                OUTPUT ${interface_wit}
                                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_json}" "${GENERATE_INTERFACE_WIT_MUSTACHE_TEMPLATE}" > "${interface_wit}"
                                DEPENDS ${interface_json} "${GENERATE_INTERFACE_WIT_MUSTACHE_TEMPLATE}"
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
                            list(APPEND output_json_files ${wasm_cxx_h})
                            
                            add_custom_command(
                                OUTPUT ${wasm_cxx_h}
                                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_json}" "${GENERATE_WASM_H_MUSTACHE_TEMPLATE}" > "${wasm_cxx_h}"
                                DEPENDS ${interface_json} "${GENERATE_WASM_H_MUSTACHE_TEMPLATE}"
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
                            list(APPEND output_json_files ${wasm_csharp_cs})
                            
                            add_custom_command(
                                OUTPUT ${wasm_csharp_cs}
                                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_json}" "${GENERATE_WASM_CS_MUSTACHE_TEMPLATE}" > "${wasm_csharp_cs}"
                                DEPENDS ${interface_json} "${GENERATE_WASM_CS_MUSTACHE_TEMPLATE}"
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
                            list(APPEND output_json_files ${wasm_rust_rs})
                            
                            add_custom_command(
                                OUTPUT ${wasm_rust_rs}
                                COMMAND ${MUSTACHE_EXECUTABLE} "${interface_json}" "${GENERATE_WASM_RS_MUSTACHE_TEMPLATE}" > "${wasm_rust_rs}"
                                DEPENDS ${interface_json} "${GENERATE_WASM_RS_MUSTACHE_TEMPLATE}"
                                COMMENT "Generating ${header_basename}.wasm.rs from interface JSON using mustache template"
                            )
                        endif()
                    endif()
                endforeach()
                
                # Create a custom target that depends on all JSON files
                add_custom_target(
                    ${target_project}_generate_reflection
                    DEPENDS ${output_json_files}
                    COMMENT "Generating interface AST files for ${target_project}"
                )

                # Add dependency from interface target to reflection generation target
                add_dependencies(${target_project} ${target_project}_generate_reflection)

                list(LENGTH interface_headers header_count)
                message(STATUS "Interface AST generation enabled for ${target_project} (${header_count} headers) using clang: ${CLANG_EXECUTABLE}")
            else()
                message(WARNING "clang++ not found, skipping interface AST generation for ${target_project}")
            endif()
        endif()
    endif()

endfunction()
