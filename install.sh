#!/usr/bin/env bash
# Hillstone Secure Connect — Arch / Garuda 一键：官网下载 → 安装 → systemd 虚拟网卡
#
# 一条命令（下载 + 安装 + 配置）:
#   curl -fsSL https://raw.githubusercontent.com/meetorion/hillstone-arch/main/install.sh | bash
#
# 已有本地 .run:
#   curl -fsSL .../install.sh | bash -s -- ~/下载/HillstoneSecureConnect_*.run
set -euo pipefail

REPO_URL="${HILLSTONE_SC_REPO:-https://github.com/meetorion/hillstone-arch.git}"
REPO_ARCHIVE="${HILLSTONE_SC_ARCHIVE:-https://github.com/meetorion/hillstone-arch/archive/refs/heads/main.tar.gz}"
BRANCH="${HILLSTONE_SC_BRANCH:-main}"
SHARE="${HILLSTONE_SC_SHARE:-/usr/share/hillstone-arch}"
BINDIR="${HILLSTONE_SC_BINDIR:-/usr/local/bin}"
INSTALLER_ARG="${1:-}"

# curl | bash 时默认无人值守（无图形安装向导）
if [ ! -t 0 ] && [ -z "${HILLSTONE_UNATTENDED:-}" ]; then
    export HILLSTONE_UNATTENDED=1
fi

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m警告:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m错误:\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

fetch_repo_archive() {
    local tmp dest
    tmp=$(mktemp -d)
    log "从 GitHub 获取安装脚本..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$REPO_ARCHIVE" | tar xz -C "$tmp"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$REPO_ARCHIVE" | tar xz -C "$tmp"
    else
        rm -rf "$tmp"
        return 1
    fi
    dest=$(find "$tmp" -maxdepth 1 -type d -name 'hillstone-arch-*' | head -1)
    if [ -z "$dest" ] || [ ! -f "$dest/scripts/common.sh" ]; then
        rm -rf "$tmp"
        return 1
    fi
    # 移到固定路径，删掉外层临时目录壳
    mv "$dest" "${tmp}/repo"
    printf '%s\n' "${tmp}/repo"
}

resolve_repo_dir() {
    if [ -n "${HILLSTONE_SC_REPO_DIR:-}" ] && [ -f "$HILLSTONE_SC_REPO_DIR/scripts/common.sh" ]; then
        printf '%s\n' "$HILLSTONE_SC_REPO_DIR"
        return
    fi
    local src dir
    src="${BASH_SOURCE[0]:-$0}"
    if [ -n "$src" ] && [ -f "$src" ]; then
        dir=$(CDPATH= cd "$(dirname "$src")" && pwd)
        if [ -f "$dir/scripts/common.sh" ]; then
            printf '%s\n' "$dir"
            return
        fi
    fi
    if fetched=$(fetch_repo_archive); then
        HILLSTONE_SC_REPO_DIR=$fetched
        printf '%s\n' "$fetched"
        return
    fi
    if command -v git >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp -d)
        log "使用 git 克隆仓库..."
        git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$tmp"
        printf '%s\n' "$tmp"
        return
    fi
    die "无法获取安装脚本。请安装 curl 或 git 后重试，或 git clone $REPO_URL"
}

check_os() {
    [ -f /etc/os-release ] || die "无法识别系统"
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
        arch:*|*:arch*) ;;
        garuda:arch*) ;;
        manjaro:arch*) ;;
        endeavouros:arch*) ;;
        *)
            die "本脚本仅适用于 Arch / Garuda / Manjaro。当前: ${PRETTY_NAME:-unknown}"
            ;;
    esac
}

install_deps() {
    log "[1/5] 安装系统依赖 (pacman)..."
    command -v pacman >/dev/null || die "需要 pacman"
    sudo pacman -Sy --needed --noconfirm \
        wget curl python \
        libxcb libxkbcommon-x11 xcb-util-cursor \
        icu systemd iproute2 \
        2>/dev/null || sudo pacman -Sy --needed \
        wget curl python libxcb libxkbcommon-x11 xcb-util-cursor icu systemd iproute2
}

