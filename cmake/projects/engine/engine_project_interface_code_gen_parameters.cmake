function(project_interface_code_gen_parameters target_project)
    set(oneValueArgs 
        ROOT_NAMESPACE
        SCRIPT_PACKAGE_NAME
        
        GENERATE_ROOT_FOLDER

        AST_GENERATE_FOLDER
        NATIVE_CODE_GENERATE_FOLDER
        WASM_WIT_GENERATE_FOLDER
        WASM_CXX_SCRIPT_GENERATE_FOLDER
        WASM_CSHARP_SCRIPT_GENERATE_FOLDER
        WASM_RUST_SCRIPT_GENERATE_FOLDER
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    # Skip if no code generation parameters provided
    if(NOT ARGUMENT_ROOT_NAMESPACE AND NOT ARGUMENT_SCRIPT_PACKAGE_NAME)
        message(STATUS "No interface code generation configured for ${target_project}")
        return()
    endif()

    # Resolve sub-folder paths: ${GENERATE_ROOT_FOLDER} is not a CMake variable at call-site,
    # so ${GENERATE_ROOT_FOLDER}/ast expands to /ast (empty prefix + /ast).
    # Detect paths that lost their root and prepend ARGUMENT_GENERATE_ROOT_FOLDER.
    if(ARGUMENT_GENERATE_ROOT_FOLDER)
        set(ARGUMENT_AST_GENERATE_FOLDER "${ARGUMENT_GENERATE_ROOT_FOLDER}${ARGUMENT_AST_GENERATE_FOLDER}")
        set(ARGUMENT_NATIVE_CODE_GENERATE_FOLDER "${ARGUMENT_GENERATE_ROOT_FOLDER}${ARGUMENT_NATIVE_CODE_GENERATE_FOLDER}")
        set(ARGUMENT_WASM_WIT_GENERATE_FOLDER "${ARGUMENT_GENERATE_ROOT_FOLDER}${ARGUMENT_WASM_WIT_GENERATE_FOLDER}")
        set(ARGUMENT_WASM_CXX_SCRIPT_GENERATE_FOLDER "${ARGUMENT_GENERATE_ROOT_FOLDER}${ARGUMENT_WASM_CXX_SCRIPT_GENERATE_FOLDER}")
        set(ARGUMENT_WASM_CSHARP_SCRIPT_GENERATE_FOLDER "${ARGUMENT_GENERATE_ROOT_FOLDER}${ARGUMENT_WASM_CSHARP_SCRIPT_GENERATE_FOLDER}")
        set(ARGUMENT_WASM_RUST_SCRIPT_GENERATE_FOLDER "${ARGUMENT_GENERATE_ROOT_FOLDER}${ARGUMENT_WASM_RUST_SCRIPT_GENERATE_FOLDER}")
    endif()

    # Set paramter to parent scope for use in install steps
    set(INTERFACE_CODEGEN_ROOT_FOLDER ${ARGUMENT_GENERATE_ROOT_FOLDER} PARENT_SCOPE)

    message(STATUS "Configuring interface code generation for ${target_project}")
    message(STATUS "  ROOT_NAMESPACE: ${ARGUMENT_ROOT_NAMESPACE}")
    message(STATUS "  SCRIPT_PACKAGE_NAME: ${ARGUMENT_SCRIPT_PACKAGE_NAME}")
    message(STATUS "  GENERATE_ROOT_FOLDER: ${ARGUMENT_GENERATE_ROOT_FOLDER}")

    # Get interface include folders from target
    get_target_property(interface_includes ${target_project} INTERFACE_INCLUDE_DIRECTORIES)
    
    # Find all header files in interface include folders
    set(interface_headers)
    if(interface_includes)
        foreach(include_folder ${interface_includes})
            # Clean generator expressions
            string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]+)>" "\\1" cleaned_folder "${include_folder}")
            string(REGEX REPLACE "\\$<INSTALL_INTERFACE:[^>]+>" "" cleaned_folder "${cleaned_folder}")
            
            if(cleaned_folder AND EXISTS "${cleaned_folder}")
                file(GLOB_RECURSE headers "${cleaned_folder}/*.h" "${cleaned_folder}/*.hpp")
                list(APPEND interface_headers ${headers})
            endif()
        endforeach()
    endif()

    message(STATUS "Interface headers for ${target_project}: ${interface_headers}")

    # Remove duplicates
    if(interface_headers)
        list(REMOVE_DUPLICATES interface_headers)
    endif()

    # Build extra include folders for code generation
    set(extra_include_folder_list)

    # Add interface include folders from target
    if(interface_includes)
        foreach(inc_dir ${interface_includes})
            string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]+)>" "\\1" cleaned_dir "${inc_dir}")
            string(REGEX REPLACE "\\$<INSTALL_INTERFACE:[^>]+>" "" cleaned_dir "${cleaned_dir}")
            if(cleaned_dir AND EXISTS "${cleaned_dir}")
                list(APPEND extra_include_folder_list ${cleaned_dir})
            endif()
        endforeach()
    endif()

    # Extract include directories from linked libraries
    # get_target_property(interface_libs ${target_project} INTERFACE_LINK_LIBRARIES)
    # if(interface_libs)
    #     foreach(linterface_lib ${interface_libs})
    #         if(TARGET ${linterface_lib})
    #             collect_include_dirs_from_target(${linterface_lib} extra_include_folder_list)
    #         endif()
    #     endforeach()
    # endif()
    if(TARGET arieo_core)
        collect_include_dirs_from_target(arieo_core extra_include_folder_list)
    endif()
    if(TARGET Arieo-Core::arieo_core)
        collect_include_dirs_from_target(Arieo-Core::arieo_core extra_include_folder_list)
    endif()

    # Get C++ standard library include directories
    if(DEFINED CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES)
        list(APPEND extra_include_folder_list ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
    endif()

    # Get directory-level include directories
    get_property(standard_includes DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
    if(standard_includes)
        list(APPEND extra_include_folder_list ${standard_includes})
    endif()

    # Add extra include files
    # Find prerequisites.h from extra_include_folder_list
    set(extra_include_file_list)
    find_file(arieo_prerequisites_h_file
        NAMES "prerequisites.h"
        PATHS ${extra_include_folder_list}
        PATH_SUFFIXES "base"
        NO_DEFAULT_PATH
        NO_CACHE
    )
    if(arieo_prerequisites_h_file)
        list(APPEND extra_include_file_list "${arieo_prerequisites_h_file}")
        message(STATUS "Found prerequisites.h for ${target_project}: ${arieo_prerequisites_h_file}")
    else()
        message(FATAL_ERROR "Could not find prerequisites.h in include dirs for ${target_project}")
    endif()

    # Remove duplicates
    if(extra_include_folder_list)
        list(REMOVE_DUPLICATES extra_include_folder_list)
    endif()
    if(extra_include_file_list)
        list(REMOVE_DUPLICATES extra_include_file_list)
    endif()

    message(STATUS "Extra include folders for ${target_project}: ${extra_include_folder_list}")

    # Call the interface code generation function
    arieo_generate_interface_code(
        ${target_project}
        INTERFACE_HEADERS ${interface_headers}
        
        EXTRA_INCLUDE_FILES ${extra_include_file_list}
        EXTRA_INCLUDE_FOLDERS ${extra_include_folder_list}

        SCRIPT_PACKAGE_NAME "${ARGUMENT_SCRIPT_PACKAGE_NAME}"
        ROOT_NAMESPACE "${ARGUMENT_ROOT_NAMESPACE}"
        AST_GENERATE_FOLDER "${ARGUMENT_AST_GENERATE_FOLDER}"
        
        NATIVE_CODE_GENERATE_FOLDER "${ARGUMENT_NATIVE_CODE_GENERATE_FOLDER}"
        WASM_WIT_GENERATE_FOLDER "${ARGUMENT_WASM_WIT_GENERATE_FOLDER}"
        WASM_CXX_SCRIPT_GENERATE_FOLDER "${ARGUMENT_WASM_CXX_SCRIPT_GENERATE_FOLDER}"
        WASM_CSHARP_SCRIPT_GENERATE_FOLDER "${ARGUMENT_WASM_CSHARP_SCRIPT_GENERATE_FOLDER}"
        WASM_RUST_SCRIPT_GENERATE_FOLDER "${ARGUMENT_WASM_RUST_SCRIPT_GENERATE_FOLDER}"
    )
endfunction()

# Helper function to collect include directories from a target and its transitive dependencies
function(collect_include_dirs_from_target target_name out_list)
    if(NOT TARGET ${target_name})
        return()
    endif()

    # Get direct include directories
    get_target_property(includes ${target_name} INTERFACE_INCLUDE_DIRECTORIES)
    if(includes)
        foreach(inc_dir ${includes})
            _clean_generator_expression("${inc_dir}" cleaned_dir)
            if(cleaned_dir AND EXISTS "${cleaned_dir}")
                list(APPEND ${out_list} "${cleaned_dir}")
            endif()
        endforeach()
    endif()

    # Get transitive dependencies
    get_target_property(transitive_libs ${target_name} INTERFACE_LINK_LIBRARIES)
    if(transitive_libs)
        foreach(trans_lib ${transitive_libs})
            if(NOT TARGET ${trans_lib})
                # For Namespace::target style libs, try to find_package to bring them into scope
                if(trans_lib MATCHES "^([A-Za-z0-9_-]+)::.+")
                    string(REGEX REPLACE "^([A-Za-z0-9_-]+)::.+" "\\1" _pkg_name "${trans_lib}")
                    find_package(${_pkg_name} QUIET)
                endif()
            endif()
            if(TARGET ${trans_lib})
                get_target_property(trans_includes ${trans_lib} INTERFACE_INCLUDE_DIRECTORIES)
                if(trans_includes)
                    foreach(inc_dir ${trans_includes})
                        _clean_generator_expression("${inc_dir}" cleaned_dir)
                        if(cleaned_dir AND EXISTS "${cleaned_dir}")
                            list(APPEND ${out_list} "${cleaned_dir}")
                        endif()
                    endforeach()
                endif()
            endif()
        endforeach()
    endif()

    set(${out_list} ${${out_list}} PARENT_SCOPE)
endfunction()

# Helper function to clean CMake generator expressions from paths
function(_clean_generator_expression input_path out_var)
    set(cleaned "${input_path}")
    
    # Handle nested CONFIG generator expressions: $<$<CONFIG:RELEASE>:path> -> path
    string(REGEX REPLACE "\\$<\\$<CONFIG:[^>]+>:([^>]+)>" "\\1" cleaned "${cleaned}")
    
    # Handle BUILD_INTERFACE: $<BUILD_INTERFACE:path> -> path
    string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]+)>" "\\1" cleaned "${cleaned}")
    
    # Remove INSTALL_INTERFACE completely
    string(REGEX REPLACE "\\$<INSTALL_INTERFACE:[^>]+>" "" cleaned "${cleaned}")
    
    # Remove numeric conditions $<0:...> etc
    string(REGEX REPLACE "\\$<[0-9]+:([^>]+)>" "" cleaned "${cleaned}")
    
    # Multiple passes for remaining generator expressions
    foreach(pass RANGE 3)
        string(REGEX REPLACE "\\$<[^<>]+>" "" cleaned "${cleaned}")
    endforeach()
    
    # Clean up trailing artifacts
    string(REGEX REPLACE ">+$" "" cleaned "${cleaned}")
    string(STRIP "${cleaned}" cleaned)
    
    set(${out_var} "${cleaned}" PARENT_SCOPE)
endfunction()
