cmake_minimum_required(VERSION 3.31)

# Function to get the output wasm file path from a Cargo.toml manifest
# Usage: get_cargo_info(<cargo_toml_path> <build_type> <out_package_name> <out_wasm_path>)
#   cargo_toml_path: Path to Cargo.toml file
#   build_type: Build type (debug or release)
#   out_package_name: Variable name to store the package name
#   out_wasm_path: Variable name to store the output path
function(get_cargo_info cargo_toml_path build_type out_package_name out_wasm_path)
    # Read Cargo.toml file
    if(NOT EXISTS ${cargo_toml_path})
        message(FATAL_ERROR "Cargo.toml not found at: ${cargo_toml_path}")
    endif()
    
    file(READ ${cargo_toml_path} CARGO_TOML_CONTENT)
    
    # Extract package name from Cargo.toml (matches across multiple lines)
    string(REGEX MATCH "name[ \t]*=[ \t]*\"([^\"]+)\"" _ ${CARGO_TOML_CONTENT})
    if(NOT CMAKE_MATCH_1)
        message(FATAL_ERROR "Could not find package name in ${cargo_toml_path}")
    endif()
    
    set(package_name ${CMAKE_MATCH_1})
    
    # cargo component build always outputs to wasm32-wasip1 directory
    # (not wasm32-wasip2 even if specified in [build] target)
    # The [build] target is used for the final component transformation,
    # but the build artifacts go to wasm32-wasip1
    set(target_triple "wasm32-wasip1")
    
    # Convert hyphens to underscores (Cargo's naming convention for output files)
    string(REPLACE "-" "_" package_name_underscore ${package_name})
    
    # Get the directory containing Cargo.toml
    get_filename_component(cargo_dir ${cargo_toml_path} DIRECTORY)
    
    # Construct the output wasm file path
    set(wasm_output_path "${cargo_dir}/target/${target_triple}/${build_type}/${package_name_underscore}.wasm")
    
    # Set the output variables in parent scope
    set(${out_package_name} ${package_name} PARENT_SCOPE)
    set(${out_wasm_path} ${wasm_output_path} PARENT_SCOPE)
endfunction()

# Build rust scripts for the given application project
# Usage: arieo_build_rust_scripts(<target_project> <script_folder> <script_output_dir>)
#   target_project: Name of the target project
#   script_folder: Path to the content folder containing Cargo.toml files
#   script_output_dir: Base output directory for built scripts
function(arieo_build_rust_scripts target_project script_folder script_output_dir)
    if(NOT DEFINED script_folder)
        return()
    endif()

    if(CMAKE_BUILD_TYPE STREQUAL "Content")
        return()
    endif()
    
    # Convert to Rust build type (Debug -> debug, Release/RelWithDebInfo -> release)
    # Note: RelWithDebInfo uses --release flag but outputs to 'release' folder
    if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
        set(rust_build_type "debug")
    else()
        # Both Release and RelWithDebInfo use release mode
        set(rust_build_type "release")
    endif()

    set(rust_script_folder "${script_folder}/rust")
    file(GLOB_RECURSE cargo_files 
        LIST_DIRECTORIES false
        "${rust_script_folder}/Cargo.toml"
    )

    set(cargo_project_output_files)
    foreach(cargo_file ${cargo_files})
        get_cargo_info(
            ${cargo_file}               # Path to Cargo.toml
            ${rust_build_type}          # Build type (debug or release)
            cargo_package_name          # Package name from Cargo.toml
            cargo_build_output_file     # Output variable name
        )
        message(VERBOSE "WASM output path for ${cargo_file}: ${cargo_build_output_file}")

        # Relative path from script_folder (includes rust/ prefix, mirrors how content uses content_folder as base)
        file(RELATIVE_PATH relative_path "${script_folder}" ${cargo_file})
        get_filename_component(relative_dir "${relative_path}" DIRECTORY)

        # Set output path: script_output_dir / relative_dir(rust/...) / build_type
        set(script_project_output_dir "${script_output_dir}/${relative_dir}/${CMAKE_BUILD_TYPE}")
        get_filename_component(cargo_output_filename ${cargo_build_output_file} NAME_WE)
        set(script_output_file_in_content "${script_project_output_dir}/${cargo_output_filename}.wasm")
        file(MAKE_DIRECTORY ${script_project_output_dir})

        # Always call cargo to configure and build the project (using custom target to always run)
        # Use package name from Cargo.toml for target name, sanitize it for CMake
        string(REPLACE "-" "_" cargo_target_name "${cargo_package_name}")
        
        # Set build flags based on configuration
        if(${CMAKE_BUILD_TYPE} STREQUAL "Release")
            set(cargo_build_flags "--release")
            set(cargo_env_flags "")
        elseif(${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo")
            set(cargo_build_flags "--release")
            set(cargo_env_flags "RUSTFLAGS=-g")
        else()
            # Debug mode
            set(cargo_build_flags "")
            set(cargo_env_flags "RUSTFLAGS=-g")
        endif()
        
        add_custom_target(
            ${target_project}_build_rust_${cargo_target_name} ALL
            COMMAND ${CMAKE_COMMAND} -E env ${cargo_env_flags} cargo component build --manifest-path ${cargo_file} ${cargo_build_flags}
            COMMENT "Compiling ${relative_path} to WebAssembly (${rust_build_type})"
            COMMAND ${CMAKE_COMMAND} -E copy ${cargo_build_output_file} ${script_output_file_in_content}
            COMMENT "Copying ${cargo_build_output_file} to ${script_output_file_in_content}"
            VERBATIM
        )

        list(APPEND cargo_project_output_files ${target_project}_build_rust_${cargo_target_name})
    endforeach()

    if(cargo_project_output_files)
        add_custom_target(
            ${target_project}_rust_scripts
            DEPENDS ${cargo_project_output_files}
        )
        add_dependencies(
            ${target_project}
            ${target_project}_rust_scripts
        )
    endif()
endfunction()
