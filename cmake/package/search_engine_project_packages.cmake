cmake_minimum_required(VERSION 3.20)

#[[
Function: add_engine_packages_to_prefix_path

Scans the ArieoEngine packages install directory and adds all package cmake 
directories to CMAKE_PREFIX_PATH, allowing find_package() to locate them.

Usage:
  # Add all packages for current platform/config
  add_engine_packages_to_prefix_path()
  
  # Then use packages normally
  find_package(arieo_core REQUIRED)
  target_link_libraries(my_target PRIVATE arieo::arieo_core)

Environment Variables Used:
  ARIEO_PACKAGE_ROOT_INSTALL_FOLDER - Base install folder (e.g., E:/ArieoEngine/packages/install)
  ARIEO_PACKAGE_BUILD_HOST_PRESET - Platform (e.g., windows.x86_64, ubuntu.x86_64)
  ARIEO_PACKAGE_BUILD_TYPE - Config (e.g., Debug, Release, RelWithDebInfo)

Alternative Parameters (if env vars not set):
  PACKAGES_ROOT  - Override base install folder
  HOST_PRESET    - Override platform
  BUILD_TYPE     - Override build configuration
]]
function(add_engine_packages_to_prefix_path)
    set(oneValueArgs
        PACKAGES_ROOT
        HOST_PRESET
    )
    
    cmake_parse_arguments(
        ARG
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )
    
    # Determine packages root folder
    if(ARG_PACKAGES_ROOT)
        set(PACKAGES_ROOT "${ARG_PACKAGES_ROOT}")
    elseif(DEFINED ENV{ARIEO_PACKAGE_ROOT_INSTALL_FOLDER})
        set(PACKAGES_ROOT "$ENV{ARIEO_PACKAGE_ROOT_INSTALL_FOLDER}")
    else()
        message(FATAL_ERROR "PACKAGES_ROOT not specified and ARIEO_PACKAGE_ROOT_INSTALL_FOLDER not set")
    endif()
    
    # Determine platform
    if(ARG_HOST_PRESET)
        set(HOST_PRESET "${ARG_HOST_PRESET}")
    elseif(DEFINED ENV{ARIEO_PACKAGE_BUILD_HOST_PRESET})
        set(HOST_PRESET "$ENV{ARIEO_PACKAGE_BUILD_HOST_PRESET}")
    else()
        message(FATAL_ERROR "HOST_PRESET not specified and ARIEO_PACKAGE_BUILD_HOST_PRESET not set")
    endif()
    
    # Verify packages root exists
    if(NOT EXISTS "${PACKAGES_ROOT}")
        message(FATAL_ERROR "Packages root folder does not exist: ${PACKAGES_ROOT}")
    endif()
    
    message(STATUS "================================================================")
    message(STATUS "Adding ArieoEngine packages to CMAKE_PREFIX_PATH")
    message(STATUS "  Packages Root: ${PACKAGES_ROOT}")
    message(STATUS "  Platform: ${HOST_PRESET}")
    
    # Collect all package directories
    set(PACKAGE_PATHS "")
    
    # Scan each category folder (00_build, 01_third_parties, 02_engine, etc.)
    file(GLOB CATEGORY_FOLDERS "${PACKAGES_ROOT}/*")
    foreach(CATEGORY_FOLDER ${CATEGORY_FOLDERS})
        if(IS_DIRECTORY "${CATEGORY_FOLDER}")
            # Scan each package in the category
            file(GLOB PACKAGE_FOLDERS "${CATEGORY_FOLDER}/*")
            foreach(PACKAGE_FOLDER ${PACKAGE_FOLDERS})
                if(IS_DIRECTORY "${PACKAGE_FOLDER}")
                    get_filename_component(PACKAGE_NAME "${PACKAGE_FOLDER}" NAME)
                    
                    # Try platform-specific multi-config layout
                    set(PLATFORM_INSTALL_PATH "${PACKAGE_FOLDER}/${HOST_PRESET}")
                    if(EXISTS "${PLATFORM_INSTALL_PATH}/cmake")
                        list(APPEND PACKAGE_PATHS "${PLATFORM_INSTALL_PATH}")
                        message(STATUS "  Added: ${PACKAGE_NAME} (${HOST_PRESET})")
                    elseif(EXISTS "${PACKAGE_FOLDER}/cmake")
                        # Try platform-agnostic packages (e.g., header-only)
                        list(APPEND PACKAGE_PATHS "${PACKAGE_FOLDER}")
                        message(STATUS "  Added: ${PACKAGE_NAME} (platform-agnostic)")
                    endif()
                endif()
            endforeach()
        endif()
    endforeach()
    
    # Add to CMAKE_PREFIX_PATH
    if(PACKAGE_PATHS)
        list(APPEND CMAKE_PREFIX_PATH ${PACKAGE_PATHS})
        # Make it visible to parent scope AND current scope
        set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} PARENT_SCOPE)
        set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} CACHE INTERNAL "Package search paths" FORCE)
        # Return PACKAGE_PATHS to parent scope for use in cmake -D arguments
        set(ARIEO_PACKAGES_PREFIX_PATH "${PACKAGE_PATHS}" PARENT_SCOPE)
        list(LENGTH PACKAGE_PATHS NUM_PACKAGES)
        message(STATUS "Added ${NUM_PACKAGES} packages to CMAKE_PREFIX_PATH")
        message(STATUS "CMAKE_PREFIX_PATH is now: ${CMAKE_PREFIX_PATH}")
        
        # Debug: Check if arieo_core config exists
        foreach(PKG_PATH ${PACKAGE_PATHS})
            if(EXISTS "${PKG_PATH}/cmake/arieo_coreConfig.cmake")
                message(STATUS "  ✓ Found arieo_coreConfig.cmake at: ${PKG_PATH}/cmake/")
            endif()
        endforeach()
    else()
        message(WARNING "No packages found in ${PACKAGES_ROOT}")
    endif()
    
    message(STATUS "================================================================")
endfunction()