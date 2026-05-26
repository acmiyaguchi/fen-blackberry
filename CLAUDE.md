# CLAUDE.md — fen-blackberry

Cross-builds upstream `fen` for BB10/QNX armle-v7. **fen is never modified** —
it is `inputs.fen` (flake input pin); `nixpkgs.follows = "fen/nixpkgs"` keeps
all 7 deps byte-identical to fen's own build.

## Architecture (do not relitigate)

- Standalone: clone anywhere. The only external requirement is `BBNIX_SYSROOT`
  (a `bbndk-linux` tree) for the compile stages — the bbnix contract.
- Nix = pure source materialization only (`nix/deps.nix` → `make deps` →
  `build/deps`). It does NOT compile.
- The cross-compile uses the **bbnix** GCC 9 toolchain (input `bbnix`, prefix
  `arm-unknown-nto-qnx8.0.0eabi-*`) via the `.#cross` devShell. bbnix's gcc
  bakes `--with-sysroot`, so device headers/libs resolve automatically — no
  BBNDK FHS shell, no `qcc`. Stages 1/2/4 build `--impure` because bbnix reads
  `BBNIX_SYSROOT` via `getEnv` and throws if unset.
- Stage 3 (Lua payload + deterministic ZIP) is arch-independent and runs in the
  pure host devShell (`.#`), which carries `fennel`/`zip`.
- Link is partial-static: `-Wl,-Bstatic -llua -lcurl -lssl -lcrypto -lz
  -Wl,-Bdynamic -lsocket -lm`. Our code, Lua, AND the HTTPS/TLS stack are baked
  in — bbnix's static `libcurl.a` over its from-source OpenSSL 3.x + zlib
  (flake input `bbnix`, attrs `bb.curl`/`bb.openssl`/`bb.zlib`, store paths
  exported into `.#cross` as `BBNIX_CURL`/`BBNIX_OPENSSL`/`BBNIX_ZLIB`). This
  escapes the device's EOL `libcurl.so.2` / OpenSSL 1.0.x and its stale CA
  store. Only QNX platform libs stay dynamic: `libsocket.so.3` (QNX sockets/
  getaddrinfo, needed now that curl is static), `libm.so.2`, `libgcc_s.so.1`,
  `libc.so.3` — resolved on-device.
- **Device ops are NOT here.** This repo only produces `build/fen`; deploy,
  smoke, and the CA bundle are out of scope. Copy the binary to the device and
  launch it by absolute path (fen locates its appended Lua zip via `argv[0]`).

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
- GCC 9 over QNX's Dinkumware sysroot: `-include stddef.h` is applied to every
  compile (`$QNXCC`) for the `_GCC_SIZE_T`/`<unistd.h>` `size_t` gap. If more
  QNX-cross errors appear, the playbook is `bbnix/pkgs/qnx-common.nix`
  (`-DSA_RESTART=0`, feature macros). fen is pure C, so the C++ ABI flags and
  the GCC9-vs-4.8.3 exception/RTTI hazard do not apply.
- Iterate by running stages and fixing real errors.
