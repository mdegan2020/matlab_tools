add_library(sightline_warnings INTERFACE)

if(MSVC)
    target_compile_options(sightline_warnings INTERFACE
        /W4 /permissive- /Zc:__cplusplus)
    if(SIGHTLINE_WARNINGS_AS_ERRORS)
        target_compile_options(sightline_warnings INTERFACE /WX)
    endif()
else()
    target_compile_options(sightline_warnings INTERFACE
        -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion)
    if(SIGHTLINE_WARNINGS_AS_ERRORS)
        target_compile_options(sightline_warnings INTERFACE -Werror)
    endif()
endif()

function(sightline_enable_sanitizers target_name)
    if(NOT SIGHTLINE_ENABLE_SANITIZERS OR MSVC)
        return()
    endif()
    target_compile_options(${target_name} PRIVATE
        -fsanitize=address,undefined -fno-omit-frame-pointer)
    target_link_options(${target_name} PRIVATE
        -fsanitize=address,undefined -fno-omit-frame-pointer)
endfunction()
