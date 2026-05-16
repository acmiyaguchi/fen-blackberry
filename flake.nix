{
  description = "Cross-compile the fen coding-agent CLI for BlackBerry 10 / QNX 6.6 (armle-v7)";

  # fen is pinned as a flake input; nixpkgs *follows* fen's own pin so every
  # materialized dependency source is byte-identical to what fen's own Nix
  # build consumes. We never reimplement nixpkgs version pinning.
  inputs = {
    fen.url = "git+file:///mnt/data/fun/blackberry/fen";
    nixpkgs.follows = "fen/nixpkgs";
    flake-utils.follows = "fen/flake-utils";
  };

  outputs = { self, fen, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        # Pure, reproducible: collect the exact dependency source/dist trees.
        # The qcc cross-compile itself runs OUTSIDE Nix (see Makefile) because
        # the BBNDK toolchain lives in the parent flake's FHS env.
        packages.deps = import ./nix/deps.nix { inherit pkgs; fenSrc = fen; };
        packages.default = self.packages.${system}.deps;

        # Host tools for the arch-independent Lua payload stage (Stage 3).
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
      });
}
