function(project_outputs_paramters target_project)
    set(oneValueArgs 
        RUNTIME_OUTPUT_DIR
        ARCHIVE_OUTPUT_DIR
        LIBRARY_OUTPUT_DIR
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    #set default output directories if not provided
    if(NOT DEFINED ARGUMENT_RUNTIME_OUTPUT_DIR)
        set(ARGUMENT_RUNTIME_OUTPUT_DIR "$ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/bin/${CMAKE_BUILD_TYPE}")
    endif()
    if(NOT DEFINED ARGUMENT_ARCHIVE_OUTPUT_DIR)
        set(ARGUMENT_ARCHIVE_OUTPUT_DIR "$ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/lib/${CMAKE_BUILD_TYPE}")
    endif()
    if(NOT DEFINED ARGUMENT_LIBRARY_OUTPUT_DIR)
        set(ARGUMENT_LIBRARY_OUTPUT_DIR "$ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/bin/${CMAKE_BUILD_TYPE}")
    endif()

    # Set output directories for binaries and libraries to the package output directory
    set_target_properties(
        ${target_project}
        PROPERTIES 
            RUNTIME_OUTPUT_DIRECTORY ${ARGUMENT_RUNTIME_OUTPUT_DIR}
            ARCHIVE_OUTPUT_DIRECTORY ${ARGUMENT_ARCHIVE_OUTPUT_DIR}
            LIBRARY_OUTPUT_DIRECTORY ${ARGUMENT_LIBRARY_OUTPUT_DIR}
    )

    # Copy include files to the package output directory using a custom target  
    # set(OUTPUT_INCLUDE_DIRS)
    # # Get public and interface include folders from target_project
    # get_target_property(PUBLIC_INCLUDE_DIRS ${target_project} INCLUDE_DIRECTORIES)
    # get_target_property(INTERFACE_INCLUDE_DIRS ${target_project} INTERFACE_INCLUDE_DIRECTORIES)

    # list(APPEND OUTPUT_INCLUDE_DIRS ${PUBLIC_INCLUDE_DIRS})
    # list(APPEND OUTPUT_INCLUDE_DIRS ${INTERFACE_INCLUDE_DIRS})
    # foreach(INCLUDE_FOLDER ${OUTPUT_INCLUDE_DIRS})
    #     # get relatvie folder name to current source directory
    #     message(FATAL_ERROR "Copying headers from ${INCLUDE_FOLDER} to ${ARGUMENT_INCLUDE_OUTPUT_DIR}")
    #     file(RELATIVE_PATH REL_INCLUDE_FOLDER ${CMAKE_CURRENT_SOURCE_DIR} ${INCLUDE_FOLDER})
    #     if(EXISTS ${INCLUDE_FOLDER})
    #         set(copy_target_name copy_includes_${target_project}_${REL_INCLUDE_FOLDER})
    #         string(REPLACE "/" "_" copy_target_name ${copy_target_name})

    #         # message(FATAL_ERROR "Copying headers from ${INCLUDE_FOLDER} to $ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/inlcude")
    #         add_custom_target(${copy_target_name}
    #             COMMAND ${CMAKE_COMMAND} -E copy_directory
    #                 ${INCLUDE_FOLDER}
    #                 ${ARGUMENT_INCLUDE_OUTPUT_DIR}
    #             COMMENT "Copying headers from ${INCLUDE_FOLDER} to ${ARGUMENT_INCLUDE_OUTPUT_DIR}"
    #         )
    #         add_dependencies(${target_project} ${copy_target_name})
    #     endif()
    # endforeach()
endfunction()   