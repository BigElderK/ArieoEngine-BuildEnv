cmake_minimum_required(VERSION 3.31)

# Include manifest copying module
include(${CMAKE_CURRENT_LIST_DIR}/manifest/application_copy_manifest.cmake)

# Include content cooking modules
include(${CMAKE_CURRENT_LIST_DIR}/content/application_cook_shader.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/content/application_cook_image.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/content/application_cook_model.cmake)

# Include WASM script building modules
include(${CMAKE_CURRENT_LIST_DIR}/script/application_script_rust.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/script/application_script_cxx.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/script/application_script_dotnet.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/script/wasm_cxx_project.cmake)

function(ARIEO_APPLICATION_PROJECT target_project)
    # Require CMAKE_BUILD_TYPE to be set
    if(NOT DEFINED CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "")
        message(FATAL_ERROR "CMAKE_BUILD_TYPE is not defined. Please specify a build type (Debug, Release, RelWithDebInfo, etc.)")
    endif()

    set(oneValueArgs
        MANIFEST_FILE
        CONTENT_FOLDER
        SCRIPT_FOLDER
    )

    add_custom_target(${target_project} ALL)
    add_dependencies(${ARIEO_PACKAGE_NAME} ${target_project})

    set_target_properties(
        ${target_project}
        PROPERTIES 
            RUNTIME_OUTPUT_DIRECTORY $ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/${target_project}
            ARCHIVE_OUTPUT_DIRECTORY $ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/${target_project}
            LIBRARY_OUTPUT_DIRECTORY $ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/${target_project}
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})

    # Derive output dirs from the target's runtime output directory
    get_property(app_output_dir TARGET ${target_project} PROPERTY RUNTIME_OUTPUT_DIRECTORY)
    set(script_output_dir "${app_output_dir}/script")
    set(content_output_dir "${app_output_dir}/content")

    # Copy manifest file to output dir.
    arieo_copy_manifest(${target_project} "${ARGUMENT_MANIFEST_FILE}")

    # Cook content only when build type is Content
    if(CMAKE_BUILD_TYPE STREQUAL "Content")
        # Cook shaders
        arieo_cook_shaders(${target_project} "${ARGUMENT_CONTENT_FOLDER}" "${content_output_dir}")

        # Cook images
        arieo_cook_images(${target_project} "${ARGUMENT_CONTENT_FOLDER}" "${content_output_dir}")

        # Cook models
        arieo_cook_models(${target_project} "${ARGUMENT_CONTENT_FOLDER}" "${content_output_dir}")
    endif()

    # Build rust scripts
    arieo_build_rust_scripts(${target_project} "${ARGUMENT_SCRIPT_FOLDER}" "${script_output_dir}")

    # Build cxx scripts
    arieo_build_cxx_scripts(${target_project} "${ARGUMENT_SCRIPT_FOLDER}" "${script_output_dir}")

    # Build .NET scripts
    arieo_build_dotnet_scripts(${target_project} "${ARGUMENT_SCRIPT_FOLDER}" "${script_output_dir}")

    # Set app output directory
    set(app_output_dir $ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/${target_project})
    set(app_install_dir ${CMAKE_INSTALL_PREFIX}/${ARIEO_PACKAGE_CATEGORY}/${ARIEO_PACKAGE_NAME}/${ARIEO_BUILD_CONFIGURE_PRESET}/${target_project})

    # Install content, scripts, and generate OBB only when build type is Content
    if(CMAKE_BUILD_TYPE STREQUAL "Content")
        # Install application content (cooked shaders, images, models)
        if(ARGUMENT_CONTENT_FOLDER AND EXISTS "${ARGUMENT_CONTENT_FOLDER}")
            install(
                DIRECTORY ${app_output_dir}/content/
                DESTINATION ${app_install_dir}/content
                OPTIONAL
            )
        endif()

        if(ARGUMENT_MANIFEST_FILE AND EXISTS "${ARGUMENT_MANIFEST_FILE}")
            install(
                FILES ${ARGUMENT_MANIFEST_FILE}
                DESTINATION ${app_install_dir}
            )
        endif()

        # Generate OBB file during install (zip content and script folders only)
        set(OBB_OUTPUT_FILE ${app_install_dir}/${target_project}.obb)
        install(CODE "
            set(OBB_CONTENTS \"\")
            if(EXISTS \"${app_install_dir}/content\")
                list(APPEND OBB_CONTENTS content)
            endif()
            if(EXISTS \"${app_install_dir}/script\")
                list(APPEND OBB_CONTENTS script)
            endif()
            if(OBB_CONTENTS)
                message(STATUS \"Creating OBB file: ${OBB_OUTPUT_FILE}\")
                file(REMOVE \"${OBB_OUTPUT_FILE}\")
                execute_process(
                    COMMAND \${CMAKE_COMMAND} -E tar cfv \"${OBB_OUTPUT_FILE}\" --format=zip \${OBB_CONTENTS}
                    WORKING_DIRECTORY \"${app_install_dir}\"
                    RESULT_VARIABLE ZIP_RESULT
                )
                if(NOT ZIP_RESULT EQUAL 0)
                    message(WARNING \"Failed to create OBB file\")
                else()
                    file(SIZE \"${OBB_OUTPUT_FILE}\" OBB_SIZE)
                    message(STATUS \"OBB file created: ${OBB_OUTPUT_FILE} (\${OBB_SIZE} bytes)\")
                endif()
            endif()
        ")
    else()
        # Install wasm files from build output, keeping folder structure
        if(ARGUMENT_SCRIPT_FOLDER AND EXISTS "${ARGUMENT_SCRIPT_FOLDER}")
            install(
                DIRECTORY ${app_output_dir}/script/
                DESTINATION ${app_install_dir}/script
                OPTIONAL
                FILES_MATCHING PATTERN "*.wasm"
            )
        endif()
        # Dummy install to ensure install target exists
        install(CODE "message(STATUS \"Install complete for ${target_project}\")")
    endif()

endfunction()