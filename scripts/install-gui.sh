#!/bin/sh
# Garuda/Arch：伪装 Ubuntu + /tmp 安装 + 可选无人值守
set -eu

. "$(dirname "$0")/common.sh"

SRC="${1:-}"
if [ -z "$SRC" ]; then
    SRC=$(hillstone_find_installer) || true
fi
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
    echo "用法: $0 <官方安装包.run>" >&2
    exit 1
fi

INSTALLER="/tmp/HillstoneSecureConnect-installer.run"
echo "==> 复制安装包到 $INSTALLER"
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

echo "==> 临时伪装为 Ubuntu 20.04..."
sudo cp -a "$OS_REAL" "$BACKUP"
sudo cp "$FAKE" "$OS_REAL"

if [ -d "$HILLSTONE_OPT" ] && [ ! -x "$HILLSTONE_GUI" ]; then
    echo "==> 清理上次失败的半成品..."
    sudo rm -rf "$HILLSTONE_OPT"
fi

run_unattended() {
    echo "==> 无人值守安装（Qt --confirm-command install）..."
    if sudo env QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-minimal}" \
        "$INSTALLER" --confirm-command install; then
        return 0
    fi
    return 1
}

run_gui() {
    cat <<EOF

========================================
  图形安装向导
========================================
• 安装包: $INSTALLER
• 目标路径请保持默认: $HILLSTONE_OPT
• 安装过程中需要输入 sudo 密码
========================================

EOF
    "$INSTALLER"
}

INSTALL_EXIT=0
if [ "${HILLSTONE_UNATTENDED:-0}" = 1 ]; then
    run_unattended || INSTALL_EXIT=$?
    if [ "$INSTALL_EXIT" -ne 0 ] || ! hillstone_is_installed; then
        echo "警告: 无人值守未成功，改用图形安装向导..." >&2
        run_gui || INSTALL_EXIT=$?
    fi
else
    run_gui || INSTALL_EXIT=$?
fi

restore_os
trap - EXIT INT TERM

if hillstone_is_installed; then
    echo "==> 官方客户端安装成功: $HILLSTONE_GUI"
    exit 0
fi

echo "安装未完成，请查看上方错误。" >&2
exit "${INSTALL_EXIT:-1}"
