# Tunables for the fen-blackberry cross build.
#
# The toolchain comes from bbnix (modern GCC 9, prefix
# arm-unknown-nto-qnx8.0.0eabi-*), supplied by the `.#cross` devShell which
# exports CC/AR/RANLIB. bbnix's GCC bakes --with-sysroot, so device
# headers/libs resolve automatically — set BBNIX_SYSROOT to your bbndk-linux
# tree before running stages 1/2/4 (they build `--impure`).
#
# The version stamp (gen-version-lua.sh) reads fen's revision from the
# materialized deps (build/deps/VERSIONS); no local fen checkout is required.
