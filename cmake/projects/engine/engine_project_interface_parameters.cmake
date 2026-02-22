function(project_interface_paramters target_project)
    set(multiValueArgs 
        INTERFACE_INCLUDE_FOLDERS
        PACKAGES
        INTERFACES
        PUBLIC_LIBS
        PRIVATE_LIBS
    )

    cmake_parse_arguments(
        ARGUMENT
        ""
        ""
        "${multiValueArgs}"
        ${ARGN}
    )

    # Find all header files in interface include folders for reference
    set(interface_headers)
    foreach(include_folder ${ARGUMENT_INTERFACE_INCLUDE_FOLDERS})
        file(GLOB_RECURSE headers "${include_folder}/*.h" "${include_folder}/*.hpp")
        list(APPEND interface_headers ${headers})
    endforeach()

    message(STATUS "Interface headers for ${target_project}: ${interface_headers}")
    message(STATUS "Interface folders for ${target_project}: ${ARGUMENT_INTERFACE_INCLUDE_FOLDERS}")
    
    # Remove duplicates
    if(interface_headers)
        list(REMOVE_DUPLICATES interface_headers)
    endif()
endfunction()