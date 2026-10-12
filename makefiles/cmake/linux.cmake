# Linux settings -- CMake twin of makefiles/ambuild/linux.ambuild.
# Included after shared.cmake's mms_configure_compiler().

target_compile_definitions(mms_cxx INTERFACE LINUX _LINUX POSIX _FILE_OFFSET_BITS=64)
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    target_link_options(mms_cxx INTERFACE -static-libgcc)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # A library, so it goes after the objects, where AMBuild puts it
    target_link_libraries(mms_cxx INTERFACE -lgcc_eh)
endif()
target_link_options(mms_cxx INTERFACE -static-libstdc++)
target_link_options(mms_cxx INTERFACE -Wl,--exclude-libs,ALL)
