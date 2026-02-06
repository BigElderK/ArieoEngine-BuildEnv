cmake_minimum_required(VERSION 3.20)

#[[
Function: install_cmake_project_package

General-purpose CMake project installation function for package management.
This function can install any CMake project that was previously built.

Parameters:
  BUILD_FOLDER   - Build directory containing cmake_install.cmake (required)
  INSTALL_PREFIX - Installation destination directory (required)
  BUILD_TYPE     - Build configuration to install (Debug|Release|RelWithDebInfo|MinSizeRel) (required)
  COMPONENT      - Specific component to install (optional, installs all if not specified)

Example usage:
  install_cmake_project_package(
      BUILD_FOLDER ${CMAKE_CURRENT_LIST_DIR}/_build
      INSTALL_PREFIX ${CMAKE_CURRENT_LIST_DIR}/_output/windows.x86_64/Release
      BUILD_TYPE Release
  )
]]
function(install_cmake_project_package)
    set(oneValueArgs
        BUILD_FOLDER
        INSTALL_PREFIX
        BUILD_TYPE
        COMPONENT
    )
    
    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    ##########################################################################################
    # Validate required arguments
    if(NOT DEFINED ARGUMENT_BUILD_FOLDER)
        message(FATAL_ERROR "BUILD_FOLDER argument is required")
    endif()

    if(NOT DEFINED ARGUMENT_INSTALL_PREFIX)
        message(FATAL_ERROR "INSTALL_PREFIX argument is required")
    endif()

    if(NOT DEFINED ARGUMENT_BUILD_TYPE)
        message(FATAL_ERROR "BUILD_TYPE argument is required")
    endif()

    # Verify build folder exists
    if(NOT EXISTS "${ARGUMENT_BUILD_FOLDER}")
        message(FATAL_ERROR "Build folder does not exist: ${ARGUMENT_BUILD_FOLDER}")
    endif()

    # Verify cmake_install.cmake exists in build folder
    if(NOT EXISTS "${ARGUMENT_BUILD_FOLDER}/cmake_install.cmake")
        message(FATAL_ERROR "cmake_install.cmake not found in ${ARGUMENT_BUILD_FOLDER}. Project may not be configured properly.")
    endif()

    ##########################################################################################
    # Recreate install directory
    file(MAKE_DIRECTORY "${ARGUMENT_INSTALL_PREFIX}")

    ##########################################################################################
    # CMake Install Step
    message(STATUS "================================================================")
    message(STATUS "Installing CMake Project")
    message(STATUS "  Build Folder: ${ARGUMENT_BUILD_FOLDER}")
    message(STATUS "  Install Prefix: ${ARGUMENT_INSTALL_PREFIX}")
    message(STATUS "  Build Type: ${ARGUMENT_BUILD_TYPE}")
    if(DEFINED ARGUMENT_COMPONENT)
        message(STATUS "  Component: ${ARGUMENT_COMPONENT}")
    endif()
    message(STATUS "================================================================")

    # Prepare install command
    set(CMAKE_INSTALL_CMD ${CMAKE_COMMAND} --install ${ARGUMENT_BUILD_FOLDER})
    set(CMAKE_INSTALL_CMD ${CMAKE_INSTALL_CMD} --prefix ${ARGUMENT_INSTALL_PREFIX})
    set(CMAKE_INSTALL_CMD ${CMAKE_INSTALL_CMD} --config ${ARGUMENT_BUILD_TYPE})
    
    if(DEFINED ARGUMENT_COMPONENT)
        set(CMAKE_INSTALL_CMD ${CMAKE_INSTALL_CMD} --component ${ARGUMENT_COMPONENT})
    endif()

    # Execute install
    execute_process(
        COMMAND ${CMAKE_INSTALL_CMD}
        RESULT_VARIABLE CMAKE_RESULT
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
        COMMAND_ECHO STDOUT
    )

    if(NOT CMAKE_RESULT EQUAL 0)
        message(FATAL_ERROR "CMake install failed with code ${CMAKE_RESULT}")
    endif()

    message(STATUS "================================================================")
    message(STATUS "Installation completed successfully")
    message(STATUS "  Installed to: ${ARGUMENT_INSTALL_PREFIX}")
    message(STATUS "================================================================")
endfunction()

##########################################################################################
# Script execution: When called with cmake -P, read all parameters from environment variables
if(CMAKE_SCRIPT_MODE_FILE)
    # Get SOURCE_CMAKE_LIST_DIR from environment variable (set by Python build script)
    if(NOT DEFINED ENV{ARIEO_PACKAGE_SOURCE_DIR})
        message(FATAL_ERROR "Environment variable ARIEO_PACKAGE_SOURCE_DIR is not defined")
    endif()
    
    # Read parameters from environment variables
    if(NOT DEFINED ENV{ARIEO_PACKAGE_BUILDENV_HOST_PRESET})
        message(FATAL_ERROR "Environment variable ARIEO_PACKAGE_BUILDENV_HOST_PRESET is not defined")
    endif()
    
    if(NOT DEFINED ENV{ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE})
        message(FATAL_ERROR "Environment variable ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE is not defined")
    endif()

    if(NOT DEFINED ENV{ARIEO_PACKAGE_CORE_BUILD_FOLDER} AND NOT DEFINED ENV{ARIEO_PACKAGE_CORE_INSTALL_FOLDER})
        message(FATAL_ERROR "Neither ARIEO_PACKAGE_CORE_BUILD_FOLDER nor ARIEO_PACKAGE_CORE_INSTALL_FOLDER environment variables are defined. At least one must be defined.")
    endif()
    
    # Determine build and install folders based on package name pattern
    if(DEFINED ENV{ARIEO_PACKAGE_CORE_BUILD_FOLDER})
        set(BUILD_FOLDER_VAR $ENV{ARIEO_PACKAGE_CORE_BUILD_FOLDER})
    elseif(DEFINED BUILD_FOLDER)
        set(BUILD_FOLDER_VAR ${BUILD_FOLDER})
    else()
        message(FATAL_ERROR "BUILD_FOLDER must be defined via -DBUILD_FOLDER or ARIEO_PACKAGE_*_BUILD_FOLDER environment variable")
    endif()

    # Call the function
    install_cmake_project_package(
        BUILD_FOLDER $ENV{ARIEO_PACKAGE_CORE_BUILD_FOLDER}
        BUILD_TYPE $ENV{ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE}
        INSTALL_PREFIX $ENV{ARIEO_PACKAGE_CORE_INSTALL_FOLDER}/$ENV{ARIEO_PACKAGE_BUILDENV_HOST_PRESET}/$ENV{ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE}
    )
endif()

