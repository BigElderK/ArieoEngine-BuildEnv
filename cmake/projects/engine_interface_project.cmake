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
        PACKAGES
        PRIVATE_LIBS
        PRIVATE_INCLUDE_FOLDERS
        PRIVATE_LIB_FOLDERS
        INTERFACES
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
        Message(STATUS "Finding package ${ARGUMENT_PACKAGE} for ${target_project}")
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
    set(extra_include_folder_list)
    
    # Add project's own public include folders
    if(DEFINED ARGUMENT_PUBLIC_INCLUDE_FOLDERS)
        list(APPEND extra_include_folder_list ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS})
    endif()

    # Extract and add include directories from INTERFACES targets
    # This is needed for code generation (clang) to find headers from dependent interfaces
    set(referenced_lib_targetlist "")
    if(DEFINED ARGUMENT_INTERFACES)
        list(APPEND referenced_lib_targetlist ${ARGUMENT_INTERFACES})
    endif()

    if(DEFINED ARGUMENT_PUBLIC_LIBS)
        list(APPEND referenced_lib_targetlist ${ARGUMENT_PUBLIC_LIBS})
    endif()
    
    if(DEFINED ARGUMENT_PRIVATE_LIBS)
        list(APPEND referenced_lib_targetlist ${ARGUMENT_PRIVATE_LIBS})
    endif()

    foreach(referenced_lib_target ${referenced_lib_targetlist})
        # Check if target exists
        if(TARGET ${referenced_lib_target})
            # Get include directories from the interface target
            get_target_property(interface_includes ${referenced_lib_target} INTERFACE_INCLUDE_DIRECTORIES)

            if(interface_includes)
                foreach(inc_dir ${interface_includes})
                    # Handle generator expressions - extract BUILD_INTERFACE paths
                    string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]+)>" "\\1" cleaned_dir "${inc_dir}")
                    string(REGEX REPLACE "\\$<INSTALL_INTERFACE:[^>]+>" "" cleaned_dir "${cleaned_dir}")
                    if(cleaned_dir AND NOT cleaned_dir STREQUAL "")
                        list(APPEND extra_include_folder_list ${cleaned_dir})
                    endif()
                endforeach()
            endif()
            
            # Also get transitive dependencies (like fmt::fmt from arieo_core)
            # INTERFACE_INCLUDE_DIRECTORIES doesn't automatically include transitive includes
            get_target_property(transitive_libs ${referenced_lib_target} INTERFACE_LINK_LIBRARIES)
            
            if(transitive_libs AND NOT transitive_libs STREQUAL "transitive_libs-NOTFOUND")
                foreach(trans_lib ${transitive_libs})
                    if(TARGET ${trans_lib})
                        get_target_property(trans_includes ${trans_lib} INTERFACE_INCLUDE_DIRECTORIES)
                        
                        if(trans_includes AND NOT trans_includes STREQUAL "trans_includes-NOTFOUND")
                            foreach(inc_dir ${trans_includes})
                                # Clean generator expressions (including nested ones like $<$<CONFIG:RELEASE>:path>)
                                set(cleaned_dir "${inc_dir}")
                                
                                # Handle nested CONFIG generator expressions: $<$<CONFIG:RELEASE>:path> -> path
                                string(REGEX REPLACE "\\$<\\$<CONFIG:[^>]+>:([^>]+)>" "\\1" cleaned_dir "${cleaned_dir}")
                                
                                # Handle BUILD_INTERFACE: $<BUILD_INTERFACE:path> -> path
                                string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]+)>" "\\1" cleaned_dir "${cleaned_dir}")
                                
                                # Remove INSTALL_INTERFACE completely
                                string(REGEX REPLACE "\\$<INSTALL_INTERFACE:[^>]+>" "" cleaned_dir "${cleaned_dir}")
                                
                                # Remove $<0:...> and similar numeric conditions
                                string(REGEX REPLACE "\\$<[0-9]+:([^>]+)>" "" cleaned_dir "${cleaned_dir}")
                                
                                # Apply multiple passes to handle any remaining generator expressions
                                foreach(pass RANGE 3)
                                    string(REGEX REPLACE "\\$<[^<>]+>" "" cleaned_dir "${cleaned_dir}")
                                endforeach()
                                
                                # Clean up trailing artifacts
                                string(REGEX REPLACE ">+$" "" cleaned_dir "${cleaned_dir}")
                                string(STRIP "${cleaned_dir}" cleaned_dir)
                                
                                if(cleaned_dir AND EXISTS "${cleaned_dir}")
                                    list(APPEND extra_include_folder_list "${cleaned_dir}")
                                endif()
                            endforeach()
                        endif()
                    endif()
                endforeach()
            endif()
        endif()
    endforeach()

    # Get all include directories from the packages
    foreach(package ${ARGUMENT_PACKAGES})
        # Assume package provides a CMake variable with the same name as the package, suffixed with "_INCLUDE_DIRS"
        set(package_include_var "${package}_INCLUDE_DIRS")
        if(DEFINED ${package_include_var})
            list(APPEND extra_include_folder_list ${${package_include_var}})
        endif()
    endforeach()

    # print extra include folders for debugging
    message(STATUS "Extra include folders for ${target_project}: ${extra_include_folder_list}")

    # Get C++ standard library include directories (implicit compiler search paths)
    if(DEFINED CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES)
        list(APPEND extra_include_folder_list ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
    endif()

    # Also pick up any directory-level include directories
    get_property(standard_includes DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
    if(standard_includes)
        list(APPEND extra_include_folder_list ${standard_includes})
    endif()

    # Manually add extra include folders
    #include "base/prerequisites.h"
    list(APPEND extra_include_file_list $ENV{ARIEO_CORE_PACKAGE_INSTALL_FOLDER}/$ENV{ARIEO_PACKAGE_BUILD_HOST_PRESET}/include/base/prerequisites.h)

    # Remove duplicates
    list(REMOVE_DUPLICATES extra_include_folder_list)
    list(REMOVE_DUPLICATES extra_include_file_list)
    # message(FATAL_ERROR "Final include folders for ${target_project}: ${extra_include_file_list}")

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
