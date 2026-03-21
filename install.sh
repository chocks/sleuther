#!/usr/bin/env bash
# install.sh — Installer for sleuther Oh My Zsh plugin
set -euo pipefail

G=$'\033[0;32m' C=$'\033[0;36m' Y=$'\033[0;33m' R=$'\033[0;31m'
B=$'\033[1m' D=$'\033[2m' X=$'\033[0m'

PLUGIN_DIR="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/sleuther"

echo ""
echo "${B}${C}  sleuther installer${X}"
echo ""

if [[ ! -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}" ]] && [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    echo "${R}  ✗ Oh My Zsh not found.${X}"
    echo "${D}  Install it first: https://ohmyz.sh${X}"
    echo "${D}  Or source directly: source /path/to/sleuther/sleuther.plugin.zsh${X}"
    exit 1
fi

if [[ -d "$PLUGIN_DIR" ]]; then
    echo "${Y}  Plugin already exists at: $PLUGIN_DIR${X}"
    read -rp "  Overwrite? [y/N] " answer
    [[ "$answer" != [yY] ]] && { echo "  Aborted."; exit 0; }
    rm -rf "$PLUGIN_DIR"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/sleuther.plugin.zsh" ]]; then
    cp -r "$SCRIPT_DIR" "$PLUGIN_DIR"
else
    git clone --depth 1 https://github.com/chocks/sleuther.git "$PLUGIN_DIR"
fi

chmod +x "$PLUGIN_DIR/bin/ollama-helper"

echo "${G}  ✓ Installed to: $PLUGIN_DIR${X}"
echo ""

if [[ -f "${HOME}/.zshrc" ]] && grep -q "sleuther" "${HOME}/.zshrc" 2>/dev/null; then
    echo "${D}  sleuther already in .zshrc${X}"
else
    echo "  Add to ${B}~/.zshrc${X}:  plugins=(... ${C}sleuther${X} ...)"
fi

echo ""
echo "${G}${B}  Done! Restart your shell or run: source ~/.zshrc${X}"
echo ""
