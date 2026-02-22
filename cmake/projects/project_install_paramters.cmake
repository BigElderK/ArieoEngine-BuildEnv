include(CMakePackageConfigHelpers)
function(project_install_paramters target_project)
    include(GNUInstallDirs)
    set(oneValueArgs ""
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    # Determine package name for config files from ARIEO_PACKAGE_NAME variable
    if(NOT DEFINED ARIEO_PACKAGE_NAME)
        message(FATAL_ERROR "ARIEO_PACKAGE_NAME variable is not defined")
    endif()
    
    # Determine package category for config files from CMAKE_INSTALL_PREFIX variable
    if(NOT DEFINED CMAKE_INSTALL_PREFIX)
        message(FATAL_ERROR "CMAKE_INSTALL_PREFIX variable is not defined")
    endif()

    # Track all targets for this package using a cache variable
    # This allows multiple targets to be accumulated under the same package
    if(NOT DEFINED ARIEO_PACKAGE_TARGETS_${ARIEO_PACKAGE_NAME})
        set(ARIEO_PACKAGE_TARGETS_${ARIEO_PACKAGE_NAME} "" CACHE INTERNAL "List of targets for package ${ARIEO_PACKAGE_NAME}")
    endif()
    list(APPEND ARIEO_PACKAGE_TARGETS_${ARIEO_PACKAGE_NAME} ${target_project})
    set(ARIEO_PACKAGE_TARGETS_${ARIEO_PACKAGE_NAME} "${ARIEO_PACKAGE_TARGETS_${ARIEO_PACKAGE_NAME}}" CACHE INTERNAL "List of targets for package ${ARIEO_PACKAGE_NAME}")
    
    message(STATUS "Registered target ${target_project} for package ${ARIEO_PACKAGE_NAME}")
    message(STATUS "Current targets for ${ARIEO_PACKAGE_NAME}: ${ARIEO_PACKAGE_TARGETS_${ARIEO_PACKAGE_NAME}}")

    # Install the library target
    # Note: INCLUDES DESTINATION only sets metadata (tells consumers where to look for headers)
    #       It does NOT copy any files - we need separate install(DIRECTORY) commands below
    # Libraries are installed to build-type subdirectories to support multi-config installs
    # IMPORTANT: Use ARIEO_PACKAGE_NAME for EXPORT to group all targets under same export
    # Note: Both LIBRARY (.so/.dylib) and RUNTIME (.dll) go to bin folder for unified runtime loading
    set(install_archive_dir "${CMAKE_INSTALL_PREFIX}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/bin/${CMAKE_BUILD_TYPE}")
    set(install_lib_dir "${CMAKE_INSTALL_PREFIX}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/lib/${CMAKE_BUILD_TYPE}")
    set(install_runtime_dir "${CMAKE_INSTALL_PREFIX}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/bin/${CMAKE_BUILD_TYPE}")
    set(install_includes_dir "${CMAKE_INSTALL_PREFIX}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/include")
    set(install_cmake_dir "${CMAKE_INSTALL_PREFIX}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/cmake")
    set(install_interface_codegen_dir "${CMAKE_INSTALL_PREFIX}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/interface")

    install(TARGETS ${target_project}
        EXPORT ${ARIEO_PACKAGE_NAME}Targets
        ARCHIVE DESTINATION ${install_archive_dir}
        LIBRARY DESTINATION ${install_lib_dir}
        RUNTIME DESTINATION ${install_runtime_dir}
        INCLUDES DESTINATION ${install_includes_dir}
    )

    # Install public headers - actually copies the header files to the install destination
    # Extract paths from generator expressions
    set(export_include_dirs "")
    
    # Get include directories from target properties
    get_target_property(interface_include_dirs ${target_project} INTERFACE_INCLUDE_DIRECTORIES)
    if(interface_include_dirs AND NOT interface_include_dirs STREQUAL "interface_include_dirs-NOTFOUND")
        foreach(include_dir ${interface_include_dirs})
            # Extract path from $<BUILD_INTERFACE:path> generator expression
            if(include_dir MATCHES "\\$<BUILD_INTERFACE:(.+)>")
                list(APPEND export_include_dirs "${CMAKE_MATCH_1}")
            elseif(NOT include_dir MATCHES "\\$<INSTALL_INTERFACE:")
                # If it's not a generator expression, use it directly
                list(APPEND export_include_dirs "${include_dir}")
            endif()
        endforeach()
    endif()
    
    if(export_include_dirs)
        foreach(include_dir ${export_include_dirs})
            if(EXISTS ${include_dir})
                install(DIRECTORY ${include_dir}/
                    DESTINATION ${install_includes_dir}
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
    # Use ARIEO_PACKAGE_NAME for the export file to match find_package() expectations
    # This export includes all targets registered under this package name
    install(EXPORT ${ARIEO_PACKAGE_NAME}Targets
        FILE ${ARIEO_PACKAGE_NAME}Targets.cmake
        NAMESPACE ${ARIEO_PACKAGE_NAME}::
        DESTINATION ${install_cmake_dir}
    )

    # Generate and install package configuration file
    # Use common template and substitute ARIEO_PACKAGE_NAME and target_project
    # Note: configure_package_config_file() handles both @variable@ substitution 
    # AND @PACKAGE_...@ path transformations, so we don't need configure_file() first
    set(CONFIG_TEMPLATE_FILE ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/templates/project_install_config.cmake.in)
    
    # Build list of all exported targets with package namespace
    set(package_exported_targets "")
    foreach(target ${ARIEO_PACKAGE_TARGETS_${ARIEO_PACKAGE_NAME}})
        if(package_exported_targets)
            string(APPEND package_exported_targets " ")
        endif()
        string(APPEND package_exported_targets "${ARIEO_PACKAGE_NAME}::${target}")
    endforeach()
    
    # Set variables for template substitution
    set(target_project_name ${target_project})
    set(package_targets_list ${package_exported_targets})
    
    # Generate find_dependency calls for required packages
    # This ensures transitive dependencies are properly resolved for consumers
    set(package_dependencies_code "")
    if(DEP_THIRDPARTY_PACKAGES)
        foreach(pkg ${DEP_THIRDPARTY_PACKAGES})
            string(APPEND package_dependencies_code "find_dependency(${pkg} REQUIRED)\n")
        endforeach()
    endif()
    # Also add ARIEO_PACKAGES dependencies
    if(DEP_ARIEO_PACKAGES)
        foreach(pkg ${DEP_ARIEO_PACKAGES})
            string(APPEND package_dependencies_code "find_dependency(${pkg} REQUIRED)\n")
        endforeach()
    endif()
    
    configure_package_config_file(
        ${CONFIG_TEMPLATE_FILE}
        ${CMAKE_CURRENT_BINARY_DIR}/${ARIEO_PACKAGE_NAME}Config.cmake
        INSTALL_DESTINATION ${install_cmake_dir}
        PATH_VARS CMAKE_INSTALL_INCLUDEDIR CMAKE_INSTALL_LIBDIR
    )

    # Generate version file
    if(PROJECT_VERSION)
        set(PACKAGE_VERSION ${PROJECT_VERSION})
    else()
        set(PACKAGE_VERSION "1.0.0")
    endif()

    write_basic_package_version_file(
        ${CMAKE_CURRENT_BINARY_DIR}/${ARIEO_PACKAGE_NAME}ConfigVersion.cmake
        VERSION ${PACKAGE_VERSION}
        COMPATIBILITY SameMajorVersion
    )

    # Install config files
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/${ARIEO_PACKAGE_NAME}Config.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/${ARIEO_PACKAGE_NAME}ConfigVersion.cmake
        DESTINATION ${install_cmake_dir}
    )

    # Install Interface code generate folder if any
    if(DEFINED INTERFACE_CODEGEN_ROOT_FOLDER)
        install(DIRECTORY ${INTERFACE_CODEGEN_ROOT_FOLDER}/
            DESTINATION ${install_interface_codegen_dir}
        )
    endif()
endfunction()