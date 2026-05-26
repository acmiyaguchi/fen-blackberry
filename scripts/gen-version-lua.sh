#!/usr/bin/env bash
# Emit packages/fen/dist/fen/version.lua (the table fen.c-loaded fen.main
# expects). Replaces fen's Nix luaTree heredoc. fen only requires the table to
# load and carry a .version string; the other fields are cosmetic /status.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Default: derive provenance from the materialized deps (no local checkout).
# FEN_CHECKOUT may be set in the environment to stamp from a working tree
# (richer `git describe`/dirty info); it is unset by default.
FEN_CHECKOUT="${FEN_CHECKOUT:-}"

rev="unknown"; short="unknown"; dirty="false"; ver="unknown"; mod=""
if [ -n "$FEN_CHECKOUT" ] && git -C "$FEN_CHECKOUT" rev-parse --git-dir >/dev/null 2>&1; then
  rev="$(git -C "$FEN_CHECKOUT" rev-parse HEAD)"
  short="$(git -C "$FEN_CHECKOUT" rev-parse --short HEAD)"
  ver="$(git -C "$FEN_CHECKOUT" describe --tags --always --dirty 2>/dev/null || echo "$short")"
  mod="$(git -C "$FEN_CHECKOUT" log -1 --format=%cI 2>/dev/null || true)"
  [ -n "$(git -C "$FEN_CHECKOUT" status --porcelain 2>/dev/null)" ] && dirty="true"
elif [ -f "$ROOT/build/deps/VERSIONS" ]; then
  rev="$(sed -n 's/^fen-rev=//p' "$ROOT/build/deps/VERSIONS")"
  short="${rev:0:7}"; ver="$short"
fi

cat <<EOF
return {
  version = "${ver}",
  gitRev = "${rev}",
  gitShortRev = "${short}",
  dirty = ${dirty},
  source = "fen-blackberry",
  lastModified = "${mod}",
  buildSystem = "x86_64-linux",
  targetSystem = "arm-unknown-nto-qnx8.0.0eabi",
}
EOF
