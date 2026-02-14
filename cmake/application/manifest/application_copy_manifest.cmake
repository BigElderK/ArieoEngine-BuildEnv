cmake_minimum_required(VERSION 3.31)

# Copy manifest file for the given application project
# Usage: arieo_copy_manifest(<target_project> <manifest_file>)
#   target_project: Name of the target project
#   manifest_file: Path to the manifest file to copy
function(arieo_copy_manifest target_project manifest_file)
    if(NOT DEFINED manifest_file)
        return()
    endif()

    get_filename_component(manifest_output_filename ${manifest_file} NAME_WE)
    get_property(manifest_output_dir TARGET ${target_project} PROPERTY RUNTIME_OUTPUT_DIRECTORY)
    set(manifest_output_file "${manifest_output_dir}/${manifest_output_filename}.manifest.yaml")

    # Add custom command to copy manifest
    add_custom_command(
        OUTPUT ${manifest_output_file}
        COMMAND ${CMAKE_COMMAND} -E copy ${manifest_file} ${manifest_output_file}
        DEPENDS ${manifest_file}
        COMMENT "Copying ${manifest_file} to ${manifest_output_file}"
    )

    add_custom_target(
        ${target_project}_copy_manifest
        DEPENDS ${manifest_output_file}
    )

    add_dependencies(
        ${target_project}
        ${target_project}_copy_manifest
    )
endfunction()
