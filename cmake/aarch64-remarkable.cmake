# CMake toolchain for the reMarkable Paper Pro family (aarch64), using the
# cross compiler from the SDK's dev shell:
#   cmake -B build -DCMAKE_TOOLCHAIN_FILE=$RM_TOOLCHAIN_FILE

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-unknown-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-unknown-linux-gnu-g++)

# Binaries run on the device's glibc, so they must use its dynamic linker
# rather than the Nix store one. libstdc++ is linked statically so binaries
# don't depend on the device's GCC version.
set(CMAKE_EXE_LINKER_FLAGS_INIT "-Wl,--dynamic-linker=/lib/ld-linux-aarch64.so.1 -static-libstdc++ -static-libgcc")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
