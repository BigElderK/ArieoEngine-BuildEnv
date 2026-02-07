cmake_minimum_required(VERSION 3.31)

function(arieo_headonly_library_project target_project)
    set(oneValueArgs 
        ALIAS
    )

    set(multiValueArgs 
        PUBLIC_INCLUDE_FOLDERS
        PACKAGES
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})

    # Create INTERFACE library target for header-only library
    add_library(${target_project} INTERFACE)
    
    if(DEFINED ARGUMENT_ALIAS)
        add_library(${ARGUMENT_ALIAS} ALIAS ${target_project})
    endif()

    foreach(ARGUMENT_PACKAGE IN LISTS ARGUMENT_PACKAGES)
        find_package(${ARGUMENT_PACKAGE} REQUIRED)
    endforeach()

    # Set public include directories using generator expressions
    # INTERFACE libraries require generator expressions to distinguish build vs install paths
    foreach(INCLUDE_FOLDER ${ARGUMENT_PUBLIC_INCLUDE_FOLDERS})
        target_include_directories(
            ${target_project}
            INTERFACE 
                $<BUILD_INTERFACE:${INCLUDE_FOLDER}>
                $<INSTALL_INTERFACE:include>
        )
    endforeach()

    message(STATUS "Created header-only library: ${target_project}")

endfunction()
