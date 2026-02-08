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
        PRIVATE_LIBS
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
    if(DEFINED ARGUMENT_PRIVATE_LIBS)
        target_link_libraries(
            ${target_project} 
            INTERFACE
                ${ARGUMENT_PRIVATE_LIBS}
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

    # Set public include directories using generator expressions
    # INTERFACE libraries require generator expressions to distinguish build vs install paths
    foreach(INCLUDE_FOLDER ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS})
        target_include_directories(
            ${target_project}
            INTERFACE 
                $<BUILD_INTERFACE:${INCLUDE_FOLDER}>
                $<INSTALL_INTERFACE:include>
        )
    endforeach()

    # Generate interfaces.json for interface projects
    # Find all header files in public include folders
    set(interface_headers)
    foreach(include_folder ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS})
        file(GLOB_RECURSE headers "${include_folder}/*.h" "${include_folder}/*.hpp")
        list(APPEND interface_headers ${headers})
    endforeach()
    
    # Remove duplicates from the list
    list(REMOVE_DUPLICATES interface_headers)

    # Build extra include folders for code generation
    set(extra_include_folders)
    
    # Add project's own public include folders
    if(DEFINED ARGUMENT_PUBLIC_INCLUDE_FOLDERS)
        list(APPEND extra_include_folders ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS})
    endif()

    # Extract and add include directories from INTERFACES targets
    # This is needed for code generation (clang) to find headers from dependent interfaces
    if(DEFINED ARGUMENT_INTERFACES)
        foreach(interface_target ${ARGUMENT_INTERFACES})
            # Check if target exists
            if(TARGET ${interface_target})
                # Get include directories from the interface target
                get_target_property(interface_includes ${interface_target} INTERFACE_INCLUDE_DIRECTORIES)
                if(interface_includes)
                    foreach(inc_dir ${interface_includes})
                        # Handle generator expressions - extract BUILD_INTERFACE paths
                        string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]+)>" "\\1" cleaned_dir "${inc_dir}")
                        string(REGEX REPLACE "\\$<INSTALL_INTERFACE:[^>]+>" "" cleaned_dir "${cleaned_dir}")
                        if(cleaned_dir AND NOT cleaned_dir STREQUAL "")
                            list(APPEND extra_include_folders ${cleaned_dir})
                        endif()
                    endforeach()
                endif()
            endif()
        endforeach()
    endif()

    # Extract and add include directories from PRIVATE_LIBS targets
    # This is needed for code generation (clang) to find headers from dependent interfaces
    if(DEFINED ARGUMENT_PRIVATE_LIBS)
        foreach(private_lib ${ARGUMENT_PRIVATE_LIBS})
            # Check if target exists
            if(TARGET ${private_lib})
                # Get include directories from the target
                get_target_property(lib_includes ${private_lib} INTERFACE_INCLUDE_DIRECTORIES)
                if(lib_includes AND NOT lib_includes STREQUAL "lib_includes-NOTFOUND")
                    foreach(inc_dir ${lib_includes})
                        # Handle generator expressions - extract BUILD_INTERFACE paths
                        string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]+)>" "\\1" cleaned_dir "${inc_dir}")
                        string(REGEX REPLACE "\\$<INSTALL_INTERFACE:[^>]+>" "" cleaned_dir "${cleaned_dir}")
                        if(cleaned_dir AND NOT cleaned_dir STREQUAL "")
                            list(APPEND extra_include_folders ${cleaned_dir})
                        endif()
                    endforeach()
                endif()
            endif()
        endforeach()
    endif()

    # print extra include folders for debugging
    message(STATUS "Extra include folders for ${target_project}: ${extra_include_folders}")

    # Call the interface code generation function
    arieo_generate_interface_code(
        ${target_project}
        INTERFACE_HEADERS ${interface_headers}
        EXTRA_INCLUDE_FOLDERS ${extra_include_folders}

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
