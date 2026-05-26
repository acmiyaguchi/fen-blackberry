# Pure source-materialization derivation.
#
# Collects, into one out path, the exact dependency trees fen's own
# nix/artifacts.nix consumes — taken from the *followed* nixpkgs, so versions
# match fen's flake.lock with zero hand-pinning:
#
#   lua/       <- lua5_4 source            (Stage 1: build liblua.a, bbnix gcc)
#   cjson/     <- lua-cjson source         (Stage 2: lua_cjson/strbuf/fpconv.c)
#   lfs/       <- luafilesystem source     (Stage 2: src/lfs.c)
#   kubazip/   <- kubazip source           (Stage 4: src/zip.c, <zip/zip.h>)
#   fennel.lua <- lua54Packages.fennel     (Stage 3: embedded fennel compiler)
#   dkjson/    <- dkjson share/lua/5.4/.   (Stage 3: required Lua payload)
#   luarocks/  <- luarocks share/lua/5.4   (Stage 3: rocks.prepend-tree! at startup)
#   fen-src/   <- the fen flake input      (Stages 2-4: C sources + .fnl tree)
#   VERSIONS   <- provenance for assertion
{ pkgs, fenSrc }:

let
  lp = pkgs.lua54Packages;
  # srcOnly runs each package's own unpackPhase, so this is robust whether the
  # upstream src is a tarball (lua) or a fetched git tree (kubazip/cjson/lfs).
  src = drv: pkgs.srcOnly drv;
  v = drv: drv.version or "unknown";
in
pkgs.runCommand "fen-bb-deps"
{
  passthru.versions = {
    lua5_4 = v pkgs.lua5_4;
    lua-cjson = v lp.lua-cjson;
    luafilesystem = v lp.luafilesystem;
    kubazip = v pkgs.kubazip;
    fennel = v lp.fennel;
    dkjson = v lp.dkjson;
    luarocks = v lp.luarocks;
  };
} ''
  set -eu
  mkdir -p "$out"

  cp -R --no-preserve=mode,ownership ${src pkgs.lua5_4}/        "$out/lua"
  cp -R --no-preserve=mode,ownership ${src lp.lua-cjson}/       "$out/cjson"
  cp -R --no-preserve=mode,ownership ${src lp.luafilesystem}/   "$out/lfs"
  cp -R --no-preserve=mode,ownership ${src pkgs.kubazip}/       "$out/kubazip"

  # Arch-independent Lua payload pieces (already-built, copied verbatim the
  # same way fen's luaTree/fenBinary stages do).
  install -Dm644 ${lp.fennel}/share/lua/5.4/fennel.lua "$out/fennel.lua"
  mkdir -p "$out/dkjson"
  cp -R --no-preserve=mode,ownership ${lp.dkjson}/share/lua/5.4/. "$out/dkjson/"
  cp -R --no-preserve=mode,ownership ${lp.luarocks}/share/lua/5.4/luarocks "$out/luarocks"

  # Read-only fen source (C files + scripts/fennel-build.fnl + .fnl tree).
  cp -R --no-preserve=mode,ownership ${fenSrc}/ "$out/fen-src"

  cat > "$out/VERSIONS" <<EOF
lua5_4=${v pkgs.lua5_4}
lua-cjson=${v lp.lua-cjson}
luafilesystem=${v lp.luafilesystem}
kubazip=${v pkgs.kubazip}
fennel=${v lp.fennel}
dkjson=${v lp.dkjson}
luarocks=${v lp.luarocks}
fen-rev=${fenSrc.rev or fenSrc.dirtyRev or "unknown"}
EOF
''
