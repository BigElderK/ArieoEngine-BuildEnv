cmake_minimum_required(VERSION 3.31)

# Cook shaders for the given application project
# Usage: arieo_cook_shaders(<target_project> <content_folder>)
#   target_project: Name of the target project
#   content_folder: Path to the content folder containing shader files
function(arieo_cook_shaders target_project content_folder)
    if(NOT DEFINED content_folder)
        return()
    endif()

    file(GLOB_RECURSE shader_src_files 
        LIST_DIRECTORIES false
        "${content_folder}/*.vert"
        "${content_folder}/*.frag"
        "${content_folder}/*.hlsl"
    )

    # get output folder
    get_property(project_output_dir TARGET ${target_project} PROPERTY RUNTIME_OUTPUT_DIRECTORY)
    set(content_output_dir "${project_output_dir}/content")

    set(shader_output_files)
    foreach(shader_src_file ${shader_src_files})
        # Get relative path to maintain directory structure
        file(RELATIVE_PATH relative_path "${content_folder}" ${shader_src_file})
        
        # Set output path (same relative path but in output dir with .spv extension)
        set(shader_output_file "${content_output_dir}/${relative_path}.spv")

        # Create output directory if needed
        get_filename_component(shader_output_dir ${shader_output_file} DIRECTORY)
        file(MAKE_DIRECTORY ${shader_output_dir})

        # get_filename_component(shader_src_multi_ext ${shader_src_file} EXT)
        string(REGEX MATCH "\\.[^.]+\\.[^.]+$" shader_src_multi_ext ${shader_src_file})
        # Add custom command to compile this shader
        if(shader_src_multi_ext STREQUAL ".vert.hlsl")
            #message(FATAL_ERROR "Command: dxc -E main -T vs_6_0 -spirv -Fo ${shader_src_file} ${shader_output_file}")
            add_custom_command(
                OUTPUT ${shader_output_file}
                COMMAND dxc #${DXC_EXECUTABLE} 
                    ${shader_src_file}
                    -E main
                    -T vs_6_0
                    -spirv
                    -Fo ${shader_output_file}
                    # --target-env=vulkan1.2
                DEPENDS ${shader_src_file}
                COMMENT "Compiling ${relative_path} to SPIR-V ${shader_output_file}"
                VERBATIM
            )
        elseif(shader_src_multi_ext STREQUAL ".frag.hlsl")
            #message(FATAL_ERROR "Command: dxc -E main -T ps_6_0 -spirv -Fo ${shader_src_file} ${shader_output_file}")
            add_custom_command(
                OUTPUT ${shader_output_file}
                COMMAND dxc #${DXC_EXECUTABLE} 
                    ${shader_src_file} 
                    -E main
                    -T ps_6_0
                    -spirv
                    -Fo ${shader_output_file}
                    # --target-env=vulkan1.2
                DEPENDS ${shader_src_file}
                COMMENT "Compiling ${relative_path} to SPIR-V ${shader_output_file}"
                VERBATIM
            )            
        else()
            add_custom_command(
                OUTPUT ${shader_output_file}
                COMMAND glslc #${GLSLC_EXECUTABLE} 
                    ${shader_src_file} 
                    -o ${shader_output_file}
                    -O
                    # --target-env=vulkan1.2
                DEPENDS ${shader_src_file}
                COMMENT "Compiling ${relative_path} to SPIR-V ${shader_output_file}"
                VERBATIM
            )
        endif()

        # Add to list of all shader outputs
        list(APPEND shader_output_files ${shader_output_file})
    endforeach()

    if(shader_output_files)
        add_custom_target(
            ${target_project}_compile_shader
            DEPENDS ${shader_output_files}
        )
        add_dependencies(
            ${target_project}
            ${target_project}_compile_shader
        )
    endif()
endfunction()
