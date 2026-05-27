# shellcheck shell=sh
# 公共变量与函数（被其他脚本 source）

HILLSTONE_OPT=/opt/HillstoneSecureConnect
HILLSTONE_SVC="$HILLSTONE_OPT/bin/HillstoneSecureConnectService"
HILLSTONE_GUI="$HILLSTONE_OPT/bin/HillstoneSecureConnect"
HILLSTONE_IPC_DIR=/tmp/HillstoneSecureConnect
HILLSTONE_PIDFILE=/run/HillstoneSecureConnect/service.pid

# Linux TASK_COMM_LEN=16，进程名会被截断，不能用 pgrep -x HillstoneSecureConnectService
hillstone_svc_pgrep() {
    pgrep -f "$HILLSTONE_SVC" 2>/dev/null | head -1
}

hillstone_is_installed() {
    [ -x "$HILLSTONE_GUI" ] && [ -f "$HILLSTONE_OPT/lib/libQt5Core.so.5" ]
}

hillstone_find_installer() {
    if [ -n "${1:-}" ] && [ -f "$1" ]; then
        printf '%s\n' "$1"
        return 0
    fi
    # shellcheck disable=SC2086
    set -- \
        "$HOME/下载"/HillstoneSecureConnect_*.run \
        "$HOME/Downloads"/HillstoneSecureConnect_*.run \
        "$PWD"/HillstoneSecureConnect_*.run
    for f in "$@"; do
        [ -f "$f" ] || continue
        printf '%s\n' "$f"
        return 0
    done
    return 1
}
