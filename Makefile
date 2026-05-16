# fen-blackberry — cross-compile fen for BlackBerry 10 / QNX 6.6 (armle-v7).
#
# Nix materializes version-matched dependency *sources* (`make deps`); the
# qcc compile/link runs OUTSIDE Nix inside the parent flake's BBNDK FHS shell.
# Stage 3 (Lua payload) is arch-independent and runs in this repo's devShell.

include config.mk

.PHONY: help deps stage1 stage2 stage3 stage4 fen scp smoke clean

help:
	@echo 'fen-blackberry targets:'
	@echo '  deps    — nix build .#deps -> build/deps (version-matched sources)'
	@echo '  stage1  — qcc: Lua 5.4 static (liblua.a) [BBNDK FHS]'
	@echo '  stage2  — qcc: fen C objects             [BBNDK FHS]'
	@echo '  stage3  — host fennel: Lua payload + archive-root [devShell]'
	@echo '  stage4  — qcc: zip + partial-static link + append [BBNDK FHS]'
	@echo '  fen     — deps stage1 stage2 stage3 stage4 (full build)'
	@echo '  scp     — deploy build/fen to the device (scripts/deploy.sh)'
	@echo '  smoke   — credit-free on-device --print (scripts/smoke-device.sh)'
	@echo '  clean   — rm -rf build/'

deps:
	nix build .#deps --out-link build/deps

stage1 stage2 stage4:
	$(BB_SHELL) bash scripts/cross-build.sh $@

stage3:
	nix develop --command bash scripts/cross-build.sh stage3

fen: deps stage1 stage2 stage3 stage4
	@echo "built: build/fen"
	@file build/fen

scp:
	bash scripts/deploy.sh

smoke:
	bash scripts/smoke-device.sh

clean:
	rm -rf build
