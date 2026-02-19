function(project_sources_parameters target_project)
    set(multiValueArgs 
        PUBLIC_INCLUDE_FOLDERS
        INTERFACE_INCLUDE_FOLDERS
        PRIVATE_INCLUDE_FOLDERS
        CXX_SOURCES
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        ""
        "${multiValueArgs}"
        ${ARGN}
    )

    # Add sources - resolve relative paths 
    if(DEFINED ARGUMENT_CXX_SOURCES)
        set(resolved_patterns)
        foreach(pattern ${ARGUMENT_CXX_SOURCES})
            if(IS_ABSOLUTE ${pattern})
                list(APPEND resolved_patterns ${pattern})
            else()
                list(APPEND resolved_patterns ${CMAKE_CURRENT_SOURCE_DIR}/${pattern})
            endif()
        endforeach()
        
        message(STATUS "Input patterns for ${target_project}: ${ARGUMENT_CXX_SOURCES}")
        message(STATUS "Resolved patterns for ${target_project}: ${resolved_patterns}")
        file(GLOB default_source_files
            ${resolved_patterns}
        )

        target_sources(
            ${target_project}
            PRIVATE 
                ${default_source_files}
        )
    endif()

    # Add private include folders
    if(DEFINED ARGUMENT_PRIVATE_INCLUDE_FOLDERS)
        target_include_directories(
            ${target_project}
            PRIVATE 
                ${ARGUMENT_PRIVATE_INCLUDE_FOLDERS}
        )
    endif()

    # Set output directories and include paths
    if(DEFINED ARGUMENT_PUBLIC_INCLUDE_FOLDERS)
        target_include_directories(
            ${target_project}
            PUBLIC 
                $<BUILD_INTERFACE:${ARGUMENT_PUBLIC_INCLUDE_FOLDERS}>
                $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        )
    endif()

    # Add interface include folders (for INTERFACE/header-only libraries)
    if(DEFINED ARGUMENT_INTERFACE_INCLUDE_FOLDERS)
        target_include_directories(
            ${target_project}
            INTERFACE 
                $<BUILD_INTERFACE:${ARGUMENT_INTERFACE_INCLUDE_FOLDERS}>
                $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        )
    endif()
endfunction()
