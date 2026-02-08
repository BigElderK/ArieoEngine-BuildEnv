cmake_minimum_required(VERSION 3.31)

# ==================== Reusable Install Configuration Function ====================
# This function configures CMake installation for a target project
# Handles: library installation, header installation, target export, and config file generation
function(arieo_engine_project_install_configure target_project)
    # Include CMake helpers for package config generation
    # These are included here (not at file scope) to avoid warnings when 
    # this file is included early, before project() enables languages
    include(GNUInstallDirs)
    include(CMakePackageConfigHelpers)
    
    set(oneValueArgs
        LIBRARY_TYPE  # STATIC, SHARED, or empty for header-only
    )
    
    set(multiValueArgs
        PACKAGES  # List of required packages that consumers need to find
    )
    
    cmake_parse_arguments(
        ARG
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})
    
    # Determine package name for config files from CUR_ARIEO_PACKAGE_NAME environment variable
    if(NOT DEFINED ENV{CUR_ARIEO_PACKAGE_NAME})
        message(FATAL_ERROR "CUR_ARIEO_PACKAGE_NAME environment variable is not defined")
    endif()
    
    set(package_name "$ENV{CUR_ARIEO_PACKAGE_NAME}")
    message(STATUS "Using package name from CUR_ARIEO_PACKAGE_NAME: ${package_name}")
    
    # Get include directories from target properties
    get_target_property(PUBLIC_INCLUDE_DIRS ${target_project} INTERFACE_INCLUDE_DIRECTORIES)
        
    # Install the library target
    # Note: INCLUDES DESTINATION only sets metadata (tells consumers where to look for headers)
    #       It does NOT copy any files - we need separate install(DIRECTORY) commands below
    # Libraries are installed to build-type subdirectories to support multi-config installs
    install(TARGETS ${target_project}
        EXPORT ${target_project}Targets
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/$<CONFIG>
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/$<CONFIG>
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}/$<CONFIG>
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
            elseif(NOT INCLUDE_DIR MATCHES "\\$<INSTALL_INTERFACE:")
                # If it's not a generator expression, use it directly
                list(APPEND EXTRACTED_INCLUDE_DIRS "${INCLUDE_DIR}")
            endif()
        endforeach()
    endif()
    
    set(PUBLIC_INCLUDE_DIRS "${EXTRACTED_INCLUDE_DIRS}")
    if(PUBLIC_INCLUDE_DIRS)
        foreach(INCLUDE_FOLDER ${PUBLIC_INCLUDE_DIRS})
            if(EXISTS ${INCLUDE_FOLDER})
                install(DIRECTORY ${INCLUDE_FOLDER}/
                    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                    FILES_MATCHING
                    PATTERN "*.h"
                    PATTERN "*.hpp"
                    PATTERN "*.hxx"
                    PATTERN "*.inl"
                )
            endif()
        endforeach()
    endif()

    # Export targets for use by other CMake projects
    # Use package_name for the export file to match find_package() expectations
    install(EXPORT ${target_project}Targets
        FILE ${package_name}Targets.cmake
        NAMESPACE ${package_name}::
        DESTINATION cmake
    )

    # Generate and install package configuration file
    # Use common template and substitute package_name and target_project
    # Note: configure_package_config_file() handles both @variable@ substitution 
    # AND @PACKAGE_...@ path transformations, so we don't need configure_file() first
    set(CONFIG_TEMPLATE_FILE ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/engine_project_install_config.cmake.in)
    
    # Set variable for template substitution
    set(target_project_name ${target_project})
    
    # Generate find_dependency calls for required packages
    set(package_dependencies_code "")
    if(ARG_PACKAGES)
        foreach(pkg ${ARG_PACKAGES})
            string(APPEND package_dependencies_code "find_dependency(${pkg} REQUIRED)\n")
        endforeach()
    endif()
    
    configure_package_config_file(
        ${CONFIG_TEMPLATE_FILE}
        ${CMAKE_CURRENT_BINARY_DIR}/${package_name}Config.cmake
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
        ${CMAKE_CURRENT_BINARY_DIR}/${package_name}ConfigVersion.cmake
        VERSION ${PACKAGE_VERSION}
        COMPATIBILITY SameMajorVersion
    )

    # Install config files
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/${package_name}Config.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/${package_name}ConfigVersion.cmake
        DESTINATION cmake
    )
    
endfunction()
