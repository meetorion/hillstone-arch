#!/bin/sh
# Garuda/Arch：伪装 Ubuntu + 安装包放 /tmp（避免 root 读不了 ~/下载 导致 99% 失败）
set -eu

. "$(dirname "$0")/common.sh"

SRC="${1:-}"
if [ -z "$SRC" ]; then
    SRC=$(hillstone_find_installer) || true
fi
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
    echo "用法: $0 <官方安装包.run>" >&2
    echo "请先从官网下载 Linux 安装包:" >&2
    echo "  https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/" >&2
    exit 1
fi

INSTALLER="/tmp/HillstoneSecureConnect-installer.run"
echo "==> 复制安装包到 $INSTALLER"
echo "    （主目录常为 700 权限，root 无法读 ~/下载，必须在 /tmp）"
cp -f "$SRC" "$INSTALLER"
chmod +x "$INSTALLER"

if [ -L /etc/os-release ]; then
    OS_REAL=$(readlink -f /etc/os-release)
else
    OS_REAL=/etc/os-release
fi
BACKUP="${HOME}/.cache/hillstone-os-release.bak"
FAKE=$(mktemp)

cat > "$FAKE" <<'EOF'
NAME="Ubuntu"
VERSION="20.04.6 LTS (Focal Fossa)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 20.04.6 LTS"
VERSION_ID="20.04"
VERSION_CODENAME=focal
EOF

restore_os() {
    if [ -f "$BACKUP" ]; then
        sudo cp -a "$BACKUP" "$OS_REAL"
        rm -f "$BACKUP"
    fi
    rm -f "$FAKE"
}
trap restore_os EXIT INT TERM

echo "==> 临时伪装为 Ubuntu 20.04（安装器仅认 CentOS/Ubuntu）..."
sudo cp -a "$OS_REAL" "$BACKUP"
sudo cp "$FAKE" "$OS_REAL"

if [ -d "$HILLSTONE_OPT" ] && [ ! -x "$HILLSTONE_GUI" ]; then
    echo "==> 清理上次失败的半成品..."
    sudo rm -rf "$HILLSTONE_OPT"
fi

cat <<EOF

========================================
  山石 Secure Connect 图形安装
========================================
• 安装包: $INSTALLER
• 目标路径: $HILLSTONE_OPT （请保持默认）
• 需要多次输入 sudo 密码

装完后本脚本会自动配置 systemd 虚拟网卡服务。
========================================

EOF

"$INSTALLER"
INSTALL_EXIT=$?

restore_os
trap - EXIT INT TERM

if hillstone_is_installed; then
    echo ""
    echo "官方安装包安装成功。"
    ls -la "$HILLSTONE_GUI"
    exit 0
fi

echo "安装未完成，请查看上方错误。" >&2
exit "${INSTALL_EXIT:-1}"
