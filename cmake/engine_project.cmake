cmake_minimum_required(VERSION 3.31)

# Include specialized project type cmake files
include(${CMAKE_CURRENT_LIST_DIR}/projects/project_basic_paramters.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/project_dependencies_parameters.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/project_sources_parameters.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/project_interface_parameters.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/project_outputs_paramters.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/project_interface_code_gen_parameters.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/projects/project_install_paramters.cmake)

# Main dispatcher function
function(ARIEO_ENGINE_PROJECT target_project)
    set(oneValueArgs 
        ALIAS
        PROJECT_TYPE

    )

    set(multiValueArgs 
        DEPENDENCIES
        SOURCES
        INTERFACE_CODE_GENERATION
        OUTPUTS
        INSTALLS
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN}
    )

    # log debug info about the project type
    message(STATUS "Configuring project ${target_project} of type ${ARGUMENT_PROJECT_TYPE}")
    message(STATUS "Configuring project ${target_project} with dependencies: ${ARGUMENT_DEPENDENCIES}")
    message(STATUS "Configuring project ${target_project} with sources: ${ARGUMENT_SOURCES}")
    message(STATUS "Configuring project ${target_project} with interface code gen: ${ARGUMENT_INTERFACE_CODE_GENERATION}")

    # Append extra prefix paths from dependencies without overriding preset values
    if(DEFINED ENV{ARIEO_CMAKE_EXTRA_PREFIX_PATH})
        list(APPEND CMAKE_PREFIX_PATH $ENV{ARIEO_CMAKE_EXTRA_PREFIX_PATH})
        set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}")
    endif()

    message(STATUS "Building project ${target_project} with CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

    # make all program compile with fpic
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)

    # export compile command to link with VSCode's cpp IntelliSense
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    # make find_package use config first
    set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)

    # Map configurations with fallback chains for third-party packages (Conan)
    # This allows graceful degradation when exact config isn't available
    # Format: Try first config, if not found try second, etc.
    set(CMAKE_MAP_IMPORTED_CONFIG_DEBUG "Debug;RelWithDebInfo;Release")
    set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO "RelWithDebInfo;Release;Debug")
    set(CMAKE_MAP_IMPORTED_CONFIG_RELEASE "Release;RelWithDebInfo;Debug")
    set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL "MinSizeRel;Release;RelWithDebInfo")

    # Force set msvc crt as MD
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
    message(STATUS "Arieo MSVC CRT LIB: MultiThreadedDLL")

    add_dependencies(${ARIEO_PACKAGE_NAME} ${target_project})

    # Add definitions for interface libraries
    project_basic_paramters(${target_project} ${ARGN})

    # Call sources and dependencies parameter functions
    project_dependencies_parameters(${target_project} ${ARGUMENT_DEPENDENCIES})
    project_sources_parameters(${target_project} ${ARGUMENT_SOURCES})

    if(DEFINED ARGUMENT_INTERFACE_CODE_GENERATION)
        project_interface_code_gen_parameters(${target_project} ${ARGUMENT_INTERFACE_CODE_GENERATION})
    endif()

    if(DEFINED ARGUMENT_INTERFACES)
        project_interface_parameters(${target_project} ${ARGUMENT_INTERFACES})
    endif()
    
    project_outputs_paramters(${target_project} ${ARGUMENT_OUTPUTS})    
    project_install_paramters(${target_project} ${ARGUMENT_INSTALLS})
endfunction()