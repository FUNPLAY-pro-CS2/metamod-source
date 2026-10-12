# Settings every platform shares -- CMake twin of makefiles/ambuild/shared.ambuild.
# The per-platform ones are in linux.cmake / windows.cmake.
#
# The CMake build is for the Source 2 SDKs only (Linux / Windows, x86_64); what
# shared.ambuild only does for Source 1 or other targets is left out here.
# AMBuild's options map to the configurations: --enable-optimize to Release and
# RelWithDebInfo, --enable-debug to Debug. AMBuild always builds with debug info
# (-g3 / /Zi), so every configuration does here too.

if(WIN32 AND NOT MSVC)
    message(FATAL_ERROR "On Windows, only MSVC is supported (as with AMBuild)")
endif()

# The flags come from mms_cxx below only, not CMake's per-configuration defaults.
foreach(lang C CXX)
    set(CMAKE_${lang}_FLAGS "")
    foreach(config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
        set(CMAKE_${lang}_FLAGS_${config} "")
    endforeach()
endforeach()
foreach(kind SHARED STATIC)
    foreach(config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
        set(CMAKE_${kind}_LINKER_FLAGS_${config} "")
    endforeach()
endforeach()
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
# Like AMBuild: no RPATH to the SDK's lib folder in the binaries.
set(CMAKE_SKIP_BUILD_RPATH ON)

set(MMS_OPTIMIZE "$<CONFIG:Release,RelWithDebInfo,MinSizeRel>")
set(MMS_DEBUG "$<CONFIG:Debug>")

# What every binary is compiled with: mms_configure_compiler(), the platform's
# mms_configure_platform(), then mms_configure_cxx() -- in that order, like
# MMSConfig.configure_cxx() runs shared.ambuild's ConfigureCompiler(), the
# platform file and shared.ambuild's ConfigureCxx().
add_library(mms_cxx INTERFACE)

# shared.ambuild's ConfigureCompiler(): the compiler's flags, by its family,
# with the optimization and debugging flags after them.
function(mms_configure_compiler)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
        target_compile_definitions(mms_cxx INTERFACE
            stricmp=strcasecmp
            _stricmp=strcasecmp
            _snprintf=snprintf
            _vsnprintf=vsnprintf
            HAVE_STDINT_H
            GNUC
        )
        set(cflags
            -pipe
            -fno-strict-aliasing
            -Wall
            -Werror
            -Wno-uninitialized
            -Wno-sign-compare
            -Wno-unused
            -Wno-switch
            -Wno-unknown-pragmas
            -Wno-dangling-else
            -msse
            -fPIC
        )
        set(cxxflags -std=c++17)
        list(APPEND cflags -fvisibility=hidden)
        list(APPEND cxxflags -fvisibility-inlines-hidden)
        list(APPEND cxxflags
            -fno-exceptions
            -Wno-non-virtual-dtor
            -Wno-overloaded-virtual
            -Wno-register
        )
        list(APPEND cxxflags -Wno-delete-non-virtual-dtor)
        if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            list(APPEND cflags
                -mfpmath=sse
                -Wno-class-memaccess
            )
        endif()
        if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            list(APPEND cxxflags -Wno-implicit-exception-spec-mismatch)
            list(APPEND cxxflags -Wno-expansion-to-defined)
            list(APPEND cxxflags -Wno-inconsistent-missing-override)
            list(APPEND cxxflags -Wno-deprecated-register)

            # Work around SDK warnings.
            if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 10.0)
                list(APPEND cflags
                    -Wno-implicit-int-float-conversion
                    -Wno-tautological-overlap-compare
                )
            endif()
            if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 13.0)
                list(APPEND cflags
                    -Wno-ordered-compare-function-pointers
                )
            endif()
        endif()

        # Optimization
        target_compile_definitions(mms_cxx INTERFACE $<${MMS_OPTIMIZE}:NDEBUG>)
        list(APPEND cflags $<${MMS_OPTIMIZE}:-O3>)

        # Debugging
        target_compile_definitions(mms_cxx INTERFACE $<${MMS_DEBUG}:DEBUG> $<${MMS_DEBUG}:_DEBUG>)
        list(APPEND cflags $<${MMS_DEBUG}:-g3>)

        # Don't omit the frame pointer.
        # This needs to be after our optimization flags which could otherwise disable it.
        list(APPEND cflags -fno-omit-frame-pointer)

        # The debug info AMBuild adds after the project's cflags
        list(APPEND cflags -g3)

        # AMBuild's command line has every cflag before the cxxflags.
        target_compile_options(mms_cxx INTERFACE ${cflags} $<$<COMPILE_LANGUAGE:CXX>:${cxxflags}>)

    elseif(MSVC)
        # /MT or /MTd: CMAKE_MSVC_RUNTIME_LIBRARY above
        target_link_options(mms_cxx INTERFACE $<${MMS_DEBUG}:/NODEFAULTLIB:libcmt>)
        target_compile_definitions(mms_cxx INTERFACE
            _CRT_SECURE_NO_DEPRECATE
            _CRT_SECURE_NO_WARNINGS
            _CRT_NONSTDC_NO_DEPRECATE
        )
        set(cflags
            /W3
            /Zi
            /EHsc
            /std:c++17
        )
        set(cxxflags /TP)

        target_link_options(mms_cxx INTERFACE /SUBSYSTEM:WINDOWS)
        target_link_libraries(mms_cxx INTERFACE
            kernel32.lib
            user32.lib
            gdi32.lib
            winspool.lib
            comdlg32.lib
            advapi32.lib
            shell32.lib
            ole32.lib
            oleaut32.lib
            uuid.lib
            odbc32.lib
            odbccp32.lib
        )

        # Optimization
        target_compile_definitions(mms_cxx INTERFACE $<${MMS_OPTIMIZE}:NDEBUG>)
        list(APPEND cflags $<${MMS_OPTIMIZE}:/Ox> $<${MMS_OPTIMIZE}:/Zo>)
        target_link_options(mms_cxx INTERFACE $<${MMS_OPTIMIZE}:/OPT:ICF> $<${MMS_OPTIMIZE}:/OPT:REF>)

        # Debugging
        target_compile_definitions(mms_cxx INTERFACE $<${MMS_DEBUG}:DEBUG> $<${MMS_DEBUG}:_DEBUG>)
        list(APPEND cflags $<${MMS_DEBUG}:/Od> $<${MMS_DEBUG}:/RTC1>)
        # The PDBs, which AMBuild writes for /Zi
        target_link_options(mms_cxx INTERFACE /DEBUG)

        # Don't omit the frame pointer.
        list(APPEND cflags /Oy-)

        target_compile_options(mms_cxx INTERFACE ${cflags} $<$<COMPILE_LANGUAGE:CXX>:${cxxflags}>)
    endif()
endfunction()

# shared.ambuild's ConfigureCxx(): every compiler, after the platform file.
function(mms_configure_cxx)
    # Not for a target with MMS_NO_VERSIONLIB set (the version library)
    target_compile_definitions(mms_cxx INTERFACE $<$<NOT:$<BOOL:$<TARGET_PROPERTY:MMS_NO_VERSIONLIB>>>:MMS_USE_VERSIONLIB>)
    target_include_directories(mms_cxx INTERFACE
        ${CMAKE_SOURCE_DIR}/public
        ${CMAKE_SOURCE_DIR}/third_party/amtl
    )
    if(MMS_AUTO_VERSIONING)
        target_compile_definitions(mms_cxx INTERFACE MMS_GENERATED_BUILD)
        target_include_directories(mms_cxx INTERFACE
            ${CMAKE_BINARY_DIR}/includes
            ${CMAKE_SOURCE_DIR}/versionlib
        )
    endif()
endfunction()

# SE_<define>=<code> for every SDK of hl2sdk-manifests and s2sdk-manifests, a
# game in both once and with the same values in each (as in MMSConfig.detectSDKs();
# sorted here, where AMBuild keeps the manifests' folder order, which can't matter).
function(mms_sdk_engine_defines out)
    file(GLOB manifests
        ${CMAKE_SOURCE_DIR}/hl2sdk-manifests/manifests/*.json
        ${CMAKE_SOURCE_DIR}/s2sdk-manifests/manifests/*.json
    )
    set(names)
    foreach(manifest ${manifests})
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${manifest}")
        file(READ "${manifest}" json)
        string(JSON name GET "${json}" name)
        string(JSON define GET "${json}" define)
        string(JSON code GET "${json}" code)
        if(DEFINED se_${name} AND NOT "${se_${name}}" STREQUAL "SE_${define}=${code}")
            message(FATAL_ERROR "${name}: ${se_${name}} in one manifest, SE_${define}=${code} in the other")
        endif()
        set(se_${name} "SE_${define}=${code}")
        list(APPEND names ${name})
    endforeach()
    list(REMOVE_DUPLICATES names)
    list(SORT names)
    set(defines)
    foreach(name ${names})
        list(APPEND defines ${se_${name}})
    endforeach()
    set(${out} ${defines} PARENT_SCOPE)
endfunction()

# shared.ambuild's ConfigureBinary(): a metamod.2.<sdk> binary, before the SDK's
# include paths, defines and libraries (s2sdk::s2sdk).
# The same list, in the same order, as shared.ambuild's.
set(MMS_SDK_SOURCES
    ${MMS_SDK_DIR}/public/tier0/memoverride.cpp
    ${MMS_SDK_DIR}/tier0_perproject/convar.cpp
)
function(mms_configure_binary target source_dir)
    mms_sdk_engine_defines(se_defines)
    add_library(${target}_hl2library INTERFACE)
    target_include_directories(${target}_hl2library INTERFACE
        ${source_dir}
        ${CMAKE_SOURCE_DIR}/loader
    )
    target_compile_definitions(${target}_hl2library INTERFACE ${se_defines} META_IS_SOURCE2)
    target_sources(${target} PRIVATE ${MMS_SDK_SOURCES})
    target_link_libraries(${target} PRIVATE ${target}_hl2library)
endfunction()

mms_configure_compiler()
