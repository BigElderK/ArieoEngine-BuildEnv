cmake_minimum_required(VERSION 3.31)

# Main dispatcher function
function(ARIEO_PACKAGE package)
    set(oneValueArgs
        CATEGORY
        URL
    )

    set(multiValueArgs 
        DEPENDS
        COMPONENTS
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN}
    )

    # log debug info about the project type
    message(STATUS "Configuring package ${package_name} of category ${ARGUMENT_CATEGORY} with configure preset ${ARGUMENT_BUILD_CONFIGURE_PRESET}")
    message(STATUS "Configuring package ${package_name} with components: ${ARGUMENT_COMPONENTS}")
    message(STATUS "Configuring package ${package_name} with URL: ${ARGUMENT_URL}")
    if(DEFINED ARGUMENT_DEPENDS)
        message(STATUS "Configuring package ${package_name} with dependencies: ${ARGUMENT_DEPENDS}")
    endif()
    
    # Set global variables for package name and category to be used in install function
    # set(ARIEO_PACKAGE_NAME "${package}" CACHE INTERNAL "Name for Arieo package")
    # set(ARIEO_PACKAGE_CATEGORY "${ARGUMENT_CATEGORY}" CACHE INTERNAL "Category for Arieo packages")
    set(ARIEO_PACKAGE_NAME "${package}" PARENT_SCOPE)
    set(ARIEO_PACKAGE_CATEGORY "${ARGUMENT_CATEGORY}" PARENT_SCOPE)
    add_custom_target(
        ${package}
        DEPENDS 
            ${ARGUMENT_COMPONENTS}
    )
endfunction()