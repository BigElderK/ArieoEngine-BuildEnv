function(project_dependencies_parameters target_project)
    
    set(multiValueArgs 
        ARIEO_PACKAGES
        THIRDPARTY_PACKAGES
        INTERFACES
        PUBLIC_LIBS
        PRIVATE_LIBS
        EXTERNAL_LIBS
        PRIVATE_LIB_FOLDERS
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        ""
        "${multiValueArgs}"
        ${ARGN}
    )

    # Debug logging for parsed dependencies
    message(STATUS "Configuring dependencies for ${target_project}:")
    if(DEFINED ARGUMENT_THIRDPARTY_PACKAGES)
        message(STATUS "  THIRDPARTY_PACKAGES: ${ARGUMENT_THIRDPARTY_PACKAGES}")
    endif()
    if(DEFINED ARGUMENT_INTERFACES)
        message(STATUS "  INTERFACES: ${ARGUMENT_INTERFACES}")
    endif()
    if(DEFINED ARGUMENT_PUBLIC_LIBS)
        message(STATUS "  PUBLIC_LIBS: ${ARGUMENT_PUBLIC_LIBS}")
    endif()
    if(DEFINED ARGUMENT_PRIVATE_LIBS)
        message(STATUS "  PRIVATE_LIBS: ${ARGUMENT_PRIVATE_LIBS}")
    endif()
    if(DEFINED ARGUMENT_ARIEO_PACKAGES)
        message(STATUS "  ARIEO_PACKAGES: ${ARGUMENT_ARIEO_PACKAGES}")
    endif()

    # Validate target exists
    if(NOT TARGET ${target_project})
        message(FATAL_ERROR "Target ${target_project} does not exist. Cannot configure dependencies.")
    endif()

    if(DEFINED ARGUMENT_ARIEO_PACKAGES)
        foreach(ARGUMENT_PACKAGE IN LISTS ARGUMENT_ARIEO_PACKAGES)
            message(STATUS "Finding package: ${ARGUMENT_PACKAGE}")

            # Check if ARUGMENT_PACKAGE target is exists
            if(TARGET ${ARGUMENT_PACKAGE})
                message(STATUS "Found target for package ${ARGUMENT_PACKAGE}")
                continue()
            endif()

            # Other wise, try found it as a package
            find_package(${ARGUMENT_PACKAGE} REQUIRED)
            if(NOT ${ARGUMENT_PACKAGE}_FOUND)
                message(FATAL_ERROR "Package ${ARGUMENT_PACKAGE} not found. Check CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
            endif()

        endforeach()
    endif()

    # add packages
    foreach(ARGUMENT_PACKAGE IN LISTS ARGUMENT_THIRDPARTY_PACKAGES)
        message(STATUS "Finding package: ${ARGUMENT_PACKAGE}")
        find_package(${ARGUMENT_PACKAGE} REQUIRED)
        if(NOT ${ARGUMENT_PACKAGE}_FOUND)
            message(FATAL_ERROR "Package ${ARGUMENT_PACKAGE} not found. Check CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
        endif()
    endforeach()

    # Add private lib folders (not for INTERFACE libraries)
    if(DEFINED ARGUMENT_PRIVATE_LIB_FOLDERS)
        if(is_interface_library)
            message(WARNING "INTERFACE library ${target_project} cannot have PRIVATE_LIB_FOLDERS. Ignoring.")
        else()
            target_link_directories(
                ${target_project}
                PRIVATE 
                    ${ARGUMENT_PRIVATE_LIB_FOLDERS}
            )
        endif()
    endif()

    # Add interfaces
    if(DEFINED ARGUMENT_INTERFACES)
        set_target_libraries(
            ${target_project}
            INTERFACE
                ${ARGUMENT_INTERFACES}
        )
    endif()

    # Add public libs (dependencies used in public headers)
    if(DEFINED ARGUMENT_PUBLIC_LIBS)
        set_target_libraries(
            ${target_project}
            PUBLIC
                ${ARGUMENT_PUBLIC_LIBS}
        )
    endif()

    # Add private libs
    if(DEFINED ARGUMENT_PRIVATE_LIBS)
        set_target_libraries(
            ${target_project}
            PRIVATE
                ${ARGUMENT_PRIVATE_LIBS}
        )
    endif()

    # Copy external libs to libs folder (not for INTERFACE libraries)
    if(DEFINED ARGUMENT_EXTERNAL_LIBS)
        if(is_interface_library)
            message(WARNING "INTERFACE library ${target_project} cannot have EXTERNAL_LIBS. Use a non-interface library to copy external libraries.")
        else()
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

            if(NOT default_external_libs)
                message(WARNING "No external libs found matching patterns: ${resolved_patterns}")
            endif()

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
    endif()
endfunction()

function(set_target_libraries target_project)
    set(multiValueArgs 
        PUBLIC
        PRIVATE
        INTERFACE
    )
    cmake_parse_arguments(
        ARGUMENT
        ""
        ""
        "${multiValueArgs}"
        ${ARGN}
    )

    # Check if target is an INTERFACE library
    get_target_property(target_type ${target_project} TYPE)
    if(target_type STREQUAL "INTERFACE_LIBRARY")
        set(is_interface_library TRUE)
    else()
        set(is_interface_library FALSE)
    endif()

    target_link_libraries(
        ${target_project}
        PUBLIC
            ${ARGUMENT_PUBLIC}
        PRIVATE
            ${ARGUMENT_PRIVATE}
        INTERFACE
            ${ARGUMENT_INTERFACE}
    )
endfunction()