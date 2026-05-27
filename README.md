# Hillstone Secure Connect — Arch Linux 一键安装

在 **Arch / Garuda / Manjaro** 上安装山石 **Hillstone Secure Connect** 官方 Linux 客户端，并自动处理常见坑：

| 问题 | 处理 |
|------|------|
| 安装器不认 Garuda/Arch | 临时伪装 `Ubuntu 20.04` |
| 安装到 99% 失败 | 安装包复制到 `/tmp`（root 读不了 `~/下载`） |
| 虚拟网卡 `Operation not permitted` | systemd **root** 后台 + TUN |
| 服务秒退 / `MAINPID` 为空 | `daemon()` 双 fork + **PIDFile** |
| `pgrep` 找不到进程 | 用完整路径匹配（comm 仅 15 字符） |
| Qt `xcb` / 库冲突 | 启动器设置 `LD_LIBRARY_PATH` / `QT_PLUGIN_PATH` |

> **说明**：本仓库不含官方 `.run`；`install.sh` 会自动 **wget** 下载，也可手动下载。

## 一键安装

**方式 A（自动下载 + 安装）**

```bash
curl -fsSL https://raw.githubusercontent.com/meetorion/hillstone-arch/main/install.sh | bash
```

若安装包不在默认路径，指定文件：

```bash
curl -fsSL https://raw.githubusercontent.com/meetorion/hillstone-arch/main/install.sh | bash -s -- "$HOME/下载/HillstoneSecureConnect_5.7.1.12488_c5c25286.run"
```

或克隆后本地安装：

```bash
git clone https://github.com/meetorion/hillstone-arch.git
cd hillstone-arch
./install.sh ~/下载/HillstoneSecureConnect_*.run
```

## 仅用 wget 下载 Linux 安装包

官网按钮对应 API（非页面直链），需带 `Referer` 与浏览器 `User-Agent`：

```bash
wget -c -O ~/下载/HillstoneSecureConnect.run \
  'https://images.hillstonenet.com/api/Sslvpn/download?id=96252&cid=4379' \
  --user-agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' \
  --referer='https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/'
```

校验 MD5（官网 Linux 5.7.1.12488）：`a3de7aeefb19b3997b2e4da8fa7490f7`

或使用仓库脚本（会从下载页自动解析 API，失败则用默认 id/cid）：

```bash
git clone https://github.com/meetorion/hillstone-arch.git
./hillstone-arch/scripts/download-installer.sh ~/下载/HillstoneSecureConnect.run
```

版本更新后 `id`/`cid` 可能变化，以[下载页](https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/) HTML 中 `software_disclaimer_linux` 旁的链接为准。

## 使用

```bash
hillstone-secure-connect          # 启动 GUI
sudo hillstone-fix-vnic           # 仅修复虚拟网卡 / systemd 服务
systemctl status HillstoneSecureConnect.service
```

安装路径：`/opt/HillstoneSecureConnect`（官方默认）

## 环境变量

| 变量 | 说明 |
|------|------|
| `HILLSTONE_SC_REPO` | 脚本仓库 Git URL（curl 管道安装时） |
| `HILLSTONE_SC_REPO_DIR` | 本地仓库路径 |
| `HILLSTONE_SC_SHARE` | 安装到系统的 share 目录，默认 `/usr/share/hillstone-arch` |

## 故障排查

**后台服务未运行**

```bash
sudo hillstone-fix-vnic
journalctl -u HillstoneSecureConnect.service -n 30 --no-pager
pgrep -af /opt/HillstoneSecureConnect/bin/HillstoneSecureConnectService
```

**仅 GUI 能开、连不上 VPN**

- 确认后台进程用户为 `root`，不是当前登录用户
- 查看 `/tmp/HillstoneSecureConnect/log/secureconnect.log` 是否有 `Set up the vnic[type 3] successfully`

**Wayland 下界面异常**

启动器会自动设置 `QT_QPA_PLATFORM=xcb`；仍异常时在 X11 会话下试一次。

## 卸载

```bash
sudo systemctl disable --now HillstoneSecureConnect.service
sudo rm -f /etc/systemd/system/HillstoneSecureConnect.service
sudo systemctl daemon-reload
sudo rm -rf /opt/HillstoneSecureConnect
sudo rm -rf /usr/share/hillstone-arch
sudo rm -f /usr/local/bin/hillstone-secure-connect /usr/local/bin/hillstone-fix-vnic
sudo rm -f /usr/share/applications/hillstone-secure-connect.desktop
```

官方若提供 MaintenanceTool，也可在 `/opt/HillstoneSecureConnect` 下运行卸载向导。

## 仓库结构

```
install.sh                 # 一键入口
scripts/
  common.sh                # 公共函数
  install-gui.sh           # 伪装 Ubuntu + /tmp 安装
  fix-vnic.sh              # systemd + 虚拟网卡
bin/
  hillstone-secure-connect # 启动器
  hillstone-fix-vnic       # 修复命令入口
```

## 许可

MIT — 山石客户端本身版权归 Hillstone Networks，请遵守官网许可协议。
