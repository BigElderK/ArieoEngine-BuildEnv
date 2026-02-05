cmake_minimum_required(VERSION 3.20)

# INSTALL_FOLDER must be set from command line or environment variable
if(NOT DEFINED INSTALL_FOLDER)
    # Try to get from environment variable
    if(DEFINED ENV{INSTALL_FOLDER})
        set(INSTALL_FOLDER "$ENV{INSTALL_FOLDER}")
        message(STATUS "Using INSTALL_FOLDER from environment: ${INSTALL_FOLDER}")
    else()
        message(FATAL_ERROR "INSTALL_FOLDER is not defined. Please specify it with -DINSTALL_FOLDER=<path> or set INSTALL_FOLDER environment variable")
    endif()
else()
    message(STATUS "Using INSTALL_FOLDER from command line: ${INSTALL_FOLDER}")
endif()

# Check if ARIEO_PACKAGE_BUILDENV_HOST_PRESET is defined
if(NOT DEFINED ARIEO_PACKAGE_BUILDENV_HOST_PRESET)
    # Try to get from environment variable
    if(DEFINED ENV{ARIEO_PACKAGE_BUILDENV_HOST_PRESET})
        set(ARIEO_PACKAGE_BUILDENV_HOST_PRESET "$ENV{ARIEO_PACKAGE_BUILDENV_HOST_PRESET}")
        message(STATUS "Using ARIEO_PACKAGE_BUILDENV_HOST_PRESET from environment: ${ARIEO_PACKAGE_BUILDENV_HOST_PRESET}")
    else()
        message(FATAL_ERROR "ARIEO_PACKAGE_BUILDENV_HOST_PRESET is not defined. Please specify it with -DARIEO_PACKAGE_BUILDENV_HOST_PRESET=<preset> or set ARIEO_PACKAGE_BUILDENV_HOST_PRESET environment variable")
    endif()
else()
    message(STATUS "Using ARIEO_PACKAGE_BUILDENV_HOST_PRESET from command line: ${ARIEO_PACKAGE_BUILDENV_HOST_PRESET}")
endif()


message(STATUS "Using INSTALL_FOLDER: ${INSTALL_FOLDER}")

function(generate_conan_toolchain_profile)
    set(oneValueArgs
        CONAN_PROFILE_FILE
        OUTPUT_FOLDER
    )
    
    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    execute_process(
        COMMAND conan
            install ${CMAKE_CURRENT_LIST_DIR}/conan/conanfile.txt
            --update
            --generator CMakeToolchain
            --output-folder ${ARGUMENT_OUTPUT_FOLDER}
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

    # Make all .sh under OUTPUT_FOLDER executable
    if (NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        file(GLOB_RECURSE SH_FILES "${ARGUMENT_OUTPUT_FOLDER}/*.sh")
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

    # Copy conanfile.txt to OUTPUT_FOLDER
    file(COPY ${ARGUMENT_CONAN_PROFILE_FILE} DESTINATION ${ARGUMENT_OUTPUT_FOLDER})
endfunction()


if (ARIEO_PACKAGE_BUILDENV_HOST_PRESET STREQUAL "android.armv8")
    generate_conan_toolchain_profile(
        CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.android.armv8.txt
        OUTPUT_FOLDER ${INSTALL_FOLDER}/conan/host/${ARIEO_PACKAGE_BUILDENV_HOST_PRESET}
    )
endif()

if (ARIEO_PACKAGE_BUILDENV_HOST_PRESET STREQUAL "raspberry.armv8")
    generate_conan_toolchain_profile(
        CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.raspberry.armv8.txt
        OUTPUT_FOLDER ${INSTALL_FOLDER}/conan/host/${ARIEO_PACKAGE_BUILDENV_HOST_PRESET}
    )
endif()

if (ARIEO_PACKAGE_BUILDENV_HOST_PRESET STREQUAL "ubuntu.x86_64")
    generate_conan_toolchain_profile(
        CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.ubuntu.x86_64.txt
        OUTPUT_FOLDER ${INSTALL_FOLDER}/conan/host/${ARIEO_PACKAGE_BUILDENV_HOST_PRESET}
    )
endif()

# Add host profiles only for windows platform
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    if (ARIEO_PACKAGE_BUILDENV_HOST_PRESET STREQUAL "windows.x86_64")
        generate_conan_toolchain_profile(
            CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.windows.x86_64.txt
            OUTPUT_FOLDER ${INSTALL_FOLDER}/conan/host/${ARIEO_PACKAGE_BUILDENV_HOST_PRESET}
        )
    endif()
else()
    #message(FATAL_ERROR "Windows platform only support Windows host system.")
endif()

# Add host profiles only for darwin platform
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    if (ARIEO_PACKAGE_BUILDENV_HOST_PRESET STREQUAL "macos.arm64")
        generate_conan_toolchain_profile(
            CONAN_PROFILE_FILE ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.macos.arm64.txt
            OUTPUT_FOLDER ${INSTALL_FOLDER}/host/${ARIEO_PACKAGE_BUILDENV_HOST_PRESET}
        )
    endif()
else()
    #message(FATAL_ERROR "macOS platform only supports Darwin host system.")
endif()

# Copy cmake folder to INSTALL_FOLDER
file(COPY ${CMAKE_CURRENT_LIST_DIR}/cmake DESTINATION ${INSTALL_FOLDER})