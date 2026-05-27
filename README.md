# hillstone-arch

在 **Arch Linux / Garuda / Manjaro** 上一键完成：**从山石官网下载** → **安装 Hillstone Secure Connect** → **配置 systemd 虚拟网卡**。

无需事先下载 `.run`，无需手动改 `os-release`，一条命令即可使用。

## 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/meetorion/hillstone-arch/main/install.sh | bash
```

执行过程中会提示输入 **sudo 密码**（安装依赖、伪装 Ubuntu、写入 `/opt`、配置服务）。

完成后启动：

```bash
hillstone-secure-connect
```

### 脚本会自动完成的步骤

| 步骤 | 说明 |
|------|------|
| 1 | `pacman` 安装 `wget` `curl` `python` 等依赖 |
| 2 | 安装 `hillstone-secure-connect` / `hillstone-fix-vnic` 到 `/usr/local/bin` |
| 3 | 从官网 API **wget 下载** Linux 安装包（约 47MB） |
| 4 | 临时伪装 **Ubuntu 20.04**，复制包到 `/tmp`，**无人值守**安装到 `/opt` |
| 5 | 配置 **systemd root 后台**，修复虚拟网卡 |

### 已有本地安装包时

```bash
curl -fsSL https://raw.githubusercontent.com/meetorion/hillstone-arch/main/install.sh | bash -s -- "$HOME/下载/HillstoneSecureConnect_*.run"
```

或克隆仓库：

```bash
git clone https://github.com/meetorion/hillstone-arch.git
cd hillstone-arch
./install.sh
```

跳过自动下载、强制图形安装向导：

```bash
HILLSTONE_SKIP_DOWNLOAD=1 HILLSTONE_UNATTENDED=0 ./install.sh ~/下载/HillstoneSecureConnect_*.run
```

## 已修复的问题

| 现象 | 处理 |
|------|------|
| 安装器不认 Garuda/Arch | 临时伪装 `Ubuntu 20.04` |
| 安装到 99% 失败 | 安装包复制到 `/tmp`（root 读不了 `~/下载`） |
| 虚拟网卡 `Operation not permitted` | systemd **root** 后台 |
| 服务秒退 / `MAINPID` 为空 | `daemon()` + **PIDFile** |
| `pgrep` 找不到进程 | 按完整路径匹配（comm 仅 15 字符） |
| Qt xcb / 库冲突 | 启动器设置 bundled Qt 路径 |

## 常用命令

```bash
hillstone-secure-connect                    # 启动客户端
sudo hillstone-fix-vnic                     # 仅修复虚拟网卡服务
systemctl status HillstoneSecureConnect.service
pgrep -af /opt/HillstoneSecureConnect/bin/HillstoneSecureConnectService
```

安装路径：`/opt/HillstoneSecureConnect`

## 仅下载安装包

```bash
git clone https://github.com/meetorion/hillstone-arch.git
./hillstone-arch/scripts/download-installer.sh ~/下载/HillstoneSecureConnect.run
```

或手动 wget（Linux 5.7.1.12488，[官网](https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/)）：

```bash
wget -c -O ~/下载/HillstoneSecureConnect.run \
  'https://images.hillstonenet.com/api/Sslvpn/download?id=96252&cid=4379' \
  --user-agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' \
  --referer='https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/'
```

MD5：`a3de7aeefb19b3997b2e4da8fa7490f7`（版本更新后可能变化）

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HILLSTONE_UNATTENDED` | 管道安装时为 `1` | `1` 尝试无人值守安装 |
| `HILLSTONE_SKIP_DOWNLOAD` | `0` | `1` 不自动 wget，须自备 `.run` |
| `HILLSTONE_INSTALLER_CACHE` | `~/下载/HillstoneSecureConnect_linux.run` | 下载保存路径 |
| `HILLSTONE_LINUX_MD5` | 官网当前 MD5 | 下载后校验 |
| `HILLSTONE_SC_ARCHIVE` | GitHub `main.tar.gz` | 管道安装时拉取脚本 |

## 故障排查

**后台不是 root / 虚拟网卡失败**

```bash
sudo hillstone-fix-vnic
journalctl -u HillstoneSecureConnect.service -n 30 --no-pager
```

**无人值守安装失败**

脚本会自动回退到图形向导；或手动：

```bash
HILLSTONE_UNATTENDED=0 ./install.sh
```

**日志**

`/tmp/HillstoneSecureConnect/log/secureconnect.log`

## 卸载

```bash
sudo systemctl disable --now HillstoneSecureConnect.service
sudo rm -f /etc/systemd/system/HillstoneSecureConnect.service
sudo systemctl daemon-reload
sudo rm -rf /opt/HillstoneSecureConnect /usr/share/hillstone-arch
sudo rm -f /usr/local/bin/hillstone-secure-connect /usr/local/bin/hillstone-fix-vnic
sudo rm -f /usr/share/applications/hillstone-secure-connect.desktop
```

## 许可

MIT — 山石客户端版权归 Hillstone Networks，请遵守[官网](https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/)许可协议。本仓库不包含官方安装包。
