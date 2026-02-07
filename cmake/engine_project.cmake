cmake_minimum_required(VERSION 3.31)

# Include specialized project type cmake files
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_base_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_static_library_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_shared_library_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_headonly_library_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_interface_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_interface_linker_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_module_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_plugin_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_tool_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_test_project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/engine_projects/engine_bootstrap_project.cmake)

# Include installation configuration function
include(${CMAKE_CURRENT_LIST_DIR}/engine_project_install_config.cmake)

# Main dispatcher function
function(arieo_engine_project target_project)
    set(oneValueArgs 
        ALIAS
        PROJECT_TYPE
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN})
    
    string(TOLOWER "${ARGUMENT_PROJECT_TYPE}" ARGUMENT_PROJECT_TYPE)

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
    )
endfunction()