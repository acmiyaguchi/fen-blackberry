#!/usr/bin/env bash
# Emit packages/fen/dist/fen/version.lua (the table fen.c-loaded fen.main
# expects). Replaces fen's Nix luaTree heredoc. fen only requires the table to
# load and carry a .version string; the other fields are cosmetic /status.
#
# Provenance comes from the materialized deps (build/deps/VERSIONS) — the
# standalone model never needs a local fen checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

rev="unknown"; short="unknown"; dirty="false"; ver="unknown"; mod=""
if [ -f "$ROOT/build/deps/VERSIONS" ]; then
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
