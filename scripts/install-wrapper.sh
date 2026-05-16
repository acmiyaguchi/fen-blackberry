#!/usr/bin/env bash
# Install a `fen` wrapper into BerryCore's bin so it's a first-class on-PATH
# command in any Term49 shell. The wrapper execs fen by ABSOLUTE path, which
# is required: fen.c locates its appended Lua zip via argv[0] (and our port
# patch relies on argv[0][0]=='/'), so a bare PATH lookup would not work.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib-ssh.sh"

DEPLOY_DIR="${DEPLOY_DIR:-/accounts/1000/shared/documents}"
BERRYCORE_BIN="${BERRYCORE_BIN:-/accounts/1000/shared/misc/berrycore/bin}"

trap bb_close EXIT
bb_open

stage="$(mktemp -d)"
cat > "$stage/fen" <<EOF
#!$BERRYCORE_BIN/bash
exec $DEPLOY_DIR/fen "\$@"
EOF
chmod +x "$stage/fen"

echo ">> installing wrapper -> $BB_DEVICE:$BERRYCORE_BIN/fen"
bb_in_shell "scp $SSHOPTS -O '$stage/fen' devuser@$BB_DEVICE:$BERRYCORE_BIN/fen"
rm -rf "$stage"
bb_ssh_q "chmod +x $BERRYCORE_BIN/fen; ls -l $BERRYCORE_BIN/fen; $BERRYCORE_BIN/fen --version"
echo ">> done — \`fen\` is now on PATH in any Term49/BerryCore shell"
