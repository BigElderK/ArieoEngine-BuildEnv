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

function(arieo_application_project target_project)
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
    add_dependencies(ArieoApplications ${target_project})

    set_target_properties(
        ${target_project}
        PROPERTIES 
            RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/apps/${target_project}
            ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/apps/${target_project}
            LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/apps/${target_project}
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})

    # Copy manifest file to output dir.
    arieo_copy_manifest(${target_project} "${ARGUMENT_MANIFEST_FILE}")

    # Cook shaders
    arieo_cook_shaders(${target_project} "${ARGUMENT_CONTENT_FOLDER}")

    # Cook images
    arieo_cook_images(${target_project} "${ARGUMENT_CONTENT_FOLDER}")

    # Cook models
    arieo_cook_models(${target_project} "${ARGUMENT_CONTENT_FOLDER}")

    # Build rust scripts
    arieo_build_rust_scripts(${target_project} "${ARGUMENT_SCRIPT_FOLDER}")

    # Build cxx scripts
    arieo_build_cxx_scripts(${target_project} "${ARGUMENT_SCRIPT_FOLDER}")

    # Build .NET scripts
    arieo_build_dotnet_scripts(${target_project} "${ARGUMENT_SCRIPT_FOLDER}")

    # Install application output directory
    install(
        DIRECTORY ${app_output_dir}/
        DESTINATION apps/${target_project}
        USE_SOURCE_PERMISSIONS
        PATTERN "*.pdb" EXCLUDE
    )

endfunction()