install_scripts() {
    log "[2/5] 安装命令到 $BINDIR ..."
    sudo install -d -m 755 "$SHARE/scripts" "$SHARE/bin"
    sudo cp -a "$REPO_DIR/scripts/"* "$SHARE/scripts/"
    sudo cp -a "$REPO_DIR/bin/"* "$SHARE/bin/"
    sudo chmod 755 "$SHARE/scripts/"*.sh "$SHARE/bin/"*
    for cmd in hillstone-secure-connect hillstone-fix-vnic; do
        sudo ln -sf "$SHARE/bin/$cmd" "$BINDIR/$cmd"
    done
    export HILLSTONE_SC_SHARE="$SHARE"
}

download_installer() {
    local dest="${HILLSTONE_INSTALLER_CACHE:-$HOME/下载/HillstoneSecureConnect_linux.run}"
    mkdir -p "$(dirname "$dest")"
    log "[3/5] 从山石官网下载 Linux 安装包 (~47MB)..."
    bash "$REPO_DIR/scripts/download-installer.sh" "$dest"
    printf '%s\n' "$dest"
}

find_installer() {
    if [ -n "$INSTALLER_ARG" ] && [ -f "$INSTALLER_ARG" ]; then
        printf '%s\n' "$(readlink -f "$INSTALLER_ARG")"
        return
    fi
    # shellcheck source=/dev/null
    . "$REPO_DIR/scripts/common.sh"
    if hillstone_find_installer; then
        return
    fi
    if [ "${HILLSTONE_SKIP_DOWNLOAD:-0}" = 1 ]; then
        return 1
    fi
    download_installer
}

run_official_installer() {
    local installer
    installer=$(find_installer) || die "无法获得安装包。请检查网络，或:
  HILLSTONE_SKIP_DOWNLOAD=1 ./install.sh ~/path/HillstoneSecureConnect_*.run"

    log "[4/5] 安装官方客户端到 /opt/HillstoneSecureConnect ..."
    log "使用安装包: $installer"
    export HILLSTONE_UNATTENDED="${HILLSTONE_UNATTENDED:-0}"
    bash "$REPO_DIR/scripts/install-gui.sh" "$installer"
}

post_install() {
    log "[5/5] 配置虚拟网卡后台服务 (systemd)..."
    sudo env HILLSTONE_SC_SHARE="$SHARE" "$SHARE/scripts/fix-vnic.sh"

    if [ -f /opt/HillstoneSecureConnect/HillstoneSecureConnect.desktop ]; then
        sudo install -D -m 644 \
            /opt/HillstoneSecureConnect/HillstoneSecureConnect.desktop \
            /usr/share/applications/hillstone-secure-connect.desktop
        sudo sed -i "s|^Exec=.*|Exec=$BINDIR/hillstone-secure-connect|" \
            /usr/share/applications/hillstone-secure-connect.desktop 2>/dev/null || true
    fi
}

maybe_skip_full_install() {
    # shellcheck source=/dev/null
    . "$REPO_DIR/scripts/common.sh"
    if ! hillstone_is_installed; then
        return 1
    fi
    log "检测到已安装: $HILLSTONE_GUI"
    if [ ! -t 0 ]; then
        log "非交互模式：跳过官方安装包，仅更新脚本与服务"
        install_scripts
        post_install
        finish
        exit 0
    fi
    read -r -p "已安装。是否重新运行官方安装包? [y/N] " ans || true
    case "${ans:-N}" in
        y|Y|yes|Yes) return 1 ;;
        *)
            install_scripts
            post_install
            finish
            exit 0
            ;;
    esac
}

main() {
    echo ""
    echo "========================================"
    echo "  Hillstone Secure Connect — Arch 一键安装"
    echo "========================================"
    echo ""

    check_os
    need_cmd sudo
    need_cmd bash

    REPO_DIR=$(resolve_repo_dir)
    export HILLSTONE_SC_REPO_DIR="$REPO_DIR"

    install_deps
    install_scripts

    maybe_skip_full_install || true

    run_official_installer
    post_install
    finish
}

finish() {
    cat <<'EOF'

========================================
  全部完成
========================================
启动 VPN 客户端:
  hillstone-secure-connect

检查后台 (进程用户应为 root):
  systemctl status HillstoneSecureConnect.service

虚拟网卡异常时:
  sudo hillstone-fix-vnic
========================================
EOF
}

main "$@"
