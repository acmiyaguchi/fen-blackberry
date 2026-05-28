# fen-blackberry

Cross-compiles the [fen](https://github.com/acmiyaguchi/fen) coding-agent CLI
for **BlackBerry 10 / QNX (armle-v7)** — the rooted Q10. Upstream fen is
consumed **unmodified** as a flake input. Standalone: clone it anywhere; the
only external requirement is a `bbndk-linux` tree pointed at by `BBNIX_SYSROOT`.

## How it works

Nix's only job is pure, reproducible materialization of the exact dependency
*sources* fen's own build uses (`nixpkgs.follows = "fen/nixpkgs"`). The
cross-compile uses the [bbnix](https://github.com/acmiyaguchi/bbnix) GCC 9
toolchain (flake input `bbnix`, prefix `arm-unknown-nto-qnx8.0.0eabi-*`) in the
`.#cross` devShell — no BBNDK FHS shell, no `qcc`. bbnix's GCC bakes
`--with-sysroot`, so device headers/libs resolve automatically. Link model:
**partial-static** — our code, `liblua.a`, AND the HTTPS/TLS stack (bbnix's
from-source `libcurl` over its OpenSSL 3.x + zlib), and the sysroot `libm.a`
are baked in. Only QNX `libsocket.so.3` and `libc.so.3` stay dynamic, resolved
on-device; Fen does not require `libgcc_s.so.1` in the device loader path. This
escapes the device's EOL `libcurl.so.2` / OpenSSL 1.0.x.

Stages 1/2/4 build `--impure` because bbnix reads `BBNIX_SYSROOT` and throws if
it is unset:

```sh
export BBNIX_SYSROOT=/path/to/bbndk-linux
make fen     # deps -> stage1(Lua) -> stage2(C) -> stage3(payload) -> stage4(link)
make help    # lists every target
```

Stage 3 (the arch-independent Lua payload + deterministic ZIP) runs in the pure
host devShell and needs no sysroot.

## Deploying to a device

Out of scope — this repo only produces `build/fen`. Copy it to the device with
whatever transport you use and launch it by **absolute path** (fen locates its
appended Lua zip via `argv[0]`).

TLS: bbnix's static `libcurl`/`openssl` bake `CAINFO`/`OPENSSLDIR` to
`/accounts/1000/shared/misc/bbnix/ssl/`, where its `deploy-bundle` stages a
current Mozilla `cacert.pem` — modern endpoints validate with no env override.
If you're not deploying that bundle, export `CURL_CA_BUNDLE` / `SSL_CERT_FILE`
to a current bundle of your own (fen ≥ v0.6.2 honors these via `CURLOPT_CAINFO`);
BB10's stock 2012-vintage store will fail most handshakes.
`FEN_HTTP_IDLE_TIMEOUT_MS` (fen ≥ v0.7.1) overrides the per-request idle-stall
watchdog (default 60 s, `0` disables) — useful for slow/quiet streaming
providers on a flaky device link.
