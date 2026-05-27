#!/bin/sh
# 修复「虚拟网卡安装失败」：后台服务必须以 root 运行；修正 systemd + daemon 双 fork
set -eu

. "$(dirname "$0")/common.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 sudo 运行: sudo hillstone-fix-vnic" >&2
    exit 1
fi

echo "==> 停止旧进程（用户态后台无法创建 TUN）..."
systemctl stop HillstoneSecureConnect.service 2>/dev/null || true
pkill -f "$HILLSTONE_SVC" 2>/dev/null || true
for u in $(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}'); do
    pkill -u "$u" -f "$HILLSTONE_SVC" 2>/dev/null || true
done
sleep 1

echo "==> 准备 IPC 目录..."
mkdir -p "$HILLSTONE_IPC_DIR/log"
chmod 1777 "$HILLSTONE_IPC_DIR" "$HILLSTONE_IPC_DIR/log" 2>/dev/null || true

echo "==> 网络能力（可选）..."
setcap cap_net_admin,cap_net_raw+ep "$HILLSTONE_SVC" 2>/dev/null || true

echo "==> 安装 systemd 启动包装（daemon 双 fork + PIDFile）..."
install -d -m 755 "$HILLSTONE_OPT/scripts"
cat > "$HILLSTONE_OPT/scripts/systemd-start.sh" <<'WRAPPER'
#!/bin/sh
set -eu
HILLSTONE_SVC=/opt/HillstoneSecureConnect/bin/HillstoneSecureConnectService
PIDFILE="/run/HillstoneSecureConnect/service.pid"
mkdir -p /run/HillstoneSecureConnect /tmp/HillstoneSecureConnect/log
chmod 1777 /tmp/HillstoneSecureConnect /tmp/HillstoneSecureConnect/log 2>/dev/null || true
rm -f "$PIDFILE"
"$HILLSTONE_SVC" &
i=0
while [ "$i" -lt 100 ]; do
    pid=$(pgrep -f "$HILLSTONE_SVC" 2>/dev/null | head -1 || true)
    if [ -n "$pid" ]; then
        echo "$pid" > "$PIDFILE"
        exit 0
    fi
    i=$((i + 1))
    sleep 0.1
done
echo "HillstoneSecureConnectService 未在 10s 内启动" >&2
exit 1
WRAPPER
chmod 755 "$HILLSTONE_OPT/scripts/systemd-start.sh"

echo "==> 写入 systemd 单元..."
cat > /etc/systemd/system/HillstoneSecureConnect.service <<EOF
[Unit]
Description=Hillstone Secure Connect Service
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=$HILLSTONE_PIDFILE
RuntimeDirectory=HillstoneSecureConnect
KillMode=process
Restart=on-failure
RestartSec=5
ExecStart=$HILLSTONE_OPT/scripts/systemd-start.sh
ExecStop=/bin/kill -s QUIT \$MAINPID
ExecReload=-/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl reset-failed HillstoneSecureConnect.service 2>/dev/null || true
systemctl enable HillstoneSecureConnect.service
systemctl restart HillstoneSecureConnect.service
sleep 2

if systemctl is-active --quiet HillstoneSecureConnect.service && hillstone_svc_pgrep >/dev/null; then
    echo ""
    echo "后台服务已启动（应为 root）。"
    systemctl status HillstoneSecureConnect.service --no-pager | head -10
    pid=$(hillstone_svc_pgrep)
    ps -o user=,pid=,comm=,args= -p "$pid" 2>/dev/null || true
    exit 0
fi

echo "服务启动失败:" >&2
journalctl -u HillstoneSecureConnect.service -n 25 --no-pager >&2
exit 1
