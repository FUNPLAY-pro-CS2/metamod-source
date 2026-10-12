# Windows settings -- CMake twin of makefiles/ambuild/windows.ambuild.
# Included after shared.cmake's mms_configure_compiler().

target_compile_definitions(mms_cxx INTERFACE WIN32 _WINDOWS)
