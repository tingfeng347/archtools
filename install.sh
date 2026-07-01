#!/usr/bin/env bash
# ==============================================================================
# archtools - Arch Linux 包管理 TUI 一键安装脚本
# 支持 Pacman / AUR / Flatpak 三源统一搜索安装、卸载与降级
# ==============================================================================
set -euo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
SHARE_DIR="${SHARE_DIR:-/usr/share/archtools}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

ensure_sudo() {
    echo -e "  需要 sudo 权限安装依赖，如提示请输入当前用户密码。"
    sudo -v
}

pacman_install_packages() {
    echo -e "  正在安装: $*"
    sudo pacman -S --noconfirm --needed "$@"
}

# --- 检查是否为 Arch Linux ---
if ! grep -qi 'arch' /etc/os-release 2>/dev/null; then
    echo -e "${RED}错误：此脚本仅支持 Arch Linux 系统。${RESET}"
    echo -e "当前系统：$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo '未知')"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo -e "${RED}错误：未找到 pacman，此脚本仅支持 Arch Linux。${RESET}"
    exit 1
fi

echo -e "${CYAN}========================================${RESET}"
echo -e "${CYAN}  archtools - Arch Linux Package TUI${RESET}"
echo -e "${CYAN}========================================${RESET}"
echo ""

# --- 自动安装 fzf ---
install_fzf() {
    echo -e "${YELLOW}  未检测到 fzf，核心依赖，必须安装。${RESET}"
    if ! prompt_yes_no "  是否安装? [Y/n] "; then
        echo -e "${RED}  已取消，pack/pacr/pacd 无法运行。${RESET}"
        exit 1
    fi
    ensure_sudo
    pacman_install_packages fzf
    echo -e "  ${GREEN}✓${RESET} fzf 已安装"
}

# --- 自动安装 base-devel + git (构建 AUR 包必备) ---
install_build_deps() {
    local need=()
    command -v git >/dev/null 2>&1 || need+=("git")
    if ! pacman -Qg base-devel >/dev/null 2>&1; then
        need+=("base-devel")
    fi
    if [[ ${#need[@]} -eq 0 ]]; then
        return 0
    fi

    echo -e "${YELLOW}  未检测到 ${need[*]} (构建 AUR 助手需要)。${RESET}"
    if ! prompt_yes_no "  是否安装? [Y/n] "; then
        echo -e "  - 跳过，AUR 助手将无法构建"
        return 1
    fi
    ensure_sudo
    pacman_install_packages "${need[@]}"
    echo -e "  ${GREEN}✓${RESET} ${need[*]} 已安装"
    return 0
}

# --- 自动安装 paru (AUR 助手, 优先) ---
install_paru() {
    echo -e "${YELLOW}  未检测到 AUR 助手 (paru/yay)。${RESET}"
    if ! prompt_yes_no "  是否安装 paru? [Y/n] "; then
        echo -e "  - 跳过，AUR 源将不可用"
        return 1
    fi

    install_build_deps || return 1

    local build_dir
    build_dir=$(mktemp -d -t archtools-paru-build.XXXXXX)
    echo -e "  正在从 AUR 构建 paru，需要 sudo 权限..."
    if ! git clone --depth=1 https://aur.archlinux.org/paru.git "$build_dir" >&2; then
        echo -e "${RED}  paru 源码克隆失败。${RESET}"
        rm -rf "$build_dir"
        return 1
    fi
    if ! (cd "$build_dir" && makepkg -si --noconfirm); then
        echo -e "${RED}  paru 构建失败。${RESET}"
        rm -rf "$build_dir"
        return 1
    fi
    rm -rf "$build_dir"
    echo -e "  ${GREEN}✓${RESET} paru 已安装"
    return 0
}

# --- 自动安装 flatpak + flathub ---
install_flatpak() {
    echo -e "${YELLOW}  未检测到 flatpak。${RESET}"
    if ! prompt_yes_no "  是否安装 flatpak? [Y/n] "; then
        echo -e "  - 跳过，Flatpak 源将不可用"
        return 1
    fi
    ensure_sudo
    pacman_install_packages flatpak
    echo -e "  ${GREEN}✓${RESET} flatpak 已安装"
    return 0
}

setup_flathub() {
    if ! flatpak remotes --system 2>/dev/null | grep -q flathub; then
        echo -e "${YELLOW}  未检测到 flathub 远程。${RESET}"
        if ! prompt_yes_no "  是否添加 flathub? [Y/n] "; then
            echo -e "  - 跳过，Flatpak 源将不可用"
            return
        fi
        echo -e "  正在添加 flathub 远程（网络不可达时最多等待 45 秒）..."
        if timeout 45s sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
            echo -e "  ${GREEN}✓${RESET} flathub 远程已添加"
            return
        fi

        echo -e "${YELLOW}  flathub 添加失败或超时，已跳过。Pacman/AUR 功能仍可正常使用。${RESET}"
        echo -e "  可稍后手动执行：sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    fi
}

# --- 自动安装 downgrade (pacd 依赖) ---
install_downgrade() {
    echo -e "${YELLOW}  未检测到 downgrade (pacd 降级功能依赖)。${RESET}"
    if ! prompt_yes_no "  是否通过 AUR 安装 downgrade? [Y/n] "; then
        echo -e "  - 跳过，pacd 将无法使用"
        return 1
    fi

    # downgrade 在 AUR，需要 AUR 助手
    local helper=""
    if command -v paru >/dev/null 2>&1; then
        helper="paru"
    elif command -v yay >/dev/null 2>&1; then
        helper="yay"
    else
        echo -e "${RED}  未找到 AUR 助手，无法安装 downgrade。${RESET}"
        return 1
    fi

    echo -e "  正在通过 $helper 安装 downgrade..."
    if $helper -S --noconfirm downgrade; then
        echo -e "  ${GREEN}✓${RESET} downgrade 已安装"
        return 0
    fi
    echo -e "${RED}  downgrade 安装失败。${RESET}"
    return 1
}

# --- 1. 检查并安装核心依赖 ---
echo -e "${CYAN}[1/5]${RESET} 检查核心依赖..."
if ! command -v fzf >/dev/null 2>&1; then
    install_fzf
else
    echo -e "  ${GREEN}✓${RESET} fzf 已安装"
fi
echo ""

# --- 2. 检查并安装 AUR 助手 ---
echo -e "${CYAN}[2/5]${RESET} 检查 AUR 助手..."
if command -v paru >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} paru 已安装"
elif command -v yay >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} yay 已安装"
else
    install_paru || true
fi
echo ""

# --- 3. 检查并安装可选依赖 flatpak ---
echo -e "${CYAN}[3/5]${RESET} 检查可选依赖 flatpak..."
if command -v flatpak >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} flatpak 已安装"
    setup_flathub
