# The binaries -- CMake twin of the AMBuild scripts that add them:
# third_party/khook/third_party/safetyhook/AMBuilder, third_party/khook/AMBuilder,
# support/buildbot/Versioning + versionlib/AMBuildScript, loader/AMBuilder and
# core/AMBuilder, with MMSConfig.Library() / HL2Library() of AMBuildScript.
# Same sources in the same order; what an AMBuilder adds after the shared
# settings goes into a <target>_ambuilder interface library linked after them,
# so it lands after them on the command line as well.
# Included by CMakeLists.txt after shared.cmake, the platform file and s2sdk_manifest().

set(KHOOK_DIR ${CMAKE_SOURCE_DIR}/third_party/khook)
set(SAFETYHOOK_DIR ${KHOOK_DIR}/third_party/safetyhook)

# safetyhook: its own flags only (its AMBuilder resets the compiler's).
add_library(safetyhook STATIC
    ${SAFETYHOOK_DIR}/src/allocator.cpp
    ${SAFETYHOOK_DIR}/src/easy.cpp
    ${SAFETYHOOK_DIR}/src/inline_hook.cpp
    ${SAFETYHOOK_DIR}/src/mid_hook.cpp
    ${SAFETYHOOK_DIR}/src/utility.cpp
    ${SAFETYHOOK_DIR}/src/vmt_hook.cpp
    ${SAFETYHOOK_DIR}/zydis/Zydis.c
)
if(WIN32)
    target_compile_options(safetyhook PRIVATE /W4 $<$<COMPILE_LANGUAGE:CXX>:/EHsc /permissive- /w14640 /std:c++17> /Zi)
    target_sources(safetyhook PRIVATE ${SAFETYHOOK_DIR}/src/os.windows.cpp)
else()
    target_compile_options(safetyhook PRIVATE
        -Werror -Wall -Wextra -pedantic -Wshadow -Wno-unused-const-variable -Wno-unused-function -fPIC -g3
        $<$<COMPILE_LANGUAGE:CXX>:-Wnon-virtual-dtor -Wno-format -std=c++17>
    )
    target_sources(safetyhook PRIVATE ${SAFETYHOOK_DIR}/src/os.linux.cpp)
endif()
target_include_directories(safetyhook PRIVATE ${SAFETYHOOK_DIR}/include ${SAFETYHOOK_DIR}/zydis)

# khook: the shared settings, plus its own.
add_library(khook STATIC
    ${KHOOK_DIR}/src/detour.cpp
    ${KHOOK_DIR}/src/ranges.cpp
)
add_library(khook_ambuilder INTERFACE)
target_compile_definitions(khook_ambuilder INTERFACE KHOOK_STANDALONE KHOOK_EXPORT)
target_include_directories(khook_ambuilder INTERFACE ${KHOOK_DIR}/include ${SAFETYHOOK_DIR}/include)
target_link_libraries(khook PRIVATE mms_cxx khook_ambuilder)

# The version header and library (MMS_AUTO_VERSIONING, AMBuild's auto-versioning).
if(MMS_AUTO_VERSIONING)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    execute_process(
        COMMAND git rev-parse --absolute-git-dir
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE MMS_GIT_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULTS_VARIABLE git_result
    )
    if(NOT git_result EQUAL 0)
        message(FATAL_ERROR "Auto-versioning needs a git checkout; or -DMMS_AUTO_VERSIONING=OFF")
    endif()
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/includes)
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/includes/metamod_version_auto.h
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/support/buildbot/generate_headers.py
                ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR}/includes
        # Like the AMBuild script: regenerated when product.version, the script or the git HEAD changes
        DEPENDS ${CMAKE_SOURCE_DIR}/product.version
                ${CMAKE_SOURCE_DIR}/support/buildbot/generate_headers.py
                ${MMS_GIT_DIR}/HEAD
        COMMENT "Generating metamod_version_auto.h"
        VERBATIM
    )
    add_custom_target(mms_version_header DEPENDS ${CMAKE_BINARY_DIR}/includes/metamod_version_auto.h)

    add_library(version STATIC ${CMAKE_SOURCE_DIR}/versionlib/versionlib.cpp)
    # Without MMS_USE_VERSIONLIB, which versionlib/AMBuildScript removes
    set_target_properties(version PROPERTIES MMS_NO_VERSIONLIB ON)
    target_link_libraries(version PRIVATE mms_cxx)
    add_dependencies(version mms_version_header)
