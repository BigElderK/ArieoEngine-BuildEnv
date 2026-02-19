function(project_basic_paramters target_project)
    set(oneValueArgs 
        PROJECT_TYPE
        ALIAS
    )
 
    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        ""
        ${ARGN}
    )

    string(TOLOWER "${ARGUMENT_PROJECT_TYPE}" ARGUMENT_PROJECT_TYPE)
    if(NOT ARGUMENT_PROJECT_TYPE)
        message(FATAL_ERROR "PROJECT_TYPE is required for project ${target_project}")
    endif()
    # Create the target first based on project type
    if("${ARGUMENT_PROJECT_TYPE}" STREQUAL "base")
        add_library(${target_project} STATIC)
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "static_library")
        add_library(${target_project} STATIC)
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "shared_library")
        add_library(${target_project} MODULE)
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "headonly_library")
        add_library(${target_project} INTERFACE)
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "interface")
        add_library(${target_project} INTERFACE)
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "interface_linker")
        add_library(${target_project} SHARED)
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "module")
        add_library(${target_project} MODULE)
    elseif("${ARGUMENT_PROJECT_TYPE}" STREQUAL "bootstrap")
        add_executable(${target_project})
    else()
        message(FATAL_ERROR "Unknown project type: ${ARGUMENT_PROJECT_TYPE}")
    endif()

    # set common compile definitions AFTER target is created
    # INTERFACE libraries require INTERFACE visibility
    if("${ARGUMENT_PROJECT_TYPE}" STREQUAL "headonly_library" OR "${ARGUMENT_PROJECT_TYPE}" STREQUAL "interface")
        target_compile_definitions(${target_project} INTERFACE 
            ARIEO_HOST_OS="${ARIEO_HOST_OS}"
        )
    else()
        target_compile_definitions(${target_project} PRIVATE 
            ARIEO_HOST_OS="${ARIEO_HOST_OS}"
        )
    endif()
endfunction()