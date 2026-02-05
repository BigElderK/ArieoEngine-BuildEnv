cmake_minimum_required(VERSION 3.31)

function(arieo_test_project target_project)
    set(oneValueArgs 
        ALIAS
        MODULE_CONFIG_FILE
        AST_GENERATE_FOLDER
        NATIVE_CODE_GENERATE_FOLDER
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
    add_executable(${target_project})
    
    if(DEFINED ARGUMENT_ALIAS)
        add_executable(${ARGUMENT_ALIAS} ALIAS ${target_project})
    endif()

    foreach(ARGUMENT_PACKAGE IN LISTS ARGUMENT_PACKAGES)
        find_package(${ARGUMENT_PACKAGE} REQUIRED)
    endforeach()
   
    # Add definitions
    add_compile_definitions(${target_project} PRIVATE 
        ARIEO_HOST_OS="${ARIEO_HOST_OS}"
    )

    # Add private include folders
    if(DEFINED ARGUMENT_PRIVATE_INCLUDE_FOLDERS)
        target_include_directories(
            ${target_project}
            PRIVATE 
                ${ARGUMENT_PRIVATE_INCLUDE_FOLDERS}
        )
    endif()

    # Add private lib folders
    if(DEFINED ARGUMENT_PRIVATE_LIB_FOLDERS)
        target_link_directories(
            ${target_project}
            PRIVATE 
                ${ARGUMENT_PRIVATE_LIB_FOLDERS}
        )
    endif()

    # Add libs
    if(DEFINED ARGUMENT_LIBS)
        target_link_libraries(
            ${target_project} 
            PRIVATE
                ${ARGUMENT_LIBS}
        )
    endif()

    # Add interfaces
    if(DEFINED ARGUMENT_INTERFACES)
        target_link_libraries(
            ${target_project} 
            PRIVATE
                ${ARGUMENT_INTERFACES}
        )
    endif()

    # Add sources - resolve relative paths 
    set(resolved_patterns)
    foreach(pattern ${ARGUMENT_SOURCES})
        if(IS_ABSOLUTE ${pattern})
            list(APPEND resolved_patterns ${pattern})
        else()
            list(APPEND resolved_patterns ${CMAKE_CURRENT_SOURCE_DIR}/${pattern})
        endif()
    endforeach()
    
    message(STATUS "Input patterns for ${target_project}: ${ARGUMENT_SOURCES}")
    message(STATUS "Resolved patterns for ${target_project}: ${resolved_patterns}")
    file(GLOB default_source_files
        ${resolved_patterns}
    )

    target_sources(
        ${target_project}
        PRIVATE 
            ${default_source_files})

    # Set output directories
    set_target_properties(
        ${target_project}
        PROPERTIES 
            RUNTIME_OUTPUT_DIRECTORY ${ARIEO_TESTS_OUTPUT_DIRECTORY}
            ARCHIVE_OUTPUT_DIRECTORY ${ARIEO_TESTS_OUTPUT_DIRECTORY}
            LIBRARY_OUTPUT_DIRECTORY ${ARIEO_TESTS_OUTPUT_DIRECTORY}
    )

    # Copy external libs to libs folder
    if(DEFINED ARGUMENT_EXTERNAL_LIBS)
        set(resolved_patterns)
        foreach(pattern ${ARGUMENT_EXTERNAL_LIBS})
            if(IS_ABSOLUTE ${pattern})
                list(APPEND resolved_patterns ${pattern})
            else()
                list(APPEND resolved_patterns ${CMAKE_CURRENT_SOURCE_DIR}/${pattern})
            endif()
        endforeach()

        file(GLOB default_external_libs
            ${resolved_patterns}
        )

        foreach(src_external_lib IN LISTS default_external_libs)
            # get filename with extension from path
            get_filename_component(src_lib_filename ${src_external_lib} NAME)
            set(dest_external_lib "${ARIEO_LIBS_OUTPUT_DIRECTORY}/${src_lib_filename}")

            message(STATUS "Copying external lib ${src_lib_filename} to ${ARIEO_LIBS_OUTPUT_DIRECTORY}/${src_lib_filename}")

            add_custom_command(
                TARGET ${target_project} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${src_external_lib}
                    ${dest_external_lib}
            )
        endforeach()
    endif()

endfunction()
