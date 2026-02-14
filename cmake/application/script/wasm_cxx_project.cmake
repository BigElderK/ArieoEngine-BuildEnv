cmake_minimum_required(VERSION 3.31)
function(arieo_script_project target_project)
    set(oneValueArgs 
        ALIAS
        PROJECT_TYPE
        WIT
        WIT_WORLD
        WIT_GEN_DIR
        BUILD_DIR
    )

    set(multiValueArgs 
        INCLUDE_FOLDERS
        SOURCES
        WIT_DEPENDENCIES
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})

    # Custom clang++ invocation to build a WASI core module and convert to a component
    # Uses the WASI SDK pointed to by the WASI_SDK_PATH environment variable and
    # requires `wasm-tools` on PATH for the component conversion step.
    if(NOT DEFINED ENV{WASI_SDK_PATH} OR "$ENV{WASI_SDK_PATH}" STREQUAL "")
        message(FATAL_ERROR "WASI_SDK_PATH environment variable is not set. Please set it to your WASI SDK installation path.")
    endif()
    set(WASI_SDK_PREFIX $ENV{WASI_SDK_PATH})
    set(WASI_SDK_BIN "${WASI_SDK_PREFIX}/bin")

    # Locate clang++ in the WASI SDK bin directory (handle Windows .exe)
    find_program(WASI_CLANG
        NAMES clang++ clang++.exe
        HINTS ${WASI_SDK_BIN}
    )
    if(NOT WASI_CLANG)
        message(FATAL_ERROR "clang++ not found in ${WASI_SDK_BIN}. Ensure WASI_SDK_PATH is correct and contains bin/clang++ or clang++.exe.")
    endif()

    # Find wasm-tools on PATH
    find_program(WASM_TOOLS wasm-tools)
    if(NOT WASM_TOOLS)
        message(FATAL_ERROR "wasm-tools not found on PATH. Install it (cargo install wasm-tools) or ensure it's available on PATH.")
    endif()

    # Find wit-bindgen on PATH
    find_program(WIT_BINDGEN wit-bindgen)
    if(NOT WIT_BINDGEN)
        message(FATAL_ERROR "wit-bindgen not found on PATH. Install it (cargo install wit-bindgen-cli) or ensure it's available on PATH.")
    endif()

    # Get SRC_FILES from SOURCES in pattern format using GLOB_RECURSE
    file(GLOB_RECURSE project_src_files 
        LIST_DIRECTORIES false
        ${ARGUMENT_SOURCES}
    )

    # Build WIT file list: dependencies first, then main WIT
    set(project_wit_files ${ARGUMENT_WIT_DEPENDENCIES} ${ARGUMENT_WIT})

    # Create _generated directory
    file(MAKE_DIRECTORY ${ARGUMENT_WIT_GEN_DIR})

    # Prepare optional world parameter
    set(wit_world_args)
    if(ARGUMENT_WIT_WORLD)
        set(wit_world_args -w ${ARGUMENT_WIT_WORLD})
    endif()

    # Create a target for wit bindings
    add_custom_command(
        OUTPUT ${ARGUMENT_WIT_GEN_DIR}/.wit_generated
        COMMAND ${WIT_BINDGEN} cpp ${project_wit_files} --out-dir ${ARGUMENT_WIT_GEN_DIR} ${wit_world_args}
        COMMAND ${CMAKE_COMMAND} -E touch ${ARGUMENT_WIT_GEN_DIR}/.wit_generated
        DEPENDS ${project_wit_files}
        COMMENT "Generating WIT bindings"
    )
    
    add_custom_target(${target_project}_wit_bindings
        DEPENDS ${ARGUMENT_WIT_GEN_DIR}/.wit_generated
    )

    # Add all generated files to project_wit_gen_files
    file(GLOB_RECURSE project_wit_gen_files
        LIST_DIRECTORIES false
        ${ARGUMENT_WIT_GEN_DIR}/*.cpp
        ${ARGUMENT_WIT_GEN_DIR}/*.o
    )

    # set output wasm file in wasip1
    set(target_wasip1 "${ARGUMENT_BUILD_DIR}/${target_project}.wasip1.wasm")
    set(target_wasip2 "${ARGUMENT_BUILD_DIR}/${target_project}.wasm")
    
    # Set optimization flags based on build configuration
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        set(cxx_debug_flags -O2 -DNDEBUG)
        set(cxx_comment_suffix "(optimized)")
    elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
        set(cxx_debug_flags -O2 -g)
        set(cxx_comment_suffix "(optimized with debug info)")
    else()
        set(cxx_debug_flags -g -O0)
        set(cxx_comment_suffix "(debug)")
    endif()

    add_custom_command(
        OUTPUT ${target_wasip1}
        COMMAND ${WASI_SDK_BIN}/clang++
            --target=wasm32-wasi
            ${cxx_debug_flags}
            -std=c++20
            -fno-exceptions
            -mexec-model=reactor
            -isystem ${WASI_SDK_PREFIX}/share/wasi-sysroot/include/c++/v1
            -isystem ${WASI_SDK_PREFIX}/share/wasi-sysroot/include/wasm32-wasi/c++/v1
            -isystem ${WASI_SDK_PREFIX}/share/wasi-sysroot/include
            -I ${ARGUMENT_WIT_GEN_DIR}
            ${project_src_files}
            ${project_wit_gen_files}
            -o ${target_wasip1}
        DEPENDS ${project_src_files}
                ${project_wit_files}
                ${target_project}_wit_bindings
                ${project_wit_gen_files}
        COMMENT "Compiling greeter_component.wasm with WASI SDK clang++ ${cxx_comment_suffix}"
    )

    set(WASI_ADAPTER "${WASI_SDK_PREFIX}/share/wasi-sysroot/lib/wasm32-wasip2/wasi_snapshot_preview1.reactor.wasm")

    if(EXISTS "${WASI_ADAPTER}")
        add_custom_command(
            OUTPUT ${target_wasip2}
            COMMAND ${WASM_TOOLS} component new ${target_wasip1} -o ${target_wasip2} --adapt ${WASI_ADAPTER}
            DEPENDS ${target_wasip1}
            COMMENT "Converting greeter_component.wasm -> greeter_component.component.wasm using wasm-tools (with adapter)"
        )
    else()
        add_custom_command(
            OUTPUT ${target_wasip2}
            COMMAND ${WASM_TOOLS} component new ${target_wasip1} -o ${target_wasip2}
            DEPENDS ${target_wasip1}
            COMMENT "Converting greeter_component.wasm -> greeter_component.component.wasm using wasm-tools (no adapter found)"
        )
    endif()

    # Create the main target that depends on the component
    add_custom_target(${target_project} ALL
        DEPENDS ${target_wasip2}
    )
endfunction()