cmake_minimum_required(VERSION 3.31)

# Function to get the output wasm file path from a CMakeLists.txt project
# Usage: get_cmake_project_info(<cmake_lists_path> <build_type> <out_project_name> <output_project_output_path>)
#   cmake_lists_path: Path to CMakeLists.txt file
#   build_type: Build type (Debug, Release, etc.)
#   out_project_name: Variable name to store the project name
#   output_project_output_path: Variable name to store the output path
function(get_cmake_project_info cmake_lists_path build_type out_project_name output_project_output_path)
    # Read CMakeLists.txt file
    if(NOT EXISTS ${cmake_lists_path})
        message(FATAL_ERROR "CMakeLists.txt not found at: ${cmake_lists_path}")
    endif()
    
    file(READ ${cmake_lists_path} CMAKE_LISTS_CONTENT)
    
    # Extract project name from arieo_script_project() call (first argument)
    string(REGEX MATCH "arieo_script_project\\([ \t\n\r]*([^ \t\n\r)]+)" _ ${CMAKE_LISTS_CONTENT})
    if(NOT CMAKE_MATCH_1)
        message(FATAL_ERROR "Could not find arieo_script_project name in ${cmake_lists_path}")
    endif()
    
    set(project_name ${CMAKE_MATCH_1})
    
    # Get the directory containing CMakeLists.txt
    get_filename_component(cmake_dir ${cmake_lists_path} DIRECTORY)
    
    # Construct the output wasm file path (assuming standard CMake binary dir structure)
    # The wasm file is typically output as <project_name>.wasm in the build directory
    set(wasm_output_path "${cmake_dir}/build/${project_name}.wasm")
    
    # Set the output variable in parent scope
    set(${out_project_name} ${project_name} PARENT_SCOPE)
    set(${output_project_output_path} ${wasm_output_path} PARENT_SCOPE)
endfunction()

# Build cxx scripts for the given application project
# Usage: arieo_build_cxx_scripts(<target_project> <script_folder>)
#   target_project: Name of the target project
#   script_folder: Path to the content folder containing CMakeLists.txt files
function(arieo_build_cxx_scripts target_project script_folder)
    if(NOT DEFINED script_folder)
        return()
    endif()
    
    # Convert to lowercase for cmake build type
    string(TOLOWER ${CMAKE_BUILD_TYPE} cmake_build_type)

    # Find all CMakeLists.txt under the content folder (for cxx script projects)
    file(GLOB_RECURSE cmake_files
        LIST_DIRECTORIES false
        "${script_folder}/CMakeLists.txt"
    )
    
    # get output folder
    get_property(project_output_dir TARGET ${target_project} PROPERTY RUNTIME_OUTPUT_DIRECTORY)
    # Convert build config to lowercase for folder name
    string(TOLOWER ${CMAKE_BUILD_TYPE} build_config_lower)
    set(content_output_dir "${project_output_dir}/script/${build_config_lower}")

    set(cmake_project_output_files)
    foreach(cmake_file ${cmake_files})
        # Get expected wasm output path
        get_cmake_project_info(
            ${cmake_file}                   # Path to CMakeLists.txt
            ${cmake_build_type}             # Build type
            cmake_project_name              # Project in cmake
            cmake_project_output_file       # Output variable name
        )
        message(VERBOSE "WASM output path for ${cmake_file}:${cmake_project_name}: ${cmake_project_output_file}")

        # Directory containing the CMakeLists
        get_filename_component(cmake_file_dir ${cmake_file} DIRECTORY)

        # Get relative path to maintain directory structure
        file(RELATIVE_PATH relative_path "${script_folder}" ${cmake_file})
        
        # Set output path in content dir
        set(script_output_dir_in_content "${content_output_dir}/${relative_path}")
        get_filename_component(script_output_dir_in_content ${script_output_dir_in_content} DIRECTORY)
        get_filename_component(cmake_output_filename ${cmake_project_output_file} NAME_WE)
        set(script_output_file_in_content "${script_output_dir_in_content}/${cmake_output_filename}.wasm")

        # Create output directory if needed
        get_filename_component(script_output_dir_in_content ${script_output_file_in_content} DIRECTORY)
        file(MAKE_DIRECTORY ${script_output_dir_in_content})

        # Create a unique build dir under the superbuild binary dir
        file(RELATIVE_PATH rel_dir "${script_folder}" ${cmake_file_dir})
        if(rel_dir STREQUAL "")
            set(rel_dir "root")
        endif()

        set(ext_build_dir "${CMAKE_CURRENT_BINARY_DIR}/external_cxx_builds/${rel_dir}")

        message(VERBOSE "External CXX build dir for ${cmake_file}: ${ext_build_dir}")

        # Create a phony target that always builds
        add_custom_target(
            ${target_project}_build_${cmake_project_name} ALL
            COMMAND ${CMAKE_COMMAND} -E make_directory ${ext_build_dir}
            COMMAND ${CMAKE_COMMAND} -E env "ARIEO_BUILDENV_PACKAGE_INSTALL_FOLDER=$ENV{ARIEO_BUILDENV_PACKAGE_INSTALL_FOLDER}"
                ${CMAKE_COMMAND} -S ${cmake_file_dir} -B ${ext_build_dir} -G "Ninja" 
                -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
            COMMAND ${CMAKE_COMMAND} --build ${ext_build_dir} --target ${cmake_project_name}
            COMMENT "Compiling ${relative_path} to WebAssembly (${CMAKE_BUILD_TYPE})"
            COMMAND ${CMAKE_COMMAND} -E copy ${cmake_project_output_file} ${script_output_file_in_content}
            COMMENT "Copying ${cmake_project_output_file} to ${script_output_file_in_content}"
            USES_TERMINAL
            VERBATIM
        )

        list(APPEND cmake_project_output_files ${target_project}_build_${cmake_project_name})
    endforeach()

    if(cmake_project_output_files)
        add_custom_target(
            ${target_project}_cxx_scripts
            DEPENDS ${cmake_project_output_files}
        )
        add_dependencies(
            ${target_project}
            ${target_project}_cxx_scripts
        )
    endif()
endfunction()
