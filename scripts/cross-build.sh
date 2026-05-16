#!/usr/bin/env bash
# The 4-stage fen cross build, 1:1 with fen's nix/artifacts.nix but using the
# BBNDK qcc toolchain and partial-static linking.
#
#   stage1/2/4 : run inside the parent BBNDK FHS shell (QNX_HOST/QNX_TARGET set)
#   stage3     : run in this repo's devShell (host fennel; arch-independent)
#
# Split rationale: the deterministic Lua-payload ZIP is arch-independent and
# needs `zip` (present in devShell, NOT in the BBNDK FHS), so it is built in
# stage3. stage4 only cross-links and appends the prebuilt ZIP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/build/deps"
LUA="$ROOT/build/lua-install"
OBJ="$ROOT/build/obj"
WORK="$ROOT/build/fen-work"
ARROOT="$ROOT/build/archive-root"
ZIP="$ROOT/build/fen-lua.zip"
OUT="$ROOT/build/fen"

CC="${CC:-qcc -Vgcc_ntoarmv7le}"

pick() { local c; for c in "$@"; do if command -v "$c" >/dev/null 2>&1; then echo "$c"; return; fi; done; echo "$1"; }
need_deps() { [ -d "$DEPS" ] || { echo "error: run 'make deps' first" >&2; exit 1; }; }
need_fhs()  { : "${QNX_TARGET:?error: not in BBNDK FHS shell (QNX_TARGET unset); use 'make stageN'}"; }

stage1() { # Lua 5.4 static (≙ fenBinaryLua). POSIX path — QNX is not Linux.
  need_deps; need_fhs
  local XAR XRANLIB
  XAR="$(pick ntoarm-ar ntoarmv7-ar ar)"
  XRANLIB="$(pick ntoarm-ranlib ntoarmv7-ranlib ranlib)"
  rm -rf "$ROOT/build/lua-src"
  cp -R "$DEPS/lua" "$ROOT/build/lua-src"; chmod -R u+w "$ROOT/build/lua-src"
  sed -i 's|#define LUA_ROOT.*|#define LUA_ROOT "/usr/"|' "$ROOT/build/lua-src/src/luaconf.h"
  # Target liblua.a directly: nixpkgs patches Lua to also build a versioned
  # liblua.so, whose SONAME logic breaks outside nixpkgs' own build env. We
  # only need the static archive + headers, so never invoke the .so rule.
  make -C "$ROOT/build/lua-src/src" liblua.a \
    CC="$CC" AR="$XAR rcu" RANLIB="$XRANLIB" \
    MYCFLAGS='-DLUA_USE_POSIX'
  mkdir -p "$LUA/include" "$LUA/lib"
  cp "$ROOT"/build/lua-src/src/{lua.h,luaconf.h,lualib.h,lauxlib.h,lua.hpp} "$LUA/include/"
  cp "$ROOT/build/lua-src/src/liblua.a" "$LUA/lib/"
  echo "stage1 ok -> $LUA/lib/liblua.a"
}

stage2() { # fen C objects (≙ fenBinaryObjects).
  need_deps; need_fhs
  local F="$DEPS/fen-src" QT="$QNX_TARGET"
  mkdir -p "$OBJ"
  # termbox2.h does `#define _XOPEN_SOURCE` (empty); QNX sys/platform.h only
  # accepts 500/600/700. Its #ifndef guard lets us win from the command line.
  # _QNX_SOURCE = QNX's expose-all-APIs macro (strerror_r, cfmakeraw, etc.).
  $CC -O2 -Wall -D_XOPEN_SOURCE=600 -D_QNX_SOURCE -I"$LUA/include" \
    -c "$F/extensions/adapters/presenters/tui/vendor/lua_termbox2.c" -o "$OBJ/lua_termbox2.o"
  $CC -O2 -Wall -I"$LUA/include" -I"$QT/usr/include" \
    -c "$F/packages/util/vendor/fen_http.c" -o "$OBJ/fen_http.o"
  $CC -O2 -Wall -I"$LUA/include" \
    -c "$F/packages/util/vendor/fen_process.c" -o "$OBJ/fen_process.o"
  $CC -O2 -Wall -I"$LUA/include" \
    -c "$F/packages/util/vendor/fen_random.c" -o "$OBJ/fen_random.o"
  $CC -O2 -Wall -I"$LUA/include" \
    -c "$DEPS/lfs/src/lfs.c" -o "$OBJ/lfs.o"
  $CC -O2 -Wall -DNDEBUG -fPIC -I"$LUA/include" -c "$DEPS/cjson/lua_cjson.c" -o "$OBJ/lua_cjson.o"
  $CC -O2 -Wall -DNDEBUG -fPIC -I"$LUA/include" -c "$DEPS/cjson/strbuf.c"    -o "$OBJ/strbuf.o"
  $CC -O2 -Wall -DNDEBUG -fPIC -I"$LUA/include" -c "$DEPS/cjson/fpconv.c"    -o "$OBJ/fpconv.o"
  echo "stage2 ok -> $(ls "$OBJ" | tr '\n' ' ')"
}

