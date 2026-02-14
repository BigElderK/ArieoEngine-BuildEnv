cmake_minimum_required(VERSION 3.31)

# Function to get the output wasm file path from a .csproj project
# Usage: get_csproj_info(<csproj_path> <build_type> <out_project_name> <out_wasm_path>)
#   csproj_path: Path to .csproj file
#   build_type: Build type (Debug, Release, etc.)
#   out_project_name: Variable name to store the project name
#   out_wasm_path: Variable name to store the output path
function(get_csproj_info csproj_path build_type out_project_name out_wasm_path)
    # Read .csproj file
    if(NOT EXISTS ${csproj_path})
        message(FATAL_ERROR ".csproj not found at: ${csproj_path}")
    endif()
    
    file(READ ${csproj_path} CSPROJ_CONTENT)
    
    # Get project name from .csproj filename (without extension)
    get_filename_component(project_name ${csproj_path} NAME_WE)
    
    # Extract TargetFramework from .csproj
    string(REGEX MATCH "<TargetFramework>([^<]+)</TargetFramework>" _ ${CSPROJ_CONTENT})
    if(NOT CMAKE_MATCH_1)
        message(FATAL_ERROR "Could not find TargetFramework in ${csproj_path}")
    endif()
    set(target_framework ${CMAKE_MATCH_1})
    
    # Extract RuntimeIdentifier from .csproj
    string(REGEX MATCH "<RuntimeIdentifier>([^<]+)</RuntimeIdentifier>" _ ${CSPROJ_CONTENT})
    if(NOT CMAKE_MATCH_1)
        message(FATAL_ERROR "Could not find RuntimeIdentifier in ${csproj_path}")
    endif()
    set(runtime_identifier ${CMAKE_MATCH_1})
    
    # Try to extract AssemblyName first (if explicitly specified)
    string(REGEX MATCH "<AssemblyName>([^<]+)</AssemblyName>" _ ${CSPROJ_CONTENT})
    if(CMAKE_MATCH_1)
        set(assembly_name ${CMAKE_MATCH_1})
    else()
        # If AssemblyName not specified, use the project file name without extension
        set(assembly_name ${project_name})
    endif()
    
    # Get the directory containing .csproj
    get_filename_component(csproj_dir ${csproj_path} DIRECTORY)
    
    # Construct the output wasm file path following .NET conventions:
    # <project_dir>/bin/<Configuration>/<TargetFramework>/<RuntimeIdentifier>/<AssemblyName>.wasm
    set(wasm_output_path "${csproj_dir}/bin/${build_type}/${target_framework}/${runtime_identifier}/publish/${assembly_name}.wasm")
    
    # Set the output variables in parent scope
    set(${out_project_name} ${project_name} PARENT_SCOPE)
    set(${out_wasm_path} ${wasm_output_path} PARENT_SCOPE)
endfunction()

# Build .NET scripts for the given application project
# Usage: arieo_build_dotnet_scripts(<target_project> <script_folder>)
#   target_project: Name of the target project
#   script_folder: Path to the content folder containing .csproj files
function(arieo_build_dotnet_scripts target_project script_folder)
    if(NOT DEFINED script_folder)
        return()
    endif()

    # Find all .csproj files under the content folder
    file(GLOB_RECURSE csproj_files
        LIST_DIRECTORIES false
        "${script_folder}/*.csproj"
    )
    
    # get output folder
    get_property(project_output_dir TARGET ${target_project} PROPERTY RUNTIME_OUTPUT_DIRECTORY)
    # Convert build config to lowercase for folder name
    string(TOLOWER ${CMAKE_BUILD_TYPE} build_config_lower)
    set(content_output_dir "${project_output_dir}/script/${build_config_lower}")

    set(csproj_output_files)
    foreach(csproj_file ${csproj_files})
        # Get expected wasm output path
        get_csproj_info(
            ${csproj_file}                  # Path to .csproj
            ${CMAKE_BUILD_TYPE}             # Build type
            csproj_project_name             # Project name from .csproj filename
            csproj_build_output_file        # Output variable name
        )
        message(VERBOSE "WASM output path for ${csproj_file}: ${csproj_build_output_file}")

        # Directory containing the .csproj
        get_filename_component(cmake_file_dir ${csproj_file} DIRECTORY)

        # Get relative path to maintain directory structure
        file(RELATIVE_PATH relative_path "${script_folder}" ${csproj_file})
        
        # Set output path in content dir
        set(script_output_dir_in_content "${content_output_dir}/${relative_path}")
        get_filename_component(script_output_dir_in_content ${script_output_dir_in_content} DIRECTORY)
        get_filename_component(csproj_output_filename ${csproj_build_output_file} NAME_WE)
        set(script_output_file_in_content "${script_output_dir_in_content}/${csproj_output_filename}.wasm")

        # Create output directory if needed
        get_filename_component(script_output_dir_in_content ${script_output_file_in_content} DIRECTORY)
        file(MAKE_DIRECTORY ${script_output_dir_in_content})

        # Always call dotnet to configure and build the project (using custom target to always run)
        # Use project name from .csproj filename for target name
        
        # Set optimization flags based on build configuration
        if(CMAKE_BUILD_TYPE STREQUAL "Release")
            set(dotnet_optimize "true")
            set(dotnet_debug_type "")
        elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
            set(dotnet_optimize "true")
            set(dotnet_debug_type "/p:DebugType=portable")
        else()
            set(dotnet_optimize "false")
            set(dotnet_debug_type "/p:DebugType=full")
        endif()
        
        add_custom_target(
            ${target_project}_build_dotnet_${csproj_project_name} ALL
            COMMAND ${CMAKE_COMMAND} -E env DOTNET_CLI_UI_LANGUAGE=en-US dotnet build ${csproj_file} -c ${CMAKE_BUILD_TYPE} /p:Optimize=${dotnet_optimize} ${dotnet_debug_type}
            COMMENT "Building ${relative_path} to WebAssembly (${CMAKE_BUILD_TYPE})"
            COMMAND ${CMAKE_COMMAND} -E copy ${csproj_build_output_file} ${script_output_file_in_content}
            COMMENT "Copying ${csproj_build_output_file} to ${script_output_file_in_content}"
            VERBATIM
        )

        list(APPEND csproj_output_files ${target_project}_build_dotnet_${csproj_project_name})
    endforeach()

    if(csproj_output_files)
        add_custom_target(
            ${target_project}_csharp_scripts
            DEPENDS ${csproj_output_files}
        )
        add_dependencies(
            ${target_project}
            ${target_project}_csharp_scripts
        )
    endif()
endfunction()

