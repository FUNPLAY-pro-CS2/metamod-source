# The package layout -- CMake twin of makefiles/ambuild/package.ambuild, for the
# x86_64 Source 2 build: <build>/package/addons/ with the .vdf files, and the
# binaries in addons/metamod/bin/linuxsteamrt64 (linux64 for the Source 1
# loader server.so) or addons/metamod/bin/win64. Built with the default target.

set(MMS_PACKAGE ${CMAKE_BINARY_DIR}/package)
set(MMS_ADDONS ${MMS_PACKAGE}/addons)
if(WIN32)
    set(MMS_BIN64 ${MMS_ADDONS}/metamod/bin/win64)
    set(MMS_BIN64_S2 ${MMS_BIN64})
    set(MMS_X64_VDF metamod_win64.vdf)
    set(MMS_S2_BINARIES server core)
    set(MMS_S1_BINARIES)
else()
    set(MMS_BIN64 ${MMS_ADDONS}/metamod/bin/linux64)
    set(MMS_BIN64_S2 ${MMS_ADDONS}/metamod/bin/linuxsteamrt64)
    set(MMS_X64_VDF metamod_linux64.vdf)
    # libserver goes with the Source 2 binaries, as in package.ambuild
    set(MMS_S2_BINARIES libserver core)
    set(MMS_S1_BINARIES server)
endif()

set(commands
    COMMAND ${CMAKE_COMMAND} -E make_directory ${MMS_ADDONS}/metamod/bin ${MMS_BIN64} ${MMS_BIN64_S2}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_SOURCE_DIR}/support/${MMS_X64_VDF} ${MMS_ADDONS}/metamod_x64.vdf
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_SOURCE_DIR}/support/metamod.vdf ${MMS_ADDONS}/
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_SOURCE_DIR}/support/metaplugins.ini ${MMS_ADDONS}/metamod/
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_SOURCE_DIR}/support/README.txt ${MMS_ADDONS}/metamod/
)
foreach(binary ${MMS_S2_BINARIES})
    list(APPEND commands COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${binary}> ${MMS_BIN64_S2}/)
endforeach()
foreach(binary ${MMS_S1_BINARIES})
    list(APPEND commands COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${binary}> ${MMS_BIN64}/)
endforeach()

add_custom_target(mms_package ALL ${commands}
    DEPENDS ${MMS_S2_BINARIES} ${MMS_S1_BINARIES}
    COMMENT "Packaging into ${MMS_PACKAGE}"
    VERBATIM
)
