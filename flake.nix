{
  description = "Cross-compile the fen coding-agent CLI for BlackBerry 10 / QNX (armle-v7) with the bbnix GCC toolchain";

  # fen is pinned as a flake input; nixpkgs *follows* fen's own pin so every
  # materialized dependency source is byte-identical to what fen's own Nix
  # build consumes. We never reimplement nixpkgs version pinning.
  #
  # bbnix supplies the cross toolchain (modern GCC 9 + binutils, prefix
  # arm-unknown-nto-qnx8.0.0eabi-*). Its GCC reads BBNIX_SYSROOT at eval time
  # and throws if unset, so anything touching `.#cross` needs `--impure` with
  # BBNIX_SYSROOT pointed at a bbndk-linux tree. bbnix keeps its OWN nixpkgs
  # pin (its GCC build is tuned to it) — we do not make it follow ours.
  inputs = {
    fen.url = "github:acmiyaguchi/fen/98c3bfcfc6b7239aa43dac808c16159da0b5c02c";
    nixpkgs.follows = "fen/nixpkgs";
    flake-utils.follows = "fen/flake-utils";
    bbnix.url = "github:acmiyaguchi/bbnix/dc54f8631979688833fce53950aa83ddf7ce49d4";
  };

  outputs = { self, fen, nixpkgs, flake-utils, bbnix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        bb = bbnix.packages.${system};
      in {
        # Pure, reproducible: collect the exact dependency source/dist trees.
        # The cross-compile itself runs OUTSIDE Nix (see Makefile), driven by
        # the bbnix toolchain in the `.#cross` devShell.
        packages.deps = import ./nix/deps.nix { inherit pkgs; fenSrc = fen; };
        packages.default = self.packages.${system}.deps;

        # Host tools for the arch-independent Lua payload stage (Stage 3).
        # Pure — never references bbnix, so `nix develop` works without a sysroot.
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.lua54Packages.fennel
            pkgs.lua5_4
            pkgs.zip
            pkgs.unzip
            pkgs.patch
            pkgs.git
            pkgs.gnumake
            pkgs.coreutils
          ];
        };

        # Cross toolchain for the qcc-replacement stages (1/2/4). Pulls bbnix's
        # GCC/binutils, so it requires `--impure` + BBNIX_SYSROOT (bbnix throws
        # otherwise). The compiler bakes --with-sysroot, so device headers/libs
        # resolve automatically; cross-build.sh just calls the prefixed tools.
        #
        # We also bring in bbnix's from-source curl (static libcurl.a over its
        # OpenSSL 3.x + zlib) so stage4 links curl/TLS partial-static instead of
        # against the device's EOL libcurl.so.2 / OpenSSL 1.0.x. cross-build.sh
        # reads these store paths for the curl headers (stage2) and the static
        # archives (stage4).
        devShells.cross = pkgs.mkShell {
          packages = [
            bb.gcc
            bb.binutils
            pkgs.gnumake
            pkgs.coreutils
            pkgs.file
          ];
          shellHook = ''
            export CC="arm-unknown-nto-qnx8.0.0eabi-gcc"
            export AR="arm-unknown-nto-qnx8.0.0eabi-ar"
            export RANLIB="arm-unknown-nto-qnx8.0.0eabi-ranlib"
            export BBNIX_CURL="${bb.curl}"
            export BBNIX_OPENSSL="${bb.openssl}"
            export BBNIX_ZLIB="${bb.zlib}"
          '';
        };
      });
}
