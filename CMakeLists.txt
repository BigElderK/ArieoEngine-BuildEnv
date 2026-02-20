cmake_minimum_required(VERSION 3.14)

set(ARIEO_PROJECT_CATEGORY "00_build" CACHE INTERNAL "Category for Arieo packages")
project(
    Arieo-BuildEnv
    VERSION 0.1.0
    DESCRIPTION "Build environment setup for Arieo Engine"
    HOMEPAGE_URL "https://github.com/BigElderK/Arieo-BuildEnv.git"
)
add_custom_target(Arieo-BuildEnv DEPENDS arieo_build_env)

##########################################################################################
# Check if Environment ARIEO_PACKAGES_BUILD_OUTPUT_DIR is defined (set by install_build_env.py) and use it as the output directory for conan builds
if(NOT DEFINED ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR})
    message(WARNING "Environment variable ARIEO_PACKAGES_BUILD_OUTPUT_DIR is not defined. Conan build output will be placed in ${CMAKE_BINARY_DIR}/conan_build_output")
    set(ARIEO_PACKAGES_BUILD_OUTPUT_DIR ${CMAKE_BINARY_DIR}/conan_build_output)
else()
    set(ARIEO_PACKAGES_BUILD_OUTPUT_DIR $ENV{ARIEO_PACKAGES_BUILD_OUTPUT_DIR})
    message(STATUS "Using ARIEO_PACKAGES_BUILD_OUTPUT_DIR: ${ARIEO_PACKAGES_BUILD_OUTPUT_DIR}")
endif()
    
set(ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR ${ARIEO_PACKAGES_BUILD_OUTPUT_DIR}/${ARIEO_PROJECT_CATEGORY}/${PROJECT_NAME})

# Ensure output directory exists (configure_file doesn't create parent directories)
file(MAKE_DIRECTORY ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR})

##########################################################################################
# CMAKE_CONFIGURE_PRESET is set by install_config.cmake included before this script
# Check if CMAKE_CONFIGURE_PRESET is defined
if(NOT DEFINED CMAKE_CONFIGURE_PRESET)
    message(FATAL_ERROR "Variable CMAKE_CONFIGURE_PRESET is not defined. install_config.cmake should be included first.")
endif()

# Normal preset handling
if (${CMAKE_CONFIGURE_PRESET} STREQUAL "android.armv8")
    set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.android.armv8.txt)
endif()

if (${CMAKE_CONFIGURE_PRESET} STREQUAL "raspberry.armv8")
    set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.raspberry.armv8.txt)
endif()

if (${CMAKE_CONFIGURE_PRESET} STREQUAL "ubuntu.x86_64")
    set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.ubuntu.x86_64.txt)
endif()

# Add host profiles only for windows platform
if (${CMAKE_CONFIGURE_PRESET} STREQUAL "windows.x86_64")
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.windows.x86_64.txt)    
    else()
        message(WARNING "Preset windows.x86_64 is only supported on Windows host platform.")
    endif()
endif()

message(STATUS "Using Conan host profile: ${conan_host_profile_file}")

# Add host profiles only for darwin platform
if (${CMAKE_CONFIGURE_PRESET} STREQUAL "macos.arm64")
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.macos.arm64.txt)
    else()
        message(WARNING "Preset macos.arm64 is only supported on Darwin host platform.")
    endif()
endif()


if (DEFINED conan_host_profile_file)
    # Use a stamp file to track conan installation completion (preset-specific)
    set(CONAN_STAMP_FILE ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${CMAKE_CONFIGURE_PRESET}/.conan_install_complete)

    # Ensure the conan directory exists
    file(MAKE_DIRECTORY ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${CMAKE_CONFIGURE_PRESET})

    add_custom_command(
        OUTPUT ${CONAN_STAMP_FILE}
        DEPENDS 
            ${conan_host_profile_file}

            ${CMAKE_CURRENT_LIST_DIR}/conan/conanfile.txt
        COMMAND ${CMAKE_COMMAND} -E rm -f ${CONAN_STAMP_FILE}
        COMMAND ${CMAKE_COMMAND} -E echo "Running conan install for ${CMAKE_CONFIGURE_PRESET}"
        COMMAND conan
            install ${CMAKE_CURRENT_LIST_DIR}/conan/conanfile.txt
            --update
            --generator CMakeToolchain
            --output-folder ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${CMAKE_CONFIGURE_PRESET}
            --build=never
            --profile=${conan_host_profile_file}
        COMMAND ${CMAKE_COMMAND} -E touch ${CONAN_STAMP_FILE}
        COMMENT "Running conan install for preset: ${CMAKE_CONFIGURE_PRESET}"
        USES_TERMINAL
        VERBATIM
    )
else()
    message(VERBOSE "No valid Conan host profile found for preset ${CMAKE_CONFIGURE_PRESET}. Skip conan install")
endif()

# Generate wrapper files from templates
configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/build_environment.cmake.in
    ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/build_environment.cmake
    @ONLY
)

configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/CMakePresets.json.in
    ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/CMakePresets.json
    @ONLY
)

# This target will be built as part of ALL
add_custom_target(arieo_build_env ALL
    DEPENDS ${CONAN_STAMP_FILE}
)

###########################################################################
# Install conan generated files (only if conan profile is defined)

if(DEFINED conan_host_profile_file)
    install(DIRECTORY ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${CMAKE_CONFIGURE_PRESET}/
        DESTINATION conan/host/${CMAKE_CONFIGURE_PRESET}
    )

    install(
        FILES ${conan_host_profile_file}
        DESTINATION conan/host/${CMAKE_CONFIGURE_PRESET}
    )
endif()

# Install generated wrapper files
install(
    FILES ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/build_environment.cmake
    DESTINATION cmake
)

install(
    FILES ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/CMakePresets.json
    DESTINATION cmake
)

