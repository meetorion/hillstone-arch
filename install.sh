#!/usr/bin/env bash
# Hillstone Secure Connect — Arch / Garuda 一键安装
# 用法:
#   ./install.sh [官方安装包.run]
#   curl -fsSL https://raw.githubusercontent.com/meetorion/hillstone-arch/main/install.sh | bash
#   curl -fsSL ... | bash -s -- /path/to/HillstoneSecureConnect_*.run
set -euo pipefail

REPO_URL="${HILLSTONE_SC_REPO:-https://github.com/meetorion/hillstone-arch.git}"
BRANCH="${HILLSTONE_SC_BRANCH:-main}"
SHARE="${HILLSTONE_SC_SHARE:-/usr/share/hillstone-arch}"
BINDIR="${HILLSTONE_SC_BINDIR:-/usr/local/bin}"
INSTALLER_ARG="${1:-}"

log() { printf '==> %s\n' "$*"; }
die() { printf '错误: %s\n' "$*" >&2; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

resolve_repo_dir() {
    if [ -n "${HILLSTONE_SC_REPO_DIR:-}" ] && [ -f "$HILLSTONE_SC_REPO_DIR/scripts/common.sh" ]; then
        printf '%s\n' "$HILLSTONE_SC_REPO_DIR"
        return
    fi
    local src
    src=$(readlink -f "${BASH_SOURCE[0]}") 2>/dev/null || src="${BASH_SOURCE[0]}"
    local dir
    dir=$(CDPATH= cd "$(dirname "$src")" && pwd)
    if [ -f "$dir/scripts/common.sh" ]; then
        printf '%s\n' "$dir"
        return
    fi
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    log "下载安装脚本仓库..."
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$tmp"
    else
        die "需要 git。请: git clone $REPO_URL && cd hillstone-arch && ./install.sh"
    fi
    HILLSTONE_SC_REPO_DIR=$tmp
    trap - EXIT
    printf '%s\n' "$tmp"
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
            die "本脚本仅测试于 Arch / Garuda / Manjaro。当前: ${PRETTY_NAME:-unknown}"
            ;;
    esac
}

install_deps() {
    log "安装系统依赖..."
    if ! command -v pacman >/dev/null; then
        die "需要 pacman"
    fi
    sudo pacman -Sy --needed --noconfirm \
        git \
        libxcb \
        libxkbcommon-x11 \
        xcb-util-cursor \
        icu \
        systemd \
        iproute2 \
        2>/dev/null || sudo pacman -Sy --needed \
        git libxcb libxkbcommon-x11 xcb-util-cursor icu systemd iproute2
}

install_scripts() {
    log "安装命令到 $BINDIR ..."
    sudo install -d -m 755 "$SHARE/scripts" "$SHARE/bin"
    sudo cp -a "$REPO_DIR/scripts/"* "$SHARE/scripts/"
    sudo cp -a "$REPO_DIR/bin/"* "$SHARE/bin/"
    sudo chmod 755 "$SHARE/scripts/"*.sh "$SHARE/bin/"*
    for cmd in hillstone-secure-connect hillstone-fix-vnic; do
        sudo ln -sf "$SHARE/bin/$cmd" "$BINDIR/$cmd"
    done
    export HILLSTONE_SC_SHARE="$SHARE"
}

find_installer() {
    if [ -n "$INSTALLER_ARG" ] && [ -f "$INSTALLER_ARG" ]; then
        printf '%s\n' "$(readlink -f "$INSTALLER_ARG")"
        return
    fi
    # shellcheck source=/dev/null
    . "$REPO_DIR/scripts/common.sh"
    hillstone_find_installer || return 1
}

run_official_installer() {
    local installer
    installer=$(find_installer) || die "未找到安装包。请:
  1. 从官网下载 Linux .run 安装包
     https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/
  2. 重新运行: ./install.sh ~/下载/HillstoneSecureConnect_*.run"

    log "使用安装包: $installer"
    bash "$REPO_DIR/scripts/install-gui.sh" "$installer"
}

post_install() {
    log "配置虚拟网卡后台服务 (systemd)..."
    sudo env HILLSTONE_SC_SHARE="$SHARE" "$SHARE/scripts/fix-vnic.sh"

    if [ -f /opt/HillstoneSecureConnect/HillstoneSecureConnect.desktop ]; then
        HILLSTONE_OPT=/opt/HillstoneSecureConnect
        sudo install -D -m 644 \
            "$HILLSTONE_OPT/HillstoneSecureConnect.desktop" \
            /usr/share/applications/hillstone-secure-connect.desktop
        sudo sed -i "s|^Exec=.*|Exec=$BINDIR/hillstone-secure-connect|" \
            /usr/share/applications/hillstone-secure-connect.desktop 2>/dev/null || true
    fi
}

main() {
    check_os
    need_cmd sudo
    need_cmd bash

    REPO_DIR=$(resolve_repo_dir)
    # shellcheck source=/dev/null
    . "$REPO_DIR/scripts/common.sh"

    if hillstone_is_installed; then
        log "检测到已安装 $HILLSTONE_GUI"
        if [ ! -t 0 ]; then
            log "非交互模式：仅更新脚本与 systemd 服务"
            install_deps
            install_scripts
            post_install
            finish
            exit 0
        fi
        read -r -p "是否重新运行官方安装包? [y/N] " ans || true
        case "${ans:-N}" in
            y|Y|yes|Yes) ;;
            *)
                install_deps
                install_scripts
                post_install
                finish
                exit 0
                ;;
        esac
    fi

    install_deps
    install_scripts
    run_official_installer
    post_install
    finish
}

finish() {
    cat <<EOF

========================================
  安装完成
========================================
启动客户端:
  hillstone-secure-connect

检查后台服务 (应为 root):
  systemctl status HillstoneSecureConnect.service
  pgrep -af /opt/HillstoneSecureConnect/bin/HillstoneSecureConnectService

若虚拟网卡仍失败:
  sudo hillstone-fix-vnic

日志:
  /tmp/HillstoneSecureConnect/log/secureconnect.log
========================================
EOF
}

main "$@"
