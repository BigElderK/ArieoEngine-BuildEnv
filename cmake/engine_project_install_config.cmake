cmake_minimum_required(VERSION 3.31)

# Include CMake helpers for package config generation
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# ==================== Reusable Install Configuration Function ====================
# This function configures CMake installation for a target project
# Handles: library installation, header installation, target export, and config file generation
function(arieo_engine_project_install_configure target_project)
    set(oneValueArgs
        LIBRARY_TYPE  # STATIC, SHARED, or empty for header-only
    )
    
    cmake_parse_arguments(
        ARG
        ""
        "${oneValueArgs}"
        ""
        ${ARGN})
    
    # Get include directories from target properties
    get_target_property(PUBLIC_INCLUDE_DIRS ${target_project} INTERFACE_INCLUDE_DIRECTORIES)
    message(STATUS "DEBUG: Target '${target_project}' INTERFACE_INCLUDE_DIRECTORIES raw value: '${PUBLIC_INCLUDE_DIRS}'")
        
    # Install the library target
    # Note: INCLUDES DESTINATION only sets metadata (tells consumers where to look for headers)
    #       It does NOT copy any files - we need separate install(DIRECTORY) commands below
    install(TARGETS ${target_project}
        EXPORT ${target_project}Targets
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    # Install public headers - actually copies the header files to the install destination
    # Extract paths from generator expressions
    set(EXTRACTED_INCLUDE_DIRS "")
    if(PUBLIC_INCLUDE_DIRS AND NOT PUBLIC_INCLUDE_DIRS STREQUAL "PUBLIC_INCLUDE_DIRS-NOTFOUND")
        foreach(INCLUDE_DIR ${PUBLIC_INCLUDE_DIRS})
            # Extract path from $<BUILD_INTERFACE:path> generator expression
            if(INCLUDE_DIR MATCHES "\\$<BUILD_INTERFACE:(.+)>")
                list(APPEND EXTRACTED_INCLUDE_DIRS "${CMAKE_MATCH_1}")
                message(STATUS "DEBUG: Extracted BUILD_INTERFACE path: ${CMAKE_MATCH_1}")
            elseif(NOT INCLUDE_DIR MATCHES "\\$<INSTALL_INTERFACE:")
                # If it's not a generator expression, use it directly
                list(APPEND EXTRACTED_INCLUDE_DIRS "${INCLUDE_DIR}")
                message(STATUS "DEBUG: Using direct path: ${INCLUDE_DIR}")
            endif()
        endforeach()
    endif()
    
    set(PUBLIC_INCLUDE_DIRS "${EXTRACTED_INCLUDE_DIRS}")
    if(PUBLIC_INCLUDE_DIRS)
        message(STATUS "Installing public headers for ${target_project}")
        message(STATUS "  CMAKE_INSTALL_INCLUDEDIR: ${CMAKE_INSTALL_INCLUDEDIR}")
        message(STATUS "  PUBLIC_INCLUDE_DIRS: ${PUBLIC_INCLUDE_DIRS}")
        foreach(INCLUDE_FOLDER ${PUBLIC_INCLUDE_DIRS})
            message(STATUS "  Checking folder: ${INCLUDE_FOLDER}")
            if(EXISTS ${INCLUDE_FOLDER})
                message(STATUS "    -> Installing headers from ${INCLUDE_FOLDER}")
                install(DIRECTORY ${INCLUDE_FOLDER}/
                    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                    FILES_MATCHING
                    PATTERN "*.h"
                    PATTERN "*.hpp"
                    PATTERN "*.hxx"
                    PATTERN "*.inl"
                )
            else()
                message(WARNING "    -> Folder does not exist: ${INCLUDE_FOLDER}")
            endif()
        endforeach()
    else()
        message(STATUS "No public headers to install for ${target_project}")
    endif()

    # Export targets for use by other CMake projects
    install(EXPORT ${target_project}Targets
        FILE ${target_project}Targets.cmake
        NAMESPACE arieo::
        DESTINATION cmake
    )

    # Generate and install package configuration file
    # Use common template and substitute target_project name
    # Note: configure_package_config_file() handles both @variable@ substitution 
    # AND @PACKAGE_...@ path transformations, so we don't need configure_file() first
    set(CONFIG_TEMPLATE_FILE ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/engine_project_install_config.cmake.in)
    
    configure_package_config_file(
        ${CONFIG_TEMPLATE_FILE}
        ${CMAKE_CURRENT_BINARY_DIR}/${target_project}Config.cmake
        INSTALL_DESTINATION cmake
        PATH_VARS CMAKE_INSTALL_INCLUDEDIR CMAKE_INSTALL_LIBDIR
    )

    # Generate version file
    if(PROJECT_VERSION)
        set(PACKAGE_VERSION ${PROJECT_VERSION})
    else()
        set(PACKAGE_VERSION "1.0.0")
    endif()

    write_basic_package_version_file(
        ${CMAKE_CURRENT_BINARY_DIR}/${target_project}ConfigVersion.cmake
        VERSION ${PACKAGE_VERSION}
        COMPATIBILITY SameMajorVersion
    )

    # Install config files
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/${target_project}Config.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/${target_project}ConfigVersion.cmake
        DESTINATION cmake
    )
    
endfunction()
