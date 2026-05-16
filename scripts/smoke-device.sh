#!/usr/bin/env bash
# On-device smoke tests.
#   level 0 (default): fen --version + --help. No network. Proves the
#                      embedded zip + Lua + fennel + luarocks startup on QNX.
#   level 1 / mock   : host runs fen's OpenAI mock; device reaches it through
#                      an SSH reverse tunnel; `fen --print` drives real
#                      provider+HTTP (fen_http -> device libcurl.so.2) + the
#                      read tool + print presenter. Zero API spend.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib-ssh.sh"

DEPLOY_DIR="${DEPLOY_DIR:-/accounts/1000/shared/documents}"
FEN_CHECKOUT="${FEN_CHECKOUT:-/mnt/data/fun/blackberry/fen}"
LEVEL="${1:-0}"

trap bb_close EXIT
bb_open

case "$LEVEL" in
  0)
    echo ">> fen --version"; bb_ssh_q "$DEPLOY_DIR/fen --version"
    echo ">> fen --help (first lines)"; bb_ssh_q "$DEPLOY_DIR/fen --help | sed -n 1,4p || $DEPLOY_DIR/fen --help"
    echo "smoke level 0 ok"
    ;;
  1|mock)
    portfile="$(mktemp)"; mocklog="$(mktemp)"
    echo ">> starting fen OpenAI mock (fen devShell, has luasocket)"
    ( cd "$FEN_CHECKOUT" && nix develop "$FEN_CHECKOUT#" --command \
        fennel scripts/mock-openai.fnl "$portfile" ) >"$mocklog" 2>&1 &
    mockpid=$!
    trap 'kill $mockpid 2>/dev/null||true; bb_close; rm -f "$portfile" "$mocklog"' EXIT
    for _ in $(seq 1 120); do [ -s "$portfile" ] && break; sleep 0.5; done
    [ -s "$portfile" ] || { echo "mock did not start" >&2; cat "$mocklog" >&2; exit 1; }
    PORT="$(cat "$portfile")"
    echo ">> mock on host 127.0.0.1:$PORT"

    WD="$DEPLOY_DIR/fen-smoke"
    # devuser's shell has no printf/sed/head — stage files on the host and scp.
    stage="$(mktemp -d)"
    printf '%s' "{\"providers\":{\"mock-openai\":{\"api\":\"openai-completions\",\"baseUrl\":\"http://127.0.0.1:$PORT/v1\",\"apiKey\":\"dummy\",\"models\":[{\"id\":\"mock-chat\"}]}}}" > "$stage/models.json"
    printf 'fen-blackberry smoke fixture\n' > "$stage/README.md"
    bb_ssh_q "mkdir -p $WD/config/fen $WD/state"
    bb_in_shell "scp $SSHOPTS -O '$stage/models.json' devuser@$BB_DEVICE:$WD/config/fen/models.json"
    bb_in_shell "scp $SSHOPTS -O '$stage/README.md'  devuser@$BB_DEVICE:$WD/README.md"
    rm -rf "$stage"

    prompt='Use the read tool to read README.md, then reply with the single word OK'
    echo ">> device fen --print via reverse tunnel"
    out="$(bb_in_shell "ssh $SSHOPTS -R 127.0.0.1:$PORT:127.0.0.1:$PORT devuser@$BB_DEVICE \
      'cd $WD; HOME=$WD XDG_CONFIG_HOME=$WD/config XDG_STATE_HOME=$WD/state \
       $DEPLOY_DIR/fen --provider mock-openai --model mock-chat --no-session --print \"$prompt\"'" 2>&1)" || true
    echo "---- device output ----"; printf '%s\n' "$out"; echo "-----------------------"
    if printf '%s' "$out" | grep -q OK; then
      echo "smoke level 1 (mock) PASS"
    else
      echo "smoke level 1 (mock) FAIL" >&2; echo "--- mock log ---" >&2; cat "$mocklog" >&2; exit 1
    fi
    ;;
  *) echo "unknown level: $LEVEL" >&2; exit 2 ;;
esac
