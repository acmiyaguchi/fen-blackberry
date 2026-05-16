# Tunables for the fen-blackberry cross build. One place for paths/flags.

# Parent flake providing the BBNDK FHS shell (`#shell` -> bb-shell-entry,
# sources bbndk-env_10_3_1_995.sh then exec "$@").
PARENT_FLAKE := /mnt/data/fun/blackberry
BB_SHELL     := nix run $(PARENT_FLAKE)#shell --

# The fen checkout (only used by gen-version-lua.sh for the version stamp;
# the build itself consumes deps/fen-src materialized by `nix build .#deps`).
FEN_CHECKOUT := /mnt/data/fun/blackberry/fen

# QNX cross toolchain (resolved inside BB_SHELL; QNX_HOST/QNX_TARGET preset).
CC     := qcc -Vgcc_ntoarmv7le
AR     := ntoarmv7-ar
RANLIB := ntoarmv7-gcc-ranlib

# Device deploy (overridable via env / .env). USB-net dev-mode defaults.
BB_DEVICE   ?= 169.254.0.1
DEPLOY_DIR  ?= /accounts/1000/shared/documents
# BerryCore's bin is first on PATH in every Term49 shell (env.sh). The
# `fen` wrapper goes here so it's a first-class on-PATH command.
BERRYCORE_BIN ?= /accounts/1000/shared/misc/berrycore/bin
