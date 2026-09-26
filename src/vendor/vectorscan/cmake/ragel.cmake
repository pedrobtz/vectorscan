# function for doing all the dirty work in turning a .rl into C++
#
# R package patch: when ragel is not installed, copy the pre-generated
# ${src_file}.rl.cpp that sits next to the .rl instead of running ragel.

function(ragelmaker src_rl)
    get_filename_component(src_dir ${src_rl} PATH) # old cmake needs PATH
    get_filename_component(src_file ${src_rl} NAME_WE)
    set(rl_out ${CMAKE_CURRENT_BINARY_DIR}/${src_dir}/${src_file}.cpp)
    set(rl_pregen ${CMAKE_CURRENT_SOURCE_DIR}/${src_dir}/${src_file}.rl.cpp)
    if (RAGEL)
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${src_dir}/${src_file}.cpp
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/${src_dir}
            COMMAND ${RAGEL} ${CMAKE_CURRENT_SOURCE_DIR}/${src_rl} -o ${rl_out} -G0
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${src_rl}
            )
    else ()
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${src_dir}/${src_file}.cpp
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/${src_dir}
            COMMAND ${CMAKE_COMMAND} -E copy ${rl_pregen} ${rl_out}
            DEPENDS ${rl_pregen}
            )
    endif ()
    add_custom_target(ragel_${src_file} DEPENDS ${rl_out})
    set_source_files_properties(${rl_out} PROPERTIES GENERATED TRUE)
endfunction(ragelmaker)
