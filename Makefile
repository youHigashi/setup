SHELL := /bin/bash

NO_SSH        ?=
SSH_KEY_TITLE ?=
HM_REPO       ?= git@github.com:youHigashi/home-manager-config.git
HM_DIR        ?= $(HOME)/.config/home-manager
HM_NAME       ?= you_higashi
AGE_KEY       ?= $(HOME)/.config/sops/age/keys.txt

.PHONY: setup nix home

setup:
	bash ./setup.sh $(if $(NO_SSH),--no-ssh) $(if $(SSH_KEY_TITLE),--ssh-key-title "$(SSH_KEY_TITLE)")

nix:
	@command -v nix >/dev/null 2>&1 && echo "[nix] already installed" || curl -fsSL https://install.determinate.systems/nix | sh -s -- install
	@echo "[nix] 新しいターミナルを開いてから make home を実行すること"

home:
	@test -f "$(AGE_KEY)" || { echo "[error] age key not found: $(AGE_KEY)"; exit 1; }
	@test -d "$(HM_DIR)/.git" || git clone "$(HM_REPO)" "$(HM_DIR)"
	nix run home-manager/master -- switch --flake "$(HM_DIR)#$(HM_NAME)" -b backup
