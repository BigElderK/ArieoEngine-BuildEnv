cmake_minimum_required(VERSION 3.31)

# Cook models for the given application project
# Usage: arieo_cook_models(<target_project> <content_folder> <content_output_dir>)
#   target_project: Name of the target project
#   content_folder: Path to the content folder containing model files
#   content_output_dir: Path to the output directory for cooked content
function(arieo_cook_models target_project content_folder content_output_dir)
    if(NOT DEFINED content_folder)
        return()
    endif()

    file(GLOB_RECURSE model_src_files 
        LIST_DIRECTORIES false
        "${content_folder}/*.obj"
    )

    set(model_output_files)
    foreach(model_src_file ${model_src_files})
        
        # Get relative path to maintain directory structure
        file(RELATIVE_PATH relative_path "${content_folder}" ${model_src_file})
        
        # Set output path (same relative path but in output dir)
        set(model_output_file "${content_output_dir}/${relative_path}")
        get_filename_component(model_output_dir ${model_output_file} DIRECTORY)

        # Create output directory if needed
        file(MAKE_DIRECTORY ${model_output_dir})

        # Add custom command to copy model file
        add_custom_command(
            OUTPUT ${model_output_file}
            COMMAND ${CMAKE_COMMAND} -E copy ${model_src_file} ${model_output_file}
            DEPENDS ${model_src_file}
            COMMENT "Copying ${model_src_file} to ${model_output_file}"
        )

        # Add to list of all model outputs
        list(APPEND model_output_files ${model_output_file})
    endforeach()

    if(model_output_files)
        add_custom_target(
            ${target_project}_cook_model
            DEPENDS ${model_output_files}
        )
        add_dependencies(
            ${target_project}
            ${target_project}_cook_model
        )
    endif()
endfunction()
