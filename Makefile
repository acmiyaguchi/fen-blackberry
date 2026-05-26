# fen-blackberry — cross-compile fen for BlackBerry 10 / QNX (armle-v7).
#
# Nix materializes version-matched dependency *sources* (`make deps`); the
# cross compile/link uses the bbnix GCC toolchain in the `.#cross` devShell.
# Stages 1/2/4 need BBNIX_SYSROOT set (they build `--impure`); set it to your
# bbndk-linux tree, e.g.  BBNIX_SYSROOT=/path/to/bbndk-linux make fen
# Stage 3 (Lua payload) is arch-independent and runs in the pure host devShell.
# Deploying to a device is out of scope — this only produces build/fen; copy it
# to the device and launch it by absolute path.

include config.mk

.PHONY: help deps stage1 stage2 stage3 stage4 fen clean

help:
	@echo 'fen-blackberry targets (set BBNIX_SYSROOT for stages 1/2/4):'
	@echo '  deps    — nix build .#deps -> build/deps (version-matched sources)'
	@echo '  stage1  — bbnix gcc: Lua 5.4 static (liblua.a)   [.#cross --impure]'
	@echo '  stage2  — bbnix gcc: fen C objects               [.#cross --impure]'
	@echo '  stage3  — host fennel: Lua payload + archive-root [devShell]'
	@echo '  stage4  — bbnix gcc: zip + partial-static link + append [.#cross --impure]'
	@echo '  fen     — deps stage1 stage2 stage3 stage4 (full build)'
	@echo '  clean   — rm -rf build/'

deps:
	nix build .#deps --out-link build/deps

stage1 stage2 stage4:
	nix develop .#cross --impure --command bash scripts/cross-build.sh $@

stage3:
	nix develop --command bash scripts/cross-build.sh stage3

fen: deps stage1 stage2 stage3 stage4
	@echo "built: build/fen"
	@file build/fen

clean:
	rm -rf build
