# CLAUDE.md — fen-blackberry

Cross-builds upstream `fen` for BB10/QNX 6.6 armle-v7. **fen is never
modified** — it is `inputs.fen` (flake input pin); `nixpkgs.follows =
"fen/nixpkgs"` keeps all 7 deps byte-identical to fen's own build.

## Architecture (do not relitigate)

- Nix = pure source materialization only (`nix/deps.nix` → `make deps` →
  `build/deps`). It does NOT compile.
- The qcc cross-compile runs OUTSIDE Nix in the parent BBNDK FHS:
  `nix run /mnt/data/fun/blackberry#shell -- bash scripts/cross-build.sh stageN`.
  A Nix sandbox cannot reach the parent FHS (no `/mnt`, no nested user-ns).
- Stage 3 (Lua payload + deterministic ZIP) is arch-independent and runs in
  this repo's devShell — the BBNDK FHS lacks `zip`.
- Link is partial-static: `-Wl,-Bstatic -llua -lcurl -lssl -lcrypto -lz
  -Wl,-Bdynamic -lm` (QNX libc dynamic).

## The 4 stages mirror fen/nix/artifacts.nix 1:1

| stage | ≙ artifacts.nix | notes |
|---|---|---|
| 1 | fenBinaryLua  | `make posix` (NOT linux), `-DLUA_USE_POSIX`, `MYLIBS=-lm` |
| 2 | fenBinaryObjects | 5 fen .c + lfs.c + cjson trio (`-DNDEBUG -fPIC`) |
| 3 | luaTree + zip | host fennel; assemble archive-root; deterministic zip |
| 4 | fenBinary     | fen.c + kubazip src/zip.c; link; `cat zip >> fen` |

Dropped vs Nix (correct — no store paths exist here): the `perl /nix/store`
scrub, `patchelf`, `remove-references-to`.

## Gotchas

- fen.c needs ZERO source changes: `/proc/self/exe` falls back to absolute
  `argv[0]`; always launch fen by absolute path on-device.
- The embedded zip MUST contain `fen/main.lua` + `fennel.lua` + `dkjson.lua`
  + `luarocks/` or on-device startup crashes in `rocks.prepend-tree!`.
  stage3 hard-asserts this.
- kubazip raw repo ships `src/zip.h`; fen.c wants `<zip/zip.h>` — stage4
  builds a one-file include shim.
- gcc is 4.8.3; add `-std=gnu99` per-file only if a C11 error appears.
- Iterate by running stages and fixing real errors; don't pre-guess tool
  names — `cross-build.sh` probes `ntoarm-ar`/`ranlib` etc.

Full plan: `/home/anthony/.claude/plans/yeah-lets-do-that-calm-trinket.md`.
