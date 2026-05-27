#!/bin/sh
# 从山石官网 API 用 wget/curl 下载 Linux 安装包
set -eu

. "$(dirname "$0")/common.sh"

UA="${HILLSTONE_UA:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36}"
REFERER="${HILLSTONE_REFERER:-https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/}"
PAGE_URL="${HILLSTONE_PAGE_URL:-https://www.hillstonenet.com.cn/support-and-training/hillstone-secure-connect/}"
LINUX_API_ID="${HILLSTONE_LINUX_API_ID:-96252}"
LINUX_API_CID="${HILLSTONE_LINUX_API_CID:-4379}"
EXPECTED_MD5="${HILLSTONE_LINUX_MD5:-a3de7aeefb19b3997b2e4da8fa7490f7}"

DEST="${1:-$HOME/下载/HillstoneSecureConnect_linux.run}"
mkdir -p "$(dirname "$DEST")"

resolve_api_url() {
    if [ -n "${HILLSTONE_DOWNLOAD_URL:-}" ]; then
        printf '%s\n' "$HILLSTONE_DOWNLOAD_URL"
        return
    fi
    tmp=$(mktemp)
    if curl -fsSL "$PAGE_URL" -H "User-Agent: $UA" -o "$tmp" 2>/dev/null; then
        url=$(python3 - "$tmp" <<'PY'
import re, sys
html = open(sys.argv[1], errors="replace").read()
pat = re.compile(r'https://images\.hillstonenet\.com/api/Sslvpn/download\?id=\d+&cid=\d+')
for m in pat.finditer(html):
    ctx = html[max(0, m.start() - 600): m.end() + 100]
    if "software_disclaimer_linux" in ctx:
        print(m.group())
        break
PY
)
        rm -f "$tmp"
        if [ -n "$url" ]; then
            printf '%s\n' "$url"
            return
        fi
    fi
  rm -f "$tmp" 2>/dev/null || true
    printf '%s\n' "https://images.hillstonenet.com/api/Sslvpn/download?id=${LINUX_API_ID}&cid=${LINUX_API_CID}"
}

api_url=$(resolve_api_url)
echo "==> 下载: $api_url"
echo "==> 保存: $DEST"

if command -v wget >/dev/null 2>&1; then
    wget -c -O "$DEST" "$api_url" \
        --user-agent="$UA" \
        --referer="$REFERER"
else
    command -v curl >/dev/null || { echo "需要 wget 或 curl" >&2; exit 1; }
    curl -fL -o "$DEST" "$api_url" \
        -H "User-Agent: $UA" \
        -H "Referer: $REFERER"
fi

chmod +x "$DEST"

if [ -n "$EXPECTED_MD5" ] && command -v md5sum >/dev/null; then
    got=$(md5sum "$DEST" | awk '{print $1}')
    if [ "$got" = "$EXPECTED_MD5" ]; then
        echo "==> MD5 与官网一致"
    else
        echo "警告: MD5 与脚本记录不一致（可能官网已更新版本）" >&2
        echo "  记录: $EXPECTED_MD5" >&2
        echo "  实际: $got" >&2
    fi
fi

echo "==> 完成 ($(du -h "$DEST" | awk '{print $1}'))"
