#!/usr/bin/env bash
# Build a device CA bundle and scp it so fen's system libcurl/OpenSSL can
# verify modern certs. BB10's OpenSSL is 1.0.x: a current root set is
# necessary but NOT sufficient — it cannot reliably *path-build* modern
# cross-signed chains (e.g. GTS Root R4 cross-signed by GlobalSign). So the
# bundle = current Mozilla roots + the live server-sent intermediates for
# the OpenAI hosts, which makes verification deterministic on old OpenSSL.
#
# Idempotent: base Mozilla bundle is cached at build/cacert.base.pem; the
# final build/cacert.pem is rebuilt fresh (base + intermediates) every run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib-ssh.sh"

CACERT_URL="${CACERT_URL:-https://curl.se/ca/cacert.pem}"
CACERT_DEVICE="${CACERT_DEVICE:-/accounts/1000/shared/documents/cacert.pem}"
HOSTS="${CACERT_HOSTS:-auth.openai.com api.openai.com chatgpt.com}"
base="$ROOT/build/cacert.base.pem"
final="$ROOT/build/cacert.pem"

mkdir -p "$ROOT/build"
if [ "${1:-}" = "--force" ] || [ ! -s "$base" ]; then
  echo ">> fetching $CACERT_URL"
  curl -fsSL "$CACERT_URL" -o "$base"
fi
n="$(grep -c 'BEGIN CERTIFICATE' "$base" || true)"
[ "${n:-0}" -ge 100 ] || { echo "error: $base looks wrong ($n certs)" >&2; exit 1; }
echo ">> base Mozilla bundle: $n roots"

cp "$base" "$final"
for H in $HOSTS; do
  echo | nix shell nixpkgs#openssl -c openssl s_client -connect "$H:443" -servername "$H" -showcerts 2>/dev/null \
    | nix shell nixpkgs#gawk -c awk '/-----BEGIN CERTIFICATE-----/{f=1} f{print} /-----END CERTIFICATE-----/{f=0}' \
    >> "$final" || true
done
echo ">> final bundle (roots + OpenAI-host chains): $(grep -c 'BEGIN CERTIFICATE' "$final") certs"

trap bb_close EXIT
bb_open
bb_in_shell "scp $SSHOPTS -O '$final' devuser@$BB_DEVICE:$CACERT_DEVICE"
bb_ssh_q "ls -l $CACERT_DEVICE"
echo ">> deployed CA bundle -> $CACERT_DEVICE"
