#!/usr/bin/env bash
# On-device smoke tests over the dev-mode SSH channel.
#
#   level 0 (default) : `fen --version` + `--help` — no network; proves the
#                        embedded zip + Lua + fennel + luarocks startup chain
#                        runs on QNX. Zero API spend.
#   level 1 (mock)    : host mock-openai over USB-net + device `--print`.
#                        Implemented in task 8 (credit-free functional test).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARENT_FLAKE="${PARENT_FLAKE:-/mnt/data/fun/blackberry}"
DEPLOY_DIR="${DEPLOY_DIR:-/accounts/1000/shared/documents}"
LEVEL="${1:-0}"

[ -f "$PARENT_FLAKE/.env" ] && . "$PARENT_FLAKE/.env"
: "${BB_DEVICE:?set BB_DEVICE}" ; : "${BB_PASSWORD:?set BB_PASSWORD}"
KEY="$HOME/.rim/bbt_id_rsa"

SSHOPTS="-F /dev/null -i $KEY -o BatchMode=yes -o IdentitiesOnly=yes \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
-o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa -o Ciphers=aes128-ctr -o MACs=hmac-sha1"

log="$(mktemp)"
nix run "$PARENT_FLAKE#shell" -- bash -c \
  "blackberry-connect '$BB_DEVICE' -password '$BB_PASSWORD' -sshPublicKey '$HOME/.rim/bbt_id_rsa.pub'" \
  >"$log" 2>&1 &
for _ in $(seq 1 60); do grep -q "Successfully connected" "$log" && break; sleep 1; done
grep -q "Successfully connected" "$log" || { echo "channel failed"; cat "$log"; rm -f "$log"; exit 1; }
trap 'pkill -f Connect.jar 2>/dev/null || true; rm -f "$log"' EXIT

run() { nix run "$PARENT_FLAKE#shell" -- bash -c "ssh $SSHOPTS devuser@'$BB_DEVICE' '$1'"; }

case "$LEVEL" in
  0)
    echo ">> fen --version"
    run "$DEPLOY_DIR/fen --version"
    echo ">> fen --help (head)"
    run "$DEPLOY_DIR/fen --help | head -5"
    echo "smoke level 0 ok"
    ;;
  1|mock)
    echo "level 1 (mock) smoke is implemented in task 8 — not yet wired" >&2
    exit 3
    ;;
  *) echo "unknown level: $LEVEL" >&2; exit 2 ;;
esac
