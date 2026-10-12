# Metamod:Source for one Source 2 SDK (cs2 by default; -DMMS_SDK=dota or deadlock),
# for local builds and IDEs. The CMake twin of the AMBuild build (AMBuildScript),
# which stays the one to release with: it also builds the Source 1 SDKs (from
# hl2sdk-manifests), several SDKs at once, 32-bit and macOS, and Breakpad symbols.
#
# The SDK comes from s2sdk-manifests (s2sdk-manifests.cmake), its folder from
# the first of the manifest's env_vars that is set (S2SDK_CS2, S2SDKCS2, S2SDK,
# HL2SDK_CS2, HL2SDKCS2 for cs2), or -DMMS_SDK_DIR=...
#
#   cmake -S . -B cmake-build-relwithdebinfo-wsl -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
#   cmake --build cmake-build-relwithdebinfo-wsl
cmake_minimum_required(VERSION 3.19) # string(JSON), s2sdk-manifests
project(metamod C CXX)

set(MMS_SDK cs2 CACHE STRING "The Source 2 SDK to build for (cs2, dota, deadlock)")
option(MMS_AUTO_VERSIONING "Version the binaries from git (AMBuild: unless --disable-auto-versioning)" ON)

if(NOT EXISTS "${CMAKE_SOURCE_DIR}/s2sdk-manifests/s2sdk-manifests.cmake")
    message(FATAL_ERROR "s2sdk-manifests is missing: git submodule update --init --recursive")
endif()
include(${CMAKE_SOURCE_DIR}/s2sdk-manifests/s2sdk-manifests.cmake)

# The SDK's folder: MMS_SDK_DIR, else the manifest's env_vars, first set wins.
if(NOT MMS_SDK_DIR)
    file(READ "${CMAKE_SOURCE_DIR}/s2sdk-manifests/manifests/${MMS_SDK}.json" manifest)
    string(JSON count LENGTH "${manifest}" env_vars)
    math(EXPR last "${count} - 1")
    foreach(i RANGE ${last})
        string(JSON var GET "${manifest}" env_vars ${i})
        if(DEFINED ENV{${var}} AND NOT "$ENV{${var}}" STREQUAL "")
            set(MMS_SDK_DIR "$ENV{${var}}")
            break()
        endif()
    endforeach()
endif()
if(NOT MMS_SDK_DIR)
    message(FATAL_ERROR "s2sdk for ${MMS_SDK} not found: set S2SDK (or HL2SDKCS2, ...) or -DMMS_SDK_DIR")
endif()
file(TO_CMAKE_PATH "${MMS_SDK_DIR}" MMS_SDK_DIR)

# Compiler flags, then the platform's (shared.ambuild / linux.ambuild / windows.ambuild).
include(${CMAKE_SOURCE_DIR}/makefiles/cmake/shared.cmake)
if(WIN32)
    include(${CMAKE_SOURCE_DIR}/makefiles/cmake/windows.cmake)
else()
    include(${CMAKE_SOURCE_DIR}/makefiles/cmake/linux.cmake)
endif()
mms_configure_cxx()

# s2sdk::s2sdk (SdkHelpers.configureCxx on the AMBuild side)
s2sdk_manifest(${MMS_SDK} "${MMS_SDK_DIR}")
# Metamod picks its C++ standard itself (-std=c++17 / /std:c++17 in shared.cmake),
# so the SDK's (C++20) is not added; shared.ambuild only adds it when a project
# has none.
set_property(TARGET s2sdk_headers PROPERTY INTERFACE_COMPILE_FEATURES "")

# khook, safetyhook, versionlib, the loader and metamod.2.<sdk> (core/AMBuilder,
# loader/AMBuilder, the khook/safetyhook AMBuilders on the AMBuild side).
include(${CMAKE_SOURCE_DIR}/makefiles/cmake/CMakeBuilder.cmake)

# The package/ layout (makefiles/ambuild/package.ambuild on the AMBuild side).
include(${CMAKE_SOURCE_DIR}/makefiles/cmake/package.cmake)
