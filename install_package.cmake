cmake_minimum_required(VERSION 3.20)

function(generate_conan_toolchain_profile)
    set(oneValueArgs
        CONAN_PROFILE_FILE
        INSTALL_FOLDER
    )
    
    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    message(STATUS "Using INSTALL_FOLDER: ${ARGUMENT_INSTALL_FOLDER}")
    # Clean install folder before installing new artifacts
    if(EXISTS "${ARGUMENT_INSTALL_FOLDER}")
        message(STATUS "Cleaning install folder: ${ARGUMENT_INSTALL_FOLDER}")
        file(REMOVE_RECURSE "${ARGUMENT_INSTALL_FOLDER}")
    endif()
    # Recreate install directory
    file(MAKE_DIRECTORY "${ARGUMENT_INSTALL_FOLDER}")

    execute_process(
        COMMAND conan
            install ${CMAKE_CURRENT_LIST_DIR}/conan/conanfile.txt
            --update
            --generator CMakeToolchain
            --output-folder ${ARGUMENT_INSTALL_FOLDER}
            --build=never
            --profile=${ARGUMENT_CONAN_PROFILE_FILE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        RESULT_VARIABLE CONAN_RESULT
        ECHO_OUTPUT_VARIABLE    # This shows output in real time
        ECHO_ERROR_VARIABLE     # This shows errors in real time
        COMMAND_ECHO STDOUT      # Echo the command being executed
    )
    
    if(NOT CONAN_RESULT EQUAL 0)
        message(FATAL_ERROR "Conan install failed")
        exit(1)
    endif()

    # Make all .sh under INSTALL_FOLDER executable
    if (NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        file(GLOB_RECURSE SH_FILES "${ARGUMENT_INSTALL_FOLDER}/*.sh")
        foreach(SH_FILE ${SH_FILES})
            execute_process(
                COMMAND chmod +x "${SH_FILE}"
                RESULT_VARIABLE CHMOD_RESULT
            )
            if(NOT CHMOD_RESULT EQUAL 0)
                message(FATAL_ERROR "Failed to make ${SH_FILE} executable")
                exit(1)
            endif()
            message(LOG "Make ${SH_FILE} executable")
        endforeach()
    endif()

    # Copy conanfile.txt to INSTALL_FOLDER
    file(COPY ${ARGUMENT_CONAN_PROFILE_FILE} DESTINATION ${ARGUMENT_INSTALL_FOLDER})
endfunction()

# Check if ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET is defined in environment
if(NOT DEFINED ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET})
    message(FATAL_ERROR "Environment variable ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET is not defined")
endif()

if ($ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET} STREQUAL "android.armv8")
    generate_conan_toolchain_profile(
        CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.android.armv8.txt
        INSTALL_FOLDER $ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/conan/host/$ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET}
    )
endif()

if ($ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET} STREQUAL "raspberry.armv8")
    generate_conan_toolchain_profile(
        CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.raspberry.armv8.txt
        INSTALL_FOLDER $ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/conan/host/$ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET}
    )
endif()

if ($ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET} STREQUAL "ubuntu.x86_64")
    generate_conan_toolchain_profile(
        CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.ubuntu.x86_64.txt
        INSTALL_FOLDER $ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/conan/host/$ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET}
    )
endif()

# Add host profiles only for windows platform
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    if ($ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET} STREQUAL "windows.x86_64")
        generate_conan_toolchain_profile(
            CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.windows.x86_64.txt
            INSTALL_FOLDER $ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/conan/host/$ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET}
        )
    endif()
else()
    #message(FATAL_ERROR "Windows platform only support Windows host system.")
endif()

# Add host profiles only for darwin platform
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    if ($ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET} STREQUAL "macos.arm64")
        generate_conan_toolchain_profile(
            CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.macos.arm64.txt
            INSTALL_FOLDER $ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/host/$ENV{ARIEO_PACKAGE_BUILD_SETTING_HOST_PRESET}
        )
    endif()
else()
    #message(FATAL_ERROR "macOS platform only supports Darwin host system.")
endif()

##########################################################################################
# Create a stub cmake file in INSTALL_FOLDER that includes BuildEnv cmake
file(MAKE_DIRECTORY "$ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/cmake")
file(WRITE "$ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/cmake/build_environment.cmake"
"include(\"${CMAKE_CURRENT_LIST_DIR}/cmake/engine_project.cmake\")\n"
"include(\"${CMAKE_CURRENT_LIST_DIR}/cmake/package/build_engine_project_package.cmake\")\n"
"include(\"${CMAKE_CURRENT_LIST_DIR}/cmake/package/install_engine_project_package.cmake\")\n"
)

##########################################################################################
# Generate CMakeUserPresets.json in source directory with resolved paths
file(WRITE "$ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/cmake/CMakePresets.json"
"{
    \"version\": 4,
    \"cmakeMinimumRequired\": {
        \"major\": 3,
        \"minor\": 20,
        \"patch\": 0
    },
    \"include\": [
        \"${CMAKE_CURRENT_LIST_DIR}/cmake/presets/base.json\",
        \"${CMAKE_CURRENT_LIST_DIR}/cmake/presets/windows.x86_64.json\",
        \"${CMAKE_CURRENT_LIST_DIR}/cmake/presets/macos.arm64.json\",
        \"${CMAKE_CURRENT_LIST_DIR}/cmake/presets/ubuntu.x86_64.json\",
        \"${CMAKE_CURRENT_LIST_DIR}/cmake/presets/raspberry.armv8.json\",
        \"${CMAKE_CURRENT_LIST_DIR}/cmake/presets/android.armv8.json\",
        \"${CMAKE_CURRENT_LIST_DIR}/cmake/presets/windows-dev.x86_64.json\"
    ]
}
")
message(STATUS "Generated CMakeUserPresets.json in ${ARGUMENT_SOURCE_CMAKE_LIST_DIR}")

##########################################################################################
# Generate wrapper file for build_engine_project_package.cmake
file(WRITE "$ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/cmake/package/build_engine_project_package.cmake"
"cmake_minimum_required(VERSION 3.20)\n"
"\n"
"# Include the build package function\n"
"include(${CMAKE_CURRENT_LIST_DIR}/cmake/package/build_engine_project_package.cmake)\n"
)
message(STATUS "Generated build_engine_project_package.cmake wrapper")

##########################################################################################
# Generate wrapper file for install_engine_project_package.cmake
file(WRITE "$ENV{ARIEO_CUR_PACKAGE_INSTALL_FOLDER}/cmake/package/install_engine_project_package.cmake"
"cmake_minimum_required(VERSION 3.20)\n"
"\n"
"# Include the install package function\n"
"include(${CMAKE_CURRENT_LIST_DIR}/cmake/package/install_engine_project_package.cmake)\n"
)
message(STATUS "Generated install_engine_project_package.cmake wrapper")