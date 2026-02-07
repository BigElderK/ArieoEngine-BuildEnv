cmake_minimum_required(VERSION 3.31)

# Include specialized project type cmake files
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_base_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_static_library_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_shared_library_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_headonly_library_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_interface_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_interface_linker_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_module_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_plugin_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_tool_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_test_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/engine_bootstrap_project.cmake)

# Include installation configuration function
include(${CMAKE_CURRENT_LIST_DIR}/engine_project_install_config.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/package/search_engine_project_packages.cmake)

# Main dispatcher function
function(arieo_engine_project target_project)
    set(oneValueArgs 
        ALIAS
        PROJECT_TYPE
        MODULE_CONFIG_FILE
        AST_GENERATE_FOLDER
        NATIVE_CODE_GENERATE_FOLDER
        WASM_WIT_GENERATE_FOLDER
        WASM_CXX_SCRIPT_GENERATE_FOLDER
        WASM_CSHARP_SCRIPT_GENERATE_FOLDER
        WASM_RUST_SCRIPT_GENERATE_FOLDER
        SCRIPT_PACKAGE_NAME
        ROOT_NAMESPACE
    )

    set(multiValueArgs
        PACKAGES
        PUBLIC_INCLUDE_FOLDERS
        SOURCES
        PRIVATE_INCLUDE_FOLDERS
        PRIVATE_LIB_FOLDERS
        INTERFACES
        PUBLIC_LIBS
        PRIVATE_LIBS
        EXTERNAL_LIBS
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})
    
    string(TOLOWER "${ARGUMENT_PROJECT_TYPE}" ARGUMENT_PROJECT_TYPE)

    # add all engine package install folder to prefix
    add_engine_packages_to_prefix_path(
        PACKAGES_ROOT $ENV{ARIEO_PACKAGE_ROOT_INSTALL_FOLDER}
        HOST_PRESET $ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET}
        BUILD_TYPE $ENV{ARIEO_PACKAGE_BUILD_SETTING_BUILD_TYPE}
    )
    
    # Check Environment CONAN_BUILD_ENV_CHECK is true
    if(NOT DEFINED ENV{CONAN_BUILD_ENV_CHECK} OR NOT "$ENV{CONAN_BUILD_ENV_CHECK}" STREQUAL "true")
        message(FATAL_ERROR "Conan build environment not set up. Please make sure to run CMake with the appropriate Conan build environment setup.")
        exit(1)
    endif()

    # include toolchain file first and then we can override somesettings after
    include(${CMAKE_TOOLCHAIN_FILE})

    if(NOT DEFINED CMAKE_MODULE_LINKER_FLAGS_INIT)
        set(CMAKE_MODULE_LINKER_FLAGS_INIT "${CMAKE_SHARED_LINKER_FLAGS_INIT}")
    endif()

    # make all program compile with fpic
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)

    # export compile command to link with VSCode's cpp IntelliSense
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    # make find_package use config first
    set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)

    # Map to use release version for all third_parties packages
    # set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO RELEASE)
    # set(CMAKE_MAP_IMPORTED_CONFIG_DEBUG RELEASE)

    # Force set msvc crt as MD
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
    message(STATUS "Arieo MSVC CRT LIB: ${CMAKE_MSVC_RUNTIME_LIBRARY}")

    # Dispatch to specialized function based on project type
    if("${ARGUMENT_PROJECT_TYPE}" STREQUAL "base")
        arieo_base_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "static_library")
        arieo_static_library_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "shared_library")
        arieo_shared_library_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "headonly_library")
        arieo_headonly_library_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "interface")
        arieo_interface_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "interface_linker")
        arieo_interface_linker_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "module")
        arieo_module_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "plugin")
        arieo_plugin_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "tool")
        arieo_tool_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "test")
        arieo_test_project(${target_project} ${ARGN})
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "bootstrap")
        arieo_bootstrap_project(${target_project} ${ARGN})
    else()
        message(FATAL_ERROR "Unknown project type: ${ARGUMENT_PROJECT_TYPE}")
    endif()

    arieo_engine_project_install_configure(
        ${target_project}
        LIBRARY_TYPE ${ARGUMENT_PROJECT_TYPE}
        PACKAGES ${ARGUMENT_PACKAGES}
    )
endfunction()