endif()

# MMSConfig.Library(): a shared library with the shared settings, versioning and
# amtl's stdcxx.cpp.
function(mms_library target output_name source_dir)
    add_library(${target} SHARED)
    # No SONAME and no <target>_EXPORTS define, as with AMBuild
    set_target_properties(${target} PROPERTIES PREFIX "" OUTPUT_NAME ${output_name} NO_SONAME ON DEFINE_SYMBOL "")
    target_link_libraries(${target} PRIVATE mms_cxx)

    # MMSConfig.AddVersioning()
    if(WIN32)
        target_sources(${target} PRIVATE ${source_dir}/version.rc)
        set_source_files_properties(${source_dir}/version.rc TARGET_DIRECTORY ${target} PROPERTIES
            COMPILE_DEFINITIONS "BINARY_NAME=\"${output_name}.dll\";RC_COMPILE")
    endif()
    if(MMS_AUTO_VERSIONING)
        target_link_libraries(${target} PRIVATE version)
        add_dependencies(${target} mms_version_header)
    endif()

    if(NOT MSVC)
        target_sources(${target} PRIVATE ${CMAKE_SOURCE_DIR}/third_party/amtl/compat/stdcxx.cpp)
    endif()

    add_library(${target}_ambuilder INTERFACE)
endfunction()

# loader/AMBuilder
function(mms_loader target lib_prefix lib_suffix)
    mms_library(${target} ${target} ${CMAKE_SOURCE_DIR}/loader)
    target_sources(${target} PRIVATE
        ${CMAKE_SOURCE_DIR}/loader/loader.cpp
        ${CMAKE_SOURCE_DIR}/loader/gamedll.cpp
        ${CMAKE_SOURCE_DIR}/loader/serverplugin.cpp
        ${CMAKE_SOURCE_DIR}/loader/utility.cpp
    )
    target_include_directories(${target}_ambuilder INTERFACE ${KHOOK_DIR}/include)
    if(NOT WIN32)
        target_compile_definitions(${target}_ambuilder INTERFACE "LIB_PREFIX=\"${lib_prefix}\"" "LIB_SUFFIX=\"${lib_suffix}\"")
    endif()
    target_link_libraries(${target} PRIVATE ${target}_ambuilder)
endfunction()

if(WIN32)
    mms_loader(server "" "")
else()
    mms_loader(libserver "lib" ".so")
    mms_loader(server "" ".so")
endif()

# core/AMBuilder: metamod.2.<sdk>, MMSConfig.HL2Library()
set(MMS_CORE metamod.2.${MMS_SDK})
mms_library(core ${MMS_CORE} ${CMAKE_SOURCE_DIR}/core)
mms_configure_binary(core ${CMAKE_SOURCE_DIR}/core)
target_include_directories(core_ambuilder INTERFACE ${KHOOK_DIR}/include)
target_compile_definitions(core_ambuilder INTERFACE KHOOK_STANDALONE KHOOK_EXPORT)
target_sources(core PRIVATE
    ${CMAKE_SOURCE_DIR}/core/metamod.cpp
    ${CMAKE_SOURCE_DIR}/core/metamod_console.cpp
    ${CMAKE_SOURCE_DIR}/core/metamod_oslink.cpp
    ${CMAKE_SOURCE_DIR}/core/metamod_plugins.cpp
    ${CMAKE_SOURCE_DIR}/core/metamod_util.cpp
    ${CMAKE_SOURCE_DIR}/core/provider/provider_base.cpp
    ${CMAKE_SOURCE_DIR}/core/gamedll_bridge.cpp
    ${CMAKE_SOURCE_DIR}/core/provider/source2/provider_source2.cpp
)
target_link_libraries(core PRIVATE khook safetyhook s2sdk::s2sdk core_ambuilder)
s2sdk_protobufs(core
    common/network_connection.proto
)
