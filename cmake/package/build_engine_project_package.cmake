cmake_minimum_required(VERSION 3.20)

#[[
Function: build_cmake_project_package

General-purpose CMake project build function for package management.
This function can build any CMake project with proper toolchain/conan environment setup.

Parameters:
  SOURCE_CMAKE_LIST_DIR - Source directory containing CMakeLists.txt (required)
  PRESET                - CMake preset name to use (required)
  BUILD_TYPE            - Build configuration (Debug|Release|RelWithDebInfo|MinSizeRel) (required)
  BUILD_FOLDER          - Build output directory (required)
  OUTPUT_FOLDER         - Final output directory for built artifacts (optional)
  CONAN_ENV_SCRIPT      - Path to conan environment setup script (optional, auto-detected if not provided)
  ADDITIONAL_CMAKE_ARGS - Additional CMake configure arguments (optional)

Example usage:
  build_cmake_project_package(
      SOURCE_CMAKE_LIST_DIR ${CMAKE_CURRENT_LIST_DIR}
      PRESET windows.x86_64
      BUILD_TYPE Release
      BUILD_FOLDER ${CMAKE_CURRENT_LIST_DIR}/_build
      OUTPUT_FOLDER ${CMAKE_CURRENT_LIST_DIR}/_output
  )
]]
function(build_cmake_project_package)
    set(oneValueArgs
        SOURCE_CMAKE_LIST_DIR
        PRESET
        BUILD_TYPE
        BUILD_FOLDER
        OUTPUT_FOLDER
        CONAN_ENV_SCRIPT
        ADDITIONAL_CMAKE_ARGS
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
    if(NOT DEFINED ARGUMENT_SOURCE_CMAKE_LIST_DIR)
        message(FATAL_ERROR "SOURCE_CMAKE_LIST_DIR argument is required")
    endif()

    if(NOT DEFINED ARGUMENT_PRESET)
        message(FATAL_ERROR "PRESET argument is required")
    endif()

    if(NOT DEFINED ARGUMENT_BUILD_TYPE)
        message(FATAL_ERROR "BUILD_TYPE argument is required")
    endif()

    if(NOT DEFINED ARGUMENT_BUILD_FOLDER)
        message(FATAL_ERROR "BUILD_FOLDER argument is required")
    endif()

    # Verify source directory exists and contains CMakeLists.txt
    if(NOT EXISTS "${ARGUMENT_SOURCE_CMAKE_LIST_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "CMakeLists.txt not found in ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}")
    endif()

    ##########################################################################################
    # Auto-detect conan environment script if not provided
    if(NOT DEFINED ARGUMENT_CONAN_ENV_SCRIPT)
        # Determine batch suffix based on host system
        if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
            set(CMAKE_HOST_BATCH_SUFFIX .bat)
        else()
            set(CMAKE_HOST_BATCH_SUFFIX .sh)
        endif()

        # Try to find conan environment script from ARIEO_PACKAGE_BUILDENV_INSTALL_FOLDER
        if(DEFINED ENV{ARIEO_PACKAGE_BUILDENV_INSTALL_FOLDER})
            set(DETECTED_CONAN_SCRIPT "$ENV{ARIEO_PACKAGE_BUILDENV_INSTALL_FOLDER}/conan/host/${ARGUMENT_PRESET}/conanbuild${CMAKE_HOST_BATCH_SUFFIX}")
            if(EXISTS "${DETECTED_CONAN_SCRIPT}")
                set(ARGUMENT_CONAN_ENV_SCRIPT "${DETECTED_CONAN_SCRIPT}")
                message(STATUS "Auto-detected conan environment script: ${ARGUMENT_CONAN_ENV_SCRIPT}")
            endif()
        endif()
    endif()

    ##########################################################################################
    # Copy CMake presets if available
    if(DEFINED ENV{ARIEO_PACKAGE_BUILDENV_INSTALL_FOLDER})
        set(PRESETS_FILE "$ENV{ARIEO_PACKAGE_BUILDENV_INSTALL_FOLDER}/cmake/CMakePresets.json")
        if(EXISTS "${PRESETS_FILE}")
            execute_process(COMMAND ${CMAKE_COMMAND} -E copy
                "${PRESETS_FILE}"
                "${ARGUMENT_SOURCE_CMAKE_LIST_DIR}/CMakeUserPresets.json")
            message(STATUS "Copied CMakePresets.json to CMakeUserPresets.json")
        endif()
    endif()

    ##########################################################################################
    # Prepare CMake configure command
    set(CMAKE_CONFIGURE_CMD "cmake -S ${ARGUMENT_SOURCE_CMAKE_LIST_DIR} -B ${ARGUMENT_BUILD_FOLDER}")
    set(CMAKE_CONFIGURE_CMD "${CMAKE_CONFIGURE_CMD} --preset=${ARGUMENT_PRESET}")
    set(CMAKE_CONFIGURE_CMD "${CMAKE_CONFIGURE_CMD} -DCMAKE_BUILD_TYPE=${ARGUMENT_BUILD_TYPE}")
    
    if(DEFINED ARGUMENT_OUTPUT_FOLDER)
        set(CMAKE_CONFIGURE_CMD "${CMAKE_CONFIGURE_CMD} -DTARGET_PROJECT_OUTPUT_FOLDER=${ARGUMENT_OUTPUT_FOLDER}")
    endif()

    if(DEFINED ARGUMENT_ADDITIONAL_CMAKE_ARGS)
        set(CMAKE_CONFIGURE_CMD "${CMAKE_CONFIGURE_CMD} ${ARGUMENT_ADDITIONAL_CMAKE_ARGS}")
    endif()

    ##########################################################################################
    # CMake Configure Step
    message(STATUS "================================================================")
    message(STATUS "Configuring CMake Project")
    message(STATUS "  Source: ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}")
    message(STATUS "  Build: ${ARGUMENT_BUILD_FOLDER}")
    message(STATUS "  Preset: ${ARGUMENT_PRESET}")
    message(STATUS "  Build Type: ${ARGUMENT_BUILD_TYPE}")
    if(DEFINED ARGUMENT_CONAN_ENV_SCRIPT)
        message(STATUS "  Conan Env: ${ARGUMENT_CONAN_ENV_SCRIPT}")
    endif()
    message(STATUS "================================================================")

    if(DEFINED ARGUMENT_CONAN_ENV_SCRIPT AND EXISTS "${ARGUMENT_CONAN_ENV_SCRIPT}")
        # Configure with conan environment setup
        if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
            execute_process(
                COMMAND cmd /c "${ARGUMENT_CONAN_ENV_SCRIPT} && ${CMAKE_CONFIGURE_CMD}"
                WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
                RESULT_VARIABLE CMAKE_RESULT
                ECHO_OUTPUT_VARIABLE
                ECHO_ERROR_VARIABLE
                COMMAND_ECHO STDOUT
            )
        else()
            execute_process(
                COMMAND sh -c "source ${ARGUMENT_CONAN_ENV_SCRIPT} && ${CMAKE_CONFIGURE_CMD}"
                WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
                RESULT_VARIABLE CMAKE_RESULT
                ECHO_OUTPUT_VARIABLE
                ECHO_ERROR_VARIABLE
                COMMAND_ECHO STDOUT
            )
        endif()
    else()
        # Configure without conan environment
        execute_process(
            COMMAND ${CMAKE_COMMAND} -S ${ARGUMENT_SOURCE_CMAKE_LIST_DIR} -B ${ARGUMENT_BUILD_FOLDER}
                    --preset=${ARGUMENT_PRESET}
                    -DCMAKE_BUILD_TYPE=${ARGUMENT_BUILD_TYPE}
            WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
            RESULT_VARIABLE CMAKE_RESULT
            ECHO_OUTPUT_VARIABLE
            ECHO_ERROR_VARIABLE
            COMMAND_ECHO STDOUT
        )
    endif()

    if(NOT CMAKE_RESULT EQUAL 0)
        message(FATAL_ERROR "CMake configure failed with code ${CMAKE_RESULT}")
    endif()

    ##########################################################################################
    # CMake Build Step
    message(STATUS "================================================================")
    message(STATUS "Building CMake Project")
    message(STATUS "  Target: ALL")
    message(STATUS "================================================================")

    set(CMAKE_BUILD_CMD "cmake --build ${ARGUMENT_BUILD_FOLDER}")

    if(DEFINED ARGUMENT_CONAN_ENV_SCRIPT AND EXISTS "${ARGUMENT_CONAN_ENV_SCRIPT}")
        # Build with conan environment setup
        if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
            execute_process(
                COMMAND cmd /c "${ARGUMENT_CONAN_ENV_SCRIPT} && ${CMAKE_BUILD_CMD}"
                WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
                RESULT_VARIABLE CMAKE_RESULT
                ECHO_OUTPUT_VARIABLE
                ECHO_ERROR_VARIABLE
                COMMAND_ECHO STDOUT
            )
        else()
            execute_process(
                COMMAND sh -c "source ${ARGUMENT_CONAN_ENV_SCRIPT} && ${CMAKE_BUILD_CMD}"
                WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
                RESULT_VARIABLE CMAKE_RESULT
                ECHO_OUTPUT_VARIABLE
                ECHO_ERROR_VARIABLE
                COMMAND_ECHO STDOUT
            )
        endif()
    else()
        # Build without conan environment
        execute_process(
            COMMAND ${CMAKE_COMMAND} --build ${ARGUMENT_BUILD_FOLDER}
            WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
            RESULT_VARIABLE CMAKE_RESULT
            ECHO_OUTPUT_VARIABLE
            ECHO_ERROR_VARIABLE
            COMMAND_ECHO STDOUT
        )
    endif()

    if(NOT CMAKE_RESULT EQUAL 0)
        message(FATAL_ERROR "CMake build failed with code ${CMAKE_RESULT}")
    endif()

    message(STATUS "================================================================")
    message(STATUS "Build completed successfully")
    message(STATUS "================================================================")
endfunction()

##########################################################################################
# Script execution: When called with cmake -P, read all parameters from environment variables
if(CMAKE_SCRIPT_MODE_FILE)
    # Get SOURCE_CMAKE_LIST_DIR from environment variable (set by Python build script)
    if(NOT DEFINED ENV{ARIEO_PACKAGE_SOURCE_DIR})
        message(FATAL_ERROR "Environment variable ARIEO_PACKAGE_SOURCE_DIR is not defined")
    endif()
    
    # Read other parameters from environment variables
    if(NOT DEFINED ENV{ARIEO_PACKAGE_BUILDENV_HOST_PRESET})
        message(FATAL_ERROR "Environment variable ARIEO_PACKAGE_BUILDENV_HOST_PRESET is not defined")
    endif()
    
    if(NOT DEFINED ENV{ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE})
        message(FATAL_ERROR "Environment variable ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE is not defined")
    endif()
    
    # Determine build folder based on package name pattern
    # Try to detect package name from common environment variable patterns
    if(DEFINED ENV{ARIEO_PACKAGE_CORE_BUILD_FOLDER})
        set(BUILD_FOLDER_VAR $ENV{ARIEO_PACKAGE_CORE_BUILD_FOLDER})
    elseif(DEFINED BUILD_FOLDER)
        set(BUILD_FOLDER_VAR ${BUILD_FOLDER})
    else()
        message(FATAL_ERROR "BUILD_FOLDER must be defined via -DBUILD_FOLDER or ARIEO_PACKAGE_*_BUILD_FOLDER environment variable")
    endif()
    
    # Calculate output folder
    set(OUTPUT_FOLDER_VAR "${BUILD_FOLDER_VAR}/$ENV{ARIEO_PACKAGE_BUILDENV_HOST_PRESET}/$ENV{ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE}")
    
    # Call the function
    build_cmake_project_package(
        SOURCE_CMAKE_LIST_DIR $ENV{ARIEO_PACKAGE_SOURCE_DIR}
        PRESET $ENV{ARIEO_PACKAGE_BUILDENV_HOST_PRESET}
        BUILD_TYPE $ENV{ARIEO_PACKAGE_BUILDENV_HOST_BUILD_TYPE}
        BUILD_FOLDER ${BUILD_FOLDER_VAR}
        OUTPUT_FOLDER ${OUTPUT_FOLDER_VAR}
    )
endif()
