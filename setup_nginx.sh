#!/usr/bin/env bash
# ==============================================================================
# Nitter Nginx 一键反代配置辅助脚本 (通用版)
# ==============================================================================
set -euo pipefail

CONF_FILE="${HOME}/nitter/nitter.conf"
DOMAIN="${1:-}"

# 优先从本机的 nitter.conf 中动态读取配置的域名
if [ -z "$DOMAIN" ] && [ -f "$CONF_FILE" ]; then
    DOMAIN="$(grep -E "^hostname = " "$CONF_FILE" | sed -E 's/hostname = "([^"]+)"/\1/' | head -n 1)"
fi

if [ -z "$DOMAIN" ] || [ "$DOMAIN" == "localhost" ]; then
    echo "[ERROR] 未能从 ~/nitter/nitter.conf 中自动检测到绑定的域名。"
    echo "请手动传入域名参数执行，例如: bash setup_nginx.sh nitter.yourdomain.com"
    exit 1
fi

echo "[INFO] 自动检测到本地绑定域名: ${DOMAIN}"
echo "[INFO] 正在为 ${DOMAIN} 配置 Nginx 反向代理..."

mkdir -p /etc/nginx/conf.d

TARGET_CONF="/etc/nginx/conf.d/nitter.conf"
if [ -d "/etc/nginx/sites-enabled" ]; then
    TARGET_CONF="/etc/nginx/sites-enabled/nitter.conf"
fi

cat << EOF > "$TARGET_CONF"
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_buffering off;
    }
}
EOF

echo "[INFO] 验证 Nginx 配置并重载服务..."
nginx -t
systemctl reload nginx || nginx -s reload

echo "[OK] Nginx 反向代理配置完成！现在可直接访问 https://${DOMAIN}"
