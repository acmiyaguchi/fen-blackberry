#!/usr/bin/env bash
# Push build/fen to the rooted Q10 (direct SSH if reachable, else
# blackberry-connect). See docs/device-ssh-transfer.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib-ssh.sh"

BIN="${1:-$ROOT/build/fen}"
DEPLOY_DIR="${DEPLOY_DIR:-/accounts/1000/shared/documents}"
[ -f "$BIN" ] || { echo "error: $BIN not built (run 'make fen')" >&2; exit 1; }

trap bb_close EXIT
bb_open

echo ">> scp $BIN -> $BB_DEVICE:$DEPLOY_DIR/fen"
bb_in_shell "scp $SSHOPTS -O '$BIN' devuser@$BB_DEVICE:$DEPLOY_DIR/fen"
bb_ssh_q "chmod +x $DEPLOY_DIR/fen; ls -l $DEPLOY_DIR/fen"
echo ">> deployed: $DEPLOY_DIR/fen"
