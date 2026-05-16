#!/usr/bin/env bash
# Fetch a current Mozilla CA bundle on the host (host TLS works) and scp it
# to the device, so fen's system libcurl/OpenSSL can verify modern certs.
# BB10's stock trust store is 2012-vintage and fails on today's endpoints.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib-ssh.sh"

CACERT_URL="${CACERT_URL:-https://curl.se/ca/cacert.pem}"
CACERT_DEVICE="${CACERT_DEVICE:-/accounts/1000/shared/documents/cacert.pem}"
local_pem="$ROOT/build/cacert.pem"

mkdir -p "$ROOT/build"
if [ "${1:-}" = "--force" ] || [ ! -s "$local_pem" ]; then
  echo ">> fetching $CACERT_URL"
  curl -fsSL "$CACERT_URL" -o "$local_pem"
fi
n="$(grep -c 'BEGIN CERTIFICATE' "$local_pem" || true)"
[ "${n:-0}" -ge 100 ] || { echo "error: $local_pem looks wrong ($n certs)" >&2; exit 1; }
echo ">> host bundle: $n certificates"

trap bb_close EXIT
bb_open
bb_in_shell "scp $SSHOPTS -O '$local_pem' devuser@$BB_DEVICE:$CACERT_DEVICE"
bb_ssh_q "ls -l $CACERT_DEVICE"
echo ">> deployed CA bundle -> $CACERT_DEVICE"
