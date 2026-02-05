cmake_minimum_required(VERSION 3.20)

function(build_engine_project)
    set(oneValueArgs
        SOURCE_CMAKE_LIST_DIR
        PRESET
        TARGET_PROJECT
        BUILD_TYPE
        BUILD_FOLDER
        OUTPUT_FOLDER
    )
    
    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    ##########################################################################################
    # set prebuid patches based on preset
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(CMAKE_HOST_BATCH_SUFFIX .bat)
    else()
        set(CMAKE_HOST_BATCH_SUFFIX .sh)
    endif()

    # set prebuid patches based on preset
    if(ARGUMENT_PRESET STREQUAL "android.armv8")
        set(PREBUILD_BATCH $ENV{ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/conan/host/${ARGUMENT_PRESET}/conanbuild${CMAKE_HOST_BATCH_SUFFIX})
    endif()

    if(ARGUMENT_PRESET STREQUAL "raspberry.armv8")
        set(PREBUILD_BATCH $ENV{ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/conan/host/${ARGUMENT_PRESET}/conanbuild${CMAKE_HOST_BATCH_SUFFIX})
    endif()

    if(ARGUMENT_PRESET STREQUAL "ubuntu.x86_64")
        set(PREBUILD_BATCH $ENV{ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/conan/host/${ARGUMENT_PRESET}/conanbuild${CMAKE_HOST_BATCH_SUFFIX})
    endif()

    if(ARGUMENT_PRESET STREQUAL "windows.x86_64")
        set(PREBUILD_BATCH $ENV{ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/conan/host/${ARGUMENT_PRESET}/conanbuild${CMAKE_HOST_BATCH_SUFFIX})
    endif()

    if(ARGUMENT_PRESET STREQUAL "macos.arm64")
        set(PREBUILD_BATCH $ENV{ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/conan/host/${ARGUMENT_PRESET}/conanbuild${CMAKE_HOST_BATCH_SUFFIX})
    endif()

    ##########################################################################################
    # Generate CMakeUserPresets.json in source directory with resolved paths
    set(FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER "$ENV{ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}")
    # Convert to forward slashes (JSON and CMake both accept them on all platforms)
    string(REPLACE "\\" "/" FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER "${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}")
    file(WRITE "${ARGUMENT_SOURCE_CMAKE_LIST_DIR}/CMakeUserPresets.json"
"{
    \"version\": 4,
    \"cmakeMinimumRequired\": {
        \"major\": 3,
        \"minor\": 20,
        \"patch\": 0
    },
    \"include\": [
        \"${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/cmake/presets/base.json\",
        \"${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/cmake/presets/windows.x86_64.json\",
        \"${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/cmake/presets/macos.arm64.json\",
        \"${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/cmake/presets/ubuntu.x86_64.json\",
        \"${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/cmake/presets/raspberry.armv8.json\",
        \"${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/cmake/presets/android.armv8.json\",
        \"${FORMATTED_ARIEO_PACKAGE_BUILDENV_OUTPUT_FOLDER}/cmake/presets/windows-dev.x86_64.json\"
    ]
}
")
    message(STATUS "Generated CMakeUserPresets.json in ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}")

    ##########################################################################################
    # CMake configure steps

    # Configure engine with CMake (using shell to properly chain conan environment setup)
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        execute_process(
            COMMAND cmd /c "${PREBUILD_BATCH} && cmake -S ${ARGUMENT_SOURCE_CMAKE_LIST_DIR} -B ${ARGUMENT_BUILD_FOLDER} --preset=${ARGUMENT_PRESET} -DCMAKE_BUILD_TYPE=${ARGUMENT_BUILD_TYPE} -DTARGET_PROJECT_OUTPUT_FOLDER=${ARGUMENT_OUTPUT_FOLDER}"
            WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
            RESULT_VARIABLE CMAKE_RESULT
            ECHO_OUTPUT_VARIABLE    # This shows output in real time
            ECHO_ERROR_VARIABLE     # This shows errors in real time
            COMMAND_ECHO STDOUT      # Echo the command being executed
        )
    else()
        execute_process(
            COMMAND sh -c "source ${PREBUILD_BATCH} && cmake -S ${ARGUMENT_SOURCE_CMAKE_LIST_DIR} -B ${ARGUMENT_BUILD_FOLDER} --preset=${ARGUMENT_PRESET} -DCMAKE_BUILD_TYPE=${ARGUMENT_BUILD_TYPE} -DTARGET_PROJECT_OUTPUT_FOLDER=${ARGUMENT_OUTPUT_FOLDER}"
            WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
            RESULT_VARIABLE CMAKE_RESULT
            ECHO_OUTPUT_VARIABLE    # This shows output in real time
            ECHO_ERROR_VARIABLE     # This shows errors in real time
            COMMAND_ECHO STDOUT      # Echo the command being executed
        )
    endif()

    if(NOT CMAKE_RESULT EQUAL 0)
        message(FATAL_ERROR "CMake configure failed")
        exit(1)
    endif()

    ##########################################################################################
    # CMake build steps
    # Build engine (using shell to properly chain conan environment setup)
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        execute_process(
            COMMAND cmd /c "${PREBUILD_BATCH} && cmake --build ${ARGUMENT_BUILD_FOLDER} --target ${ARGUMENT_TARGET_PROJECT}"
            WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
            RESULT_VARIABLE CMAKE_RESULT
            ECHO_OUTPUT_VARIABLE    # This shows output in real time
            ECHO_ERROR_VARIABLE     # This shows errors in real time
            COMMAND_ECHO STDOUT      # Echo the command being executed
        )
    else()
        execute_process(
            COMMAND sh -c "source ${PREBUILD_BATCH} && cmake --build ${ARGUMENT_BUILD_FOLDER} --target ${ARGUMENT_TARGET_PROJECT}"
            WORKING_DIRECTORY ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}
            RESULT_VARIABLE CMAKE_RESULT
            ECHO_OUTPUT_VARIABLE    # This shows output in real time
            ECHO_ERROR_VARIABLE     # This shows errors in real time
            COMMAND_ECHO STDOUT      # Echo the command being executed
        )
    endif()

    if(NOT CMAKE_RESULT EQUAL 0)
        message(FATAL_ERROR "CMake build failed")
        exit(1)
    endif()
endfunction()