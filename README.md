Metamod:Source
==============

Metamod:Source - A C++ Plugin Environment and Detour Library for the Source Engine.

Build instructions
------------------

Make sure ambuild2 is installed: https://github.com/alliedmodders/ambuild

Clone the repo with submodules:
```
git clone --recurse-submodules https://github.com/alliedmodders/metamod-source
```

Clone the SDK dependencies:
```
cd ..
metamod-source/support/checkout-deps.sh
cd metamod-source
```

Configure the build:
```
mkdir build
cd build
python ../configure.py
```

Build:
```
ambuild
```

You can clone an individual SDK e.g.:
```
cd ..
metamod-source/support/checkout-deps.sh -s episode1
cd metamod-source
```

You can configure the build for an individual SDK e.g.:
```
mkdir build
cd build
python ../configure.py --sdks episode1
```

The Source 1 SDKs are described by the `hl2sdk-manifests` submodule, the Source 2 ones (cs2, dota,
deadlock) by `s2sdk-manifests` and come from [s2sdk](https://github.com/Source2Mod/s2sdk)
(`--hl2sdk-manifests` / `--s2sdk-manifests` point elsewhere). An s2sdk checkout is also found through
`S2SDK` (cs2), `S2SDK_DOTA`, `HL2SDKCS2`, ... as listed in its manifest.

The build settings are in `makefiles/ambuild/`. For one Source 2 SDK there is a CMake build too, with the
same settings in `makefiles/cmake/`, e.g. for an IDE:
```
cmake -S . -B cmake-build-relwithdebinfo -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMMS_SDK=cs2
cmake --build cmake-build-relwithdebinfo
```

Stable build snapshots: <http://www.metamodsource.net/downloads.php/?branch=stable>

Development build snapshots: <http://www.metamodsource.net/downloads.php/?branch=master>

General documentation: <https://wiki.alliedmods.net/Category:Metamod:Source_Documentation>

Detouring with SourceHook: <https://wiki.alliedmods.net/SourceHook_Development>

Development: <https://wiki.alliedmods.net/Category:Metamod:Source_Development>