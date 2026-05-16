# fen-blackberry

Cross-compiles the [fen](https://github.com/acmiyaguchi/fen) coding-agent CLI
for **BlackBerry 10 / QNX 6.6 (armle-v7)** — the rooted Q10 in the parent
BBNDK tree. Upstream fen is consumed **unmodified** as a flake input.

## How it works

Nix's only job is pure, reproducible materialization of the exact dependency
*sources* fen's own build uses (`nixpkgs.follows = "fen/nixpkgs"`). The qcc
cross-compile runs **outside Nix**, inside the parent flake's BBNDK FHS shell
(`nix run /mnt/data/fun/blackberry#shell -- …`). Link model: **partial-static**
— `libcurl/ssl/crypto/z` static from the QNX sysroot, QNX libc dynamic.

```sh
make fen      # deps -> stage1(Lua) -> stage2(C) -> stage3(payload) -> stage4(link)
make scp      # deploy build/fen to the device
make smoke    # on-device fen --version (no network)
```

`make help` lists every target. Stages 1/2/4 run in the BBNDK FHS; stage 3
(arch-independent Lua payload + ZIP) runs in this repo's `nix develop` shell.

## Runtime caveat (not a build issue)

BB10's static `libcurl` is 7.24.0 (2012) with vintage OpenSSL. Live TLS to
modern `api.openai.com`/`api.anthropic.com` may fail handshake/CA validation.
Preferred mitigation: a host-side TLS-terminating proxy over USB-net (the
device is offline-by-design in this tree). The mock smoke test avoids TLS
entirely.

See `/home/anthony/.claude/plans/yeah-lets-do-that-calm-trinket.md` for the
full plan and `../docs/device-ssh-transfer.md` for the deploy recipe.
