#!/usr/bin/env bash
# Push build/fen to the rooted Q10 over the dev-mode SSH channel.
# Implements docs/device-ssh-transfer.md verbatim (OpenSSH 6.2 legacy algos,
# scp -O, non-persistent blackberry-connect channel killed via Connect.jar).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARENT_FLAKE="${PARENT_FLAKE:-/mnt/data/fun/blackberry}"
BIN="${1:-$ROOT/build/fen}"
DEPLOY_DIR="${DEPLOY_DIR:-/accounts/1000/shared/documents}"

[ -f "$BIN" ] || { echo "error: $BIN not built (run 'make fen')" >&2; exit 1; }
# BB_DEVICE / BB_PASSWORD live in the parent tree's gitignored .env.
[ -f "$PARENT_FLAKE/.env" ] && . "$PARENT_FLAKE/.env"
: "${BB_DEVICE:?set BB_DEVICE (or populate $PARENT_FLAKE/.env)}"
: "${BB_PASSWORD:?set BB_PASSWORD (or populate $PARENT_FLAKE/.env)}"
KEY="$HOME/.rim/bbt_id_rsa"
[ -f "$KEY" ] || { echo "error: dev key $KEY missing" >&2; exit 1; }

SSHOPTS="-F /dev/null -i $KEY -o BatchMode=yes -o IdentitiesOnly=yes \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
-o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa -o Ciphers=aes128-ctr -o MACs=hmac-sha1"

log="$(mktemp)"; trap 'rm -f "$log"' EXIT
echo ">> opening blackberry-connect channel..."
nix run "$PARENT_FLAKE#shell" -- bash -c \
  "blackberry-connect '$BB_DEVICE' -password '$BB_PASSWORD' -sshPublicKey '$HOME/.rim/bbt_id_rsa.pub'" \
  >"$log" 2>&1 &
for _ in $(seq 1 60); do
  grep -q "Successfully connected" "$log" && break
  sleep 1
done
grep -q "Successfully connected" "$log" || { echo "error: channel did not open"; cat "$log"; exit 1; }

close() {
  echo ">> closing channel (kill Connect.jar)"
  pkill -f Connect.jar 2>/dev/null || true
}
trap 'close; rm -f "$log"' EXIT

echo ">> scp $BIN -> $BB_DEVICE:$DEPLOY_DIR/fen"
nix run "$PARENT_FLAKE#shell" -- bash -c \
  "scp $SSHOPTS -O '$BIN' devuser@'$BB_DEVICE':'$DEPLOY_DIR'/fen"
nix run "$PARENT_FLAKE#shell" -- bash -c \
  "ssh $SSHOPTS devuser@'$BB_DEVICE' 'ls -l $DEPLOY_DIR/fen'"
echo ">> deployed: $DEPLOY_DIR/fen"
