cmake_minimum_required(VERSION 3.14)

include(${CMAKE_CURRENT_LIST_DIR}/cmake/build_environment.cmake)

ArieoPackage(
    Arieo-BuildEnv
    CATEGORY 00_build
    COMPONENTS
        generate_toolchain_from_conan
        copy_cmake_presets
)

##########################################################################################
# Check if Environment ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR is defined (set by install_py) and use it as the output directory for conan builds
if(NOT DEFINED ENV{ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR})
    message(WARNING "Environment variable ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR is not defined. Conan build output will be placed in ${CMAKE_BINARY_DIR}/conan_build_output")
    set(ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR ${CMAKE_BINARY_DIR})
else()
    set(ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR $ENV{ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR})
    message(STATUS "Using ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR: ${ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR}")
endif()
    
set(ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR ${ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR})

# Ensure output directory exists (configure_file doesn't create parent directories)
file(MAKE_DIRECTORY ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR})

##########################################################################################
# ARIEO_BUILD_CONFIGURE_PRESET is set by install_config.cmake included before this script
# Check if ARIEO_BUILD_CONFIGURE_PRESET is defined
if(NOT DEFINED ARIEO_BUILD_CONFIGURE_PRESET)
    message(FATAL_ERROR "Variable ARIEO_BUILD_CONFIGURE_PRESET is not defined. install_config.cmake should be included first.")
endif()

# Normal preset handling
if (${ARIEO_BUILD_CONFIGURE_PRESET} STREQUAL "android.armv8")
    set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.android.armv8.txt)
endif()

if (${ARIEO_BUILD_CONFIGURE_PRESET} STREQUAL "raspberry.armv8")
    set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.raspberry.armv8.txt)
endif()

if (${ARIEO_BUILD_CONFIGURE_PRESET} STREQUAL "ubuntu.x86_64")
    set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.ubuntu.x86_64.txt)
endif()

# Add host profiles only for windows platform
if (${ARIEO_BUILD_CONFIGURE_PRESET} STREQUAL "windows.x86_64")
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.windows.x86_64.txt)    
    else()
        message(WARNING "Preset windows.x86_64 is only supported on Windows host platform.")
    endif()
endif()

# Add host profiles only for darwin platform
if (${ARIEO_BUILD_CONFIGURE_PRESET} STREQUAL "macos.arm64")
    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(conan_host_profile_file ${CMAKE_CURRENT_LIST_DIR}/conan/profiles/host/conan_host_profile.macos.arm64.txt)
    else()
        message(WARNING "Preset macos.arm64 is only supported on Darwin host platform.")
    endif()
endif()

message(STATUS "Using Conan host profile: ${conan_host_profile_file}")

# This target will be built as part of ALL
add_custom_target(
    generate_toolchain_from_conan ALL
)

if (DEFINED conan_host_profile_file)
    # Use a stamp file to track conan installation completion (preset-specific)
    set(CONAN_STAMP_FILE ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${ARIEO_BUILD_CONFIGURE_PRESET}/.conan_install_complete)
    
    add_custom_target(
        conan_generation_stamp_file ALL
        DEPENDS ${CONAN_STAMP_FILE}
    )
    add_dependencies(
        generate_toolchain_from_conan 
        conan_generation_stamp_file
    )

    # Ensure the conan directory exists
    file(MAKE_DIRECTORY ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${ARIEO_BUILD_CONFIGURE_PRESET})

    add_custom_command(
        OUTPUT ${CONAN_STAMP_FILE}
        DEPENDS 
            ${conan_host_profile_file}
            ${CMAKE_CURRENT_LIST_DIR}/conan/conanfile.txt
        COMMAND ${CMAKE_COMMAND} -E rm -f ${CONAN_STAMP_FILE}
        COMMAND ${CMAKE_COMMAND} -E echo "Running conan install for ${ARIEO_BUILD_CONFIGURE_PRESET}"
        COMMAND conan
            install ${CMAKE_CURRENT_LIST_DIR}/conan/conanfile.txt
            --update
            --generator CMakeToolchain
            --output-folder ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${ARIEO_BUILD_CONFIGURE_PRESET}
            --build=never
            --profile=${conan_host_profile_file}
        COMMAND ${CMAKE_COMMAND} -E touch ${CONAN_STAMP_FILE}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${conan_host_profile_file}
            ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/conan/host/${ARIEO_BUILD_CONFIGURE_PRESET}/
        COMMENT "Running conan install for preset: ${ARIEO_BUILD_CONFIGURE_PRESET}"
        USES_TERMINAL
        VERBATIM
    )
else()
    message(VERBOSE "No valid Conan host profile found for preset ${ARIEO_BUILD_CONFIGURE_PRESET}. Skip conan install")
endif()

# Generate wrapper files from templates
configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/build_environment.cmake.in
    ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/cmake/build_environment.cmake
    @ONLY
)


configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/cmake/CMakePresets.json.in
    ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/cmake/CMakePresets.json
    @ONLY
)

set(ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR $ENV{ARIEO_BUILD_ENV_PACKAGES_OUTPUT_DIR})
set(ARIEO_THIRDPARTIES_PACKAGES_OUTPUT_DIR $ENV{ARIEO_THIRDPARTIES_PACKAGES_OUTPUT_DIR})
configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/cmake/presets/base.json.in
    ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/cmake/presets/base.json
    @ONLY
)

########################################################################
# copy CMakePresets.json to the source directory as well for better IDE integration (some IDEs only look for CMakePresets.json in the source directory)
add_custom_command(
    OUTPUT $ENV{ARIEO_WORKSPACE_ROOT_DIR}/CMakeUserPresets.json
    # Copy all files from presets directory during build stage
    COMMAND ${CMAKE_COMMAND} -E make_directory ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/cmake/presets
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_LIST_DIR}/cmake/presets
        ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/cmake/presets
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/cmake/CMakePresets.json
        $ENV{ARIEO_WORKSPACE_ROOT_DIR}/CMakeUserPresets.json
    DEPENDS ${ARIEO_CUR_PACKAGE_BUILD_OUTPUT_DIR}/cmake/CMakePresets.json
    COMMENT "Copying CMakePresets.json to source directory for IDE integration"
)
add_custom_target(copy_cmake_presets ALL
    DEPENDS $ENV{ARIEO_WORKSPACE_ROOT_DIR}/CMakeUserPresets.json
)


