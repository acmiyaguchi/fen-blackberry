# fen-blackberry

Cross-compiles the [fen](https://github.com/acmiyaguchi/fen) coding-agent CLI
for **BlackBerry 10 / QNX 6.6 (armle-v7)** — the rooted Q10 in the parent
BBNDK tree. Upstream fen is consumed **unmodified** as a flake input.

## How it works

Nix's only job is pure, reproducible materialization of the exact dependency
*sources* fen's own build uses (`nixpkgs.follows = "fen/nixpkgs"`). The qcc
cross-compile runs **outside Nix**, inside the parent flake's BBNDK FHS shell
(`nix run /mnt/data/fun/blackberry#shell -- …`). Link model: **partial-static**
— our code and `liblua.a` are baked in; BB10's platform `libcurl`/TLS stack
and QNX libc are dynamic.

```sh
make fen             # deps -> stage1(Lua) -> stage2(C) -> stage3(payload) -> stage4(link)
make scp             # deploy build/fen to /accounts/1000/shared/documents/
make install-wrapper # `fen` wrapper into BerryCore bin -> on PATH in Term49
make smoke           # on-device fen --version/--help (no network)
make smoke-mock      # on-device --print via host OpenAI mock (no API spend)
```

`make install-wrapper` drops a 2-line wrapper at
`/accounts/1000/shared/misc/berrycore/bin/fen` that execs the real binary by
absolute path (required: fen finds its appended Lua zip via `argv[0]`).
BerryCore's `env.sh` puts that dir first on PATH, so in any Term49 shell you
just type `fen`. Re-run after a BerryCore re-extract (it wipes added bins).

`make help` lists every target. Stages 1/2/4 run in the BBNDK FHS; stage 3
(arch-independent Lua payload + ZIP) runs in this repo's `nix develop` shell.

## Modern-TLS / CA fix (resolved)

BB10's stock CA store is 2012-vintage, so the device's libcurl/OpenSSL
failed cert verification on current endpoints (Codex OAuth token exchange,
`api.openai.com`) with *"Peer certificate cannot be authenticated"*.

Fixed by shipping a current CA bundle, adding live OpenAI-host intermediates
for old-OpenSSL path building, and running fen through the BerryCore wrapper
that exports the bundle path:

```sh
make ca               # build + deploy build/cacert.pem -> device
make install-wrapper  # wrapper exports SSL_CERT_FILE/CURL_CA_BUNDLE
```

Run fen via the BerryCore `fen` wrapper (not the raw binary) so the CA env is
set. Since upstream `fen` v0.6.2, the native HTTP backend explicitly honors
`CURL_CA_BUNDLE` / `SSL_CERT_FILE` via `CURLOPT_CAINFO`. Verified with
`fen eval`: HTTPS to `example.com`, `api.openai.com`, and
`auth.openai.com/oauth/token` reaches HTTP status responses (TLS+cert OK),
not transport cert errors — so `fen --login openai-codex` can complete.

See `/home/anthony/.claude/plans/yeah-lets-do-that-calm-trinket.md` for the
full plan and `../docs/device-ssh-transfer.md` for the deploy recipe.