stage3() { # Lua payload + version.lua + deterministic ZIP (≙ luaTree+zip).
  need_deps
  command -v fennel >/dev/null 2>&1 || { echo "error: no 'fennel'; run via 'make stage3' (devShell)" >&2; exit 1; }
  command -v zip    >/dev/null 2>&1 || { echo "error: no 'zip'; run via 'make stage3' (devShell)" >&2; exit 1; }
  rm -rf "$WORK"; cp -R "$DEPS/fen-src" "$WORK"; chmod -R u+w "$WORK"
  ( cd "$WORK" && fennel scripts/fennel-build.fnl )
  mkdir -p "$WORK/packages/fen/dist/fen"
  bash "$ROOT/scripts/gen-version-lua.sh" > "$WORK/packages/fen/dist/fen/version.lua"

  rm -rf "$ARROOT"; mkdir -p "$ARROOT"
  find "$WORK/packages" "$WORK/extensions" -type d -name dist -prune -print | sort | while read -r d; do
    cp -R "$d"/. "$ARROOT/"
  done
  cp "$DEPS/fennel.lua" "$ARROOT/fennel.lua"
  cp -R "$DEPS/dkjson/." "$ARROOT/"
  cp -R "$DEPS/luarocks" "$ARROOT/luarocks"

  local need
  for need in fen/main.lua fennel.lua dkjson.lua luarocks; do
    [ -e "$ARROOT/$need" ] || { echo "error: payload missing '$need'" >&2; exit 1; }
  done

  chmod -R u+rwX,go+rX "$ARROOT"
  find "$ARROOT" -exec touch -h -d @1 {} +
  rm -f "$ZIP"
  ( cd "$ARROOT" && find . -type f -print | sort | sed 's#^\./##' | zip -q -X -9 "$ZIP" -@ )
  # Capture the listing once: `unzip -l | grep -q` would SIGPIPE unzip and,
  # under `set -o pipefail`, fail the pipeline despite a match.
  local zl; zl="$(unzip -l "$ZIP")"
  grep -F -q 'fen/main.lua' <<<"$zl" || { echo "error: zip missing fen/main.lua" >&2; exit 1; }
  grep -F -q 'luarocks/'    <<<"$zl" || { echo "error: zip missing luarocks/"   >&2; exit 1; }
  grep -F -q 'fennel.lua'   <<<"$zl" || { echo "error: zip missing fennel.lua"  >&2; exit 1; }
  grep -F -q 'dkjson.lua'   <<<"$zl" || { echo "error: zip missing dkjson.lua"  >&2; exit 1; }
  echo "stage3 ok -> $ZIP ($(grep -c '' <<<"$zl") listing lines)"
}

stage4() { # compile fen.c + kubazip, partial-static link, append ZIP (≙ fenBinary).
  need_deps; need_fhs
  [ -f "$ZIP" ] || { echo "error: run stage3 first ($ZIP missing)" >&2; exit 1; }
  local QT="$QNX_TARGET" TLIB="$QNX_TARGET/armle-v7/usr/lib"
  # fen.c does #include <zip/zip.h>; the raw kubazip repo ships src/zip.h, so
  # build a tiny <zip/zip.h> include shim and compile src/zip.c directly.
  local KZC KZH
  KZC="$(find "$DEPS/kubazip" -name zip.c -path '*/src/*' | head -1)"
  KZH="$(find "$DEPS/kubazip" -name zip.h -path '*/src/*' | head -1)"
  [ -n "$KZC" ] && [ -n "$KZH" ] || { echo "error: kubazip src/zip.{c,h} not found" >&2; exit 1; }
  rm -rf "$ROOT/build/kubazip-inc"; mkdir -p "$ROOT/build/kubazip-inc/zip"
  cp "$KZH" "$ROOT/build/kubazip-inc/zip/zip.h"

  # Precompile fen.c and kubazip into $OBJ. Compiling straight from $DEPS
  # fails: gcc 4.6 writes the intermediate .o next to the source, but $DEPS
  # is a read-only /nix/store path. Also: gcc 4.6 defaults to gnu89; fen.c
  # and zip.c use C99 (decl-in-for) -> -std=gnu99. _QNX_SOURCE exposes
  # ftruncate/symlink prototypes used by kubazip.
  $CC -O2 -Wall -std=gnu99 \
    -I"$LUA/include" -I"$ROOT/build/kubazip-inc" -I"$(dirname "$KZC")" \
    -c "$DEPS/fen-src/packages/fen/fen.c" -o "$OBJ/fen_main.o"
  $CC -O2 -Wall -std=gnu99 -D_QNX_SOURCE \
    -I"$ROOT/build/kubazip-inc" -I"$(dirname "$KZC")" \
    -c "$KZC" -o "$OBJ/kubazip.o"

  # Partial-static: OUR code (liblua.a + kubazip/cjson/lfs/fen objects) is
  # baked in static; the platform network/TLS stack is dynamic. BB10's
  # libcurl.a was built with krb5/gssapi/tftp and QNX sockets, whose deps
  # (libgssapi/libkrb5) ship shared-only — so static curl is impossible.
  # Dynamic -lcurl resolves against the device's own maintained
  # /usr/lib/libcurl.so.2 (an OS component). --allow-shlib-undefined defers
  # libcurl.so's transitive deps to the runtime loader on-device.
  $CC -O2 -Wall "$OBJ"/*.o \
    -L"$LUA/lib" -L"$TLIB" \
    -Wl,-Bstatic -llua -Wl,-Bdynamic \
    -lcurl -lm \
    -Wl,--allow-shlib-undefined \
    -o "$OUT"
  cat "$ZIP" >> "$OUT"
  chmod +x "$OUT"
  file "$OUT"
  file "$OUT" | grep -qiE 'ARM' || { echo "error: not an ARM binary" >&2; exit 1; }
  echo "stage4 ok -> $OUT"
}

case "${1:?usage: cross-build.sh stage1|stage2|stage3|stage4}" in
  stage1) stage1 ;;
  stage2) stage2 ;;
  stage3) stage3 ;;
  stage4) stage4 ;;
  *) echo "unknown stage: $1" >&2; exit 2 ;;
esac
