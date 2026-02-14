cmake_minimum_required(VERSION 3.31)

# Cook images for the given application project
# Usage: arieo_cook_images(<target_project> <content_folder>)
#   target_project: Name of the target project
#   content_folder: Path to the content folder containing image files
function(arieo_cook_images target_project content_folder)
    if(NOT DEFINED content_folder)
        return()
    endif()

    file(GLOB_RECURSE image_src_files 
        LIST_DIRECTORIES false
        "${content_folder}/*.png"
        "${content_folder}/*.jpg"
        "${content_folder}/*.tga"
    )

    # get output folder
    get_property(project_output_dir TARGET ${target_project} PROPERTY RUNTIME_OUTPUT_DIRECTORY)
    set(content_output_dir "${project_output_dir}/content")

    set(image_output_files)
    foreach(image_src_file ${image_src_files})
        # Get relative path to maintain directory structure
        file(RELATIVE_PATH relative_path "${content_folder}" ${image_src_file})
        
        # Set output path (same relative path but in output dir with .dds extension)
        set(image_output_file "${content_output_dir}/${relative_path}")
        get_filename_component(image_output_dir ${image_output_file} DIRECTORY)
        get_filename_component(image_output_filename ${image_output_file} NAME_WE)
        set(image_output_file "${image_output_dir}/${image_output_filename}.dds")

        # Create output directory if needed
        file(MAKE_DIRECTORY ${image_output_dir})

        # Add custom command to convert texture
        if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
            add_custom_command(
                OUTPUT ${image_output_file}
                COMMAND magick
                    ${image_src_file} 
                    -format dds
                    -alpha on
                    -define dds:compression=none
                    -define dds:mipmaps=0 # mipmap level
                    -define dds:dx10-format=true
                    ${image_output_file}
                DEPENDS ${image_src_file}
                COMMENT "Converting ${image_src_file} to DDS ${image_output_file}"
                VERBATIM
            )
        else()
            add_custom_command(
                OUTPUT ${image_output_file}
                COMMAND texconv
                    -f R8G8B8A8_UNORM
                    #-f BC1_UNORM
                    -ft dds #output filetype
                    -m 1 # mipmap level
                    -o ${image_output_dir}
                    -y
                    -dx10 # with DDS_HEADER_DXT10  
                    -- ${image_src_file} 
                DEPENDS ${image_src_file}
                COMMENT "Converting ${image_src_file} to DDS ${image_output_file}"
                VERBATIM
            )
        endif()

        # Add to list of all shader outputs
        list(APPEND image_output_files ${image_output_file})
    endforeach()

    if(image_output_files)
        add_custom_target(
            ${target_project}_cook_image
            DEPENDS ${image_output_files}
        )
        add_dependencies(
            ${target_project}
            ${target_project}_cook_image
        )
    endif()
endfunction()
