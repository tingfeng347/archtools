#!/usr/bin/env bash
# ==============================================================================
# archtools - uninstall script
# ==============================================================================
set -euo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
SHARE_DIR="${SHARE_DIR:-/usr/share/archtools}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/pac_tui"

prompt_yes_no() {
    local prompt="$1"
    local yn

    if [[ -r /dev/tty ]]; then
        read -rp "$prompt" yn < /dev/tty
    else
        read -rp "$prompt" yn
    fi

    [[ ! "$yn" =~ ^[Nn] ]]
}

echo -e "${CYAN}========================================${RESET}"
echo -e "${CYAN}  archtools - Uninstall${RESET}"
echo -e "${CYAN}========================================${RESET}"
echo ""

echo -e "${CYAN}[1/3]${RESET} 删除命令..."
REMOVED=0
for cmd in pack pacr pacd; do
    target="${BIN_DIR}/${cmd}"
    if [[ -e "$target" ]]; then
        sudo rm -f "$target"
        echo -e "  ${GREEN}✓${RESET} 已删除 $target"
        REMOVED=1
    else
        echo -e "  ${YELLOW}-${RESET} 未找到 $target"
    fi
done

if [[ "$REMOVED" -eq 0 ]]; then
    echo -e "  ${YELLOW}未发现已安装的 archtools 命令。${RESET}"
fi

echo ""
echo -e "${CYAN}[2/3]${RESET} 删除提示词文件..."
if [[ -d "$SHARE_DIR" ]]; then
    sudo rm -rf "$SHARE_DIR"
    echo -e "  ${GREEN}✓${RESET} 已删除 $SHARE_DIR"
else
    echo -e "  ${YELLOW}-${RESET} 未找到 $SHARE_DIR"
fi

echo ""
echo -e "${CYAN}[3/3]${RESET} 清理缓存..."
if [[ -d "$CACHE_DIR" ]]; then
    if prompt_yes_no "  是否删除缓存目录 $CACHE_DIR ? [Y/n] "; then
        rm -rf "$CACHE_DIR"
        echo -e "  ${GREEN}✓${RESET} 缓存已删除"
    else
        echo -e "  - 已保留缓存"
    fi
else
    echo -e "  ${YELLOW}-${RESET} 未找到缓存目录"
fi

echo ""
echo -e "${GREEN}卸载完成。${RESET}"
echo -e "注意：fzf、paru、flatpak、downgrade 可能被其他程序使用，卸载脚本不会删除这些系统依赖。"