else
    if install_flatpak; then
        setup_flathub
    fi
fi
echo ""

# --- 4. 检查并安装可选依赖 downgrade ---
echo -e "${CYAN}[4/5]${RESET} 检查可选依赖 downgrade (pacd 降级)..."
if command -v downgrade >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} downgrade 已安装"
else
    install_downgrade || true
fi
echo ""

# --- 5. 安装脚本与提示词 ---
echo -e "${CYAN}[5/5]${RESET} 安装 pack / pacr / pacd 到 ${BIN_DIR}..."

# 如果通过 curl | bash 运行，需要先下载脚本文件
RAW_BASE="https://raw.githubusercontent.com/tingfeng347/archtools/main"
if [[ ! -f "$SCRIPT_DIR/bin/pack" ]] || [[ ! -f "$SCRIPT_DIR/bin/pacr" ]] || [[ ! -f "$SCRIPT_DIR/bin/pacd" ]]; then
    TMPDIR="$(mktemp -d)"
    mkdir -p "$TMPDIR/bin" "$TMPDIR/share/prompts"
    echo -e "  正在下载脚本..."
    curl -fsSL "$RAW_BASE/bin/pack" -o "$TMPDIR/bin/pack"
    curl -fsSL "$RAW_BASE/bin/pacr" -o "$TMPDIR/bin/pacr"
    curl -fsSL "$RAW_BASE/bin/pacd" -o "$TMPDIR/bin/pacd"
    curl -fsSL "$RAW_BASE/share/prompts/aur-review.md" -o "$TMPDIR/share/prompts/aur-review.md"
    SCRIPT_DIR="$TMPDIR"
fi

sudo cp "$SCRIPT_DIR/bin/pack" "$BIN_DIR/pack"
sudo cp "$SCRIPT_DIR/bin/pacr" "$BIN_DIR/pacr"
sudo cp "$SCRIPT_DIR/bin/pacd" "$BIN_DIR/pacd"
sudo chmod +x "$BIN_DIR/pack" "$BIN_DIR/pacr" "$BIN_DIR/pacd"

# 安装 AUR 审查提示词到 /usr/share/archtools/prompts/
sudo mkdir -p "$SHARE_DIR/prompts"
if [[ -f "$SCRIPT_DIR/share/prompts/aur-review.md" ]]; then
    sudo cp "$SCRIPT_DIR/share/prompts/aur-review.md" "$SHARE_DIR/prompts/aur-review.md"
    echo -e "  ${GREEN}✓${RESET} AUR 审查提示词已安装到 $SHARE_DIR/prompts/"
fi

# 清理临时目录
if [[ -n "${TMPDIR:-}" ]]; then
    rm -rf "$TMPDIR"
fi

echo -e "  ${GREEN}✓${RESET} 已安装"

# --- 初始化缓存 ---
echo ""
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/pac_tui"
echo -e "  ${GREEN}✓${RESET} 缓存目录已创建"

# --- 完成 ---
echo ""
echo -e "${GREEN}========================================${RESET}"
echo -e "${GREEN}  安装完成！${RESET}"
echo -e "${GREEN}========================================${RESET}"
echo ""
echo -e "用法:"
echo -e "  ${CYAN}pack${RESET}           # 搜索并安装软件包 (Pacman+AUR+Flatpak)"
echo -e "  ${CYAN}pack firefox${RESET}   # 搜索 firefox"
echo -e "  ${CYAN}pack -e firefox${RESET} # 精确匹配"
echo -e "  ${CYAN}pack -c${RESET}        # 仅审查 AUR 包，不安装"
echo ""
echo -e "  ${CYAN}pacr${RESET}           # 搜索并卸载软件包"
echo -e "  ${CYAN}pacr firefox${RESET}   # 搜索并卸载 firefox"
echo ""
echo -e "  ${CYAN}pacd${RESET}           # 搜索并降级已安装包"
echo -e "  ${CYAN}pacd linux${RESET}     # 搜索并降级 linux"
echo ""
echo -e "热键:"
echo -e "  ${CYAN}Tab${RESET}  多选  ${CYAN}Enter${RESET} 确认  ${CYAN}Ctrl+R${RESET} 刷新  ${CYAN}Ctrl+E${RESET} 精确/模糊  ${CYAN}Esc${RESET} 退出"
