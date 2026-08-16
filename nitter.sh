#!/usr/bin/env bash
# ==============================================================================
# Nitter 一键部署与管理脚本 (个人自用 / 机器人插件对接极简版)
# 适用系统: Linux (Debian / Ubuntu / CentOS / Alpine 等)
# ==============================================================================

# 终端样式
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 默认路径
INSTALL_DIR="${HOME}/nitter"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
CONF_FILE="${INSTALL_DIR}/nitter.conf"
SESSIONS_FILE="${INSTALL_DIR}/sessions.jsonl"
SCRIPT_VERSION="3.0.0"

IS_INSTALLING=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup_on_cancel() {
    echo ""
    log_warn "检测到中断信号 (Ctrl+C)"
    if [ "$IS_INSTALLING" -eq 1 ] && [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}部署流程未完成。${NC}"
        read -rp "是否清理安装目录 [${INSTALL_DIR}]？[Y/n]: " do_clean
        case "$do_clean" in
            [nN][oO]|[nN]) log_info "已保留安装目录: ${INSTALL_DIR}" ;;
            *) rm -rf "$INSTALL_DIR"; log_success "已清理临时目录" ;;
        esac
    fi
    echo -e "${CYAN}操作已退出。${NC}"
    exit 0
}
trap cleanup_on_cancel SIGINT SIGTERM

prompt_input() {
    local prompt_msg="$1"
    local default_val="$2"
    local var_name="$3"
    local user_val=""

    while true; do
        if [ -n "$default_val" ]; then
            echo -ne "${BOLD}${prompt_msg}${NC} [默认: ${CYAN}${default_val}${NC}] (输入 ${RED}q${NC} 退出): "
        else
            echo -ne "${BOLD}${prompt_msg}${NC} (输入 ${RED}q${NC} 退出): "
        fi
        read -r user_val

        if [[ "$user_val" == "q" || "$user_val" == "Q" || "$user_val" == "quit" ]]; then
            log_info "用户主动取消操作。"
            exit 0
        fi

        [ -z "$user_val" ] && user_val="$default_val"
        eval "$var_name=\"$user_val\""
        break
    done
}

detect_compose_cmd() {
    if docker compose version &>/dev/null; then
        echo "docker compose"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

detect_arch_image() {
    case "$(uname -m)" in
        x86_64|amd64) echo "zedeus/nitter:latest" ;;
        aarch64|arm64) echo "zedeus/nitter:latest-arm64" ;;
        armv7l|armhf) echo "thejan2009/nitter-docker-armv7" ;;
        *) echo "zedeus/nitter:latest" ;;
    esac
}

check_or_install_docker() {
    if ! command -v docker &>/dev/null; then
        log_warn "未检测到 Docker 环境。"
        echo -ne "是否自动安装 Docker 官方环境？[Y/n] (输入 q 退出): "
        read -r auto_install
        [[ "$auto_install" =~ ^[qQ]$ ]] && exit 0
        if [[ "$auto_install" =~ ^[nN]$ ]]; then
            log_error "请手动安装 Docker 后再运行脚本。"
            exit 1
        fi

        log_info "正在安装 Docker..."
        curl -fsSL https://get.docker.com | bash
        systemctl enable --now docker || true
        log_success "Docker 安装完成"
    fi

    local compose_cmd
    compose_cmd="$(detect_compose_cmd)"
    if [ -z "$compose_cmd" ]; then
        log_warn "正在补充安装 Docker Compose 插件..."
        if command -v apt-get &>/dev/null; then
            apt-get update && apt-get install -y docker-compose-plugin
        elif command -v yum &>/dev/null; then
            yum install -y docker-compose-plugin
        fi
    fi
}

sanitize_token() {
    local input="$1"
    input="${input#\"}"
    input="${input%\"}"
    input="${input#\'}"
    input="${input%\'}"
    input="${input#auth_token=}"
    input="${input#ct0=}"
    echo -n "$input" | xargs
}

generate_random_hmac() {
    if command -v openssl &>/dev/null; then
        openssl rand -hex 16
    else
        head -c 32 /dev/urandom | md5sum | head -c 32
    fi
}

interactive_add_account() {
    echo -e "${CYAN}------------------------------------------------------------------${NC}"
    echo -e "${BOLD}Twitter 小号凭证录入 (用于突破推特免登录抓取限制):${NC}"
    echo -e " 1. 电脑浏览器打开 https://x.com 并登录推特小号 (勿用主力大号)"
    echo -e " 2. 按 F12 -> 进入 Application/Storage -> 左侧 Cookies -> https://x.com"
    echo -e " 3. 复制两项值: ${GREEN}auth_token${NC} 与 ${GREEN}ct0${NC}"
    echo -e "${CYAN}------------------------------------------------------------------${NC}"

    local auth_token=""
    local ct0=""
    prompt_input "请输入 auth_token (可直接回车跳过)" "" auth_token
    [ -z "$auth_token" ] && { log_info "已跳过凭证录入。"; return 0; }
    auth_token="$(sanitize_token "$auth_token")"

    prompt_input "请输入 ct0" "" ct0
    ct0="$(sanitize_token "$ct0")"

    if [ -n "$auth_token" ] && [ -n "$ct0" ]; then
        mkdir -p "$INSTALL_DIR"
        touch "$SESSIONS_FILE"
        echo "{\"kind\": \"cookie\", \"auth_token\": \"${auth_token}\", \"authToken\": \"${auth_token}\", \"ct0\": \"${ct0}\"}" >> "$SESSIONS_FILE"
        log_success "凭证已保存至: ${SESSIONS_FILE}"

        read -rp "是否继续添加下一个备用小号？[y/N]: " continue_add
        [[ "$continue_add" =~ ^[Yy]$ ]] && interactive_add_account
    fi
}

render_configs() {
    local domain="$1"
    local port="$2"
    local proxy_url="$3"
    local docker_image="$4"
    local is_https="false"
    local hmac_key
    hmac_key="$(generate_random_hmac)"

    # 如果填写的不是 localhost 并且带有域名后缀，则开启 https 适配
    if [ "$domain" != "localhost" ]; then
        is_https="true"
    fi

    mkdir -p "$INSTALL_DIR"

    # 1. nitter.conf
    cat << EOF > "$CONF_FILE"
[Server]
address = "0.0.0.0"
port = 8080
https = ${is_https}
httpReflectedXSS = "1; mode=block"
httpContentTypeOptions = "nosniff"
httpFrameOptions = "SAMEORIGIN"
title = "Nitter"
hostname = "${domain}"

[Cache]
listMinutes = 240
rssMinutes = 10
redisHost = "nitter-redis"
redisPort = 6379
redisPassword = ""
redisConnections = 20
redisMaxMem = "512mb"

[Config]
hmacKey = "${hmac_key}"
base64Media = false
enableRSS = true
enableDebug = false
proxyVideos = true
hlsPlayback = false
infiniteScroll = false
EOF

    if [ -n "$proxy_url" ]; then
        cat << EOF >> "$CONF_FILE"
proxy = "${proxy_url}"
EOF
    fi

    cat << 'EOF' >> "$CONF_FILE"

[Preferences]
theme = "Nitter"
replaceTwitter = "twitter.com"
replaceYouTube = "piped.video"
replaceReddit = "teddit.net"
EOF

    # 2. docker-compose.yml
    cat << EOF > "$COMPOSE_FILE"
services:
  nitter-redis:
    image: redis:alpine
    container_name: nitter-redis
    restart: unless-stopped
    command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - ./redis-data:/data

  nitter:
    image: ${docker_image}
    container_name: nitter
    restart: unless-stopped
    depends_on:
      - nitter-redis
    ports:
      - "${port}:8080"
    volumes:
      - ./nitter.conf:/src/nitter.conf:ro
      - ./sessions.jsonl:/src/sessions.jsonl:ro
EOF

    [ ! -f "$SESSIONS_FILE" ] && touch "$SESSIONS_FILE"
}

install_wizard() {
    clear
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "${BOLD}                 Nitter 一键容器化部署向导                        ${NC}"
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "提示: 个人自用直接一路按 ${BOLD}[回车]${NC} 即可，输入 ${RED}q${NC} 可随时退出。\n"

    IS_INSTALLING=1
    check_or_install_docker

    local compose_cmd
    compose_cmd="$(detect_compose_cmd)"
    [ -z "$compose_cmd" ] && { log_error "未检测到 Docker Compose 插件"; exit 1; }

    local docker_image
    docker_image="$(detect_arch_image)"
    log_info "匹配系统架构镜像: ${CYAN}${docker_image}${NC}"

    # 1. 端口 (默认 8080)
    local port=""
    echo ""
    echo -e "${BOLD}【1. 服务端口】${NC}"
    prompt_input "Nitter 访问端口" "8080" port

    # 2. 域名 (默认 localhost，即 IP 访问)
    local domain=""
    echo ""
    echo -e "${BOLD}【2. 访问域名 (可选)】${NC}"
    echo -e "个人自用直接通过 IP 访问请直接按回车保持默认 (localhost):"
    prompt_input "绑定域名" "localhost" domain

    # 3. 代理设置 (可选)
    local proxy_url=""
    echo ""
    echo -e "${BOLD}【3. 网络代理设置 (可选)】${NC}"
    echo -e "国内服务器需配置 HTTP/SOCKS5 代理才能抓取推特 (海外服务器直接回车跳过):"
    prompt_input "代理地址 (如 http://127.0.0.1:7890，无则留空)" "" proxy_url

    # 4. 小号 Token (可选)
    echo ""
    echo -e "${BOLD}【4. Twitter 小号凭证 (可选)】${NC}"
    local add_now="y"
    prompt_input "是否现在录入小号 Token？[Y/n]" "Y" add_now
    [[ "$add_now" =~ ^[Yy]$ ]] && interactive_add_account

    # 5. 确认清单
    echo ""
    echo -e "${CYAN}======================== [部署配置确认] ========================${NC}"
    echo -e " 本地监听端口:    ${BOLD}${port}${NC}"
    echo -e " 绑定域名/模式:   ${BOLD}${domain}${NC} (默认 IP 访问模式)"
    echo -e " 基础 Docker 镜像: ${BOLD}${docker_image}${NC} (Docker Hub 官方源)"
    echo -e " 代理设置:        ${BOLD}${proxy_url:-无 (直连)}${NC}"
    local acc_count=0
    [ -f "$SESSIONS_FILE" ] && acc_count="$(grep -c "auth_token" "$SESSIONS_FILE" 2>/dev/null || echo 0)"
    echo -e " 小号凭证数:      ${BOLD}${acc_count} 个${NC}"
    echo -e "${CYAN}================================================================${NC}"

    local confirm_deploy="y"
    prompt_input "确认配置并启动容器？[Y/n]" "Y" confirm_deploy
    if [[ ! "$confirm_deploy" =~ ^[Yy]$ ]]; then
        log_info "已取消部署。"
        rm -rf "$INSTALL_DIR"
        exit 0
    fi

    log_info "正在生成配置文件..."
    render_configs "$domain" "$port" "$proxy_url" "$docker_image"

    log_info "正在启动容器服务..."
    cd "$INSTALL_DIR"
    $compose_cmd pull && $compose_cmd up -d

    IS_INSTALLING=0
    log_success "Nitter 服务已成功启动！"

    echo ""
    show_access_info "$domain" "$port"
}

get_current_domain() {
    if [ -f "$CONF_FILE" ]; then
        grep -E "^hostname = " "$CONF_FILE" | sed -E 's/hostname = "([^"]+)"/\1/' | head -n 1
    else
        echo "localhost"
    fi
}

get_current_port() {
    if [ -f "$COMPOSE_FILE" ]; then
        grep -E '\- ".*[0-9]+:8080"' "$COMPOSE_FILE" | sed -E 's/.*:([0-9]+):8080".*/\1/' | sed -E 's/.*"([0-9]+):8080".*/\1/' | head -n 1
    else
        echo "8080"
    fi
}

show_access_info() {
    local domain="${1:-$(get_current_domain)}"
    local port="${2:-$(get_current_port)}"
    local host_ip
    host_ip="$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || echo "你的服务器IP")"

    echo -e "${GREEN}==================================================================${NC}"
    echo -e "${BOLD}Nitter 部署完成！${NC}"
    if [ "$domain" != "localhost" ]; then
        echo -e " 🌐 域名访问地址: ${CYAN}https://${domain}${NC}"
        echo -e " 📡 RSS 订阅地址: ${CYAN}https://${domain}/Twitter/rss${NC}"
    else
        echo -e " 🌐 网页访问地址: ${CYAN}http://${host_ip}:${port}${NC} (本地: http://127.0.0.1:${port})"
        echo -e " 📡 RSS 订阅地址: ${CYAN}http://${host_ip}:${port}/Twitter/rss${NC}"
        echo -e " 🤖 机器人插件对接: 直接在插件配置中填写 ${CYAN}http://${host_ip}:${port}${NC}"
    fi
    echo -e " 📁 安装目录:     ${INSTALL_DIR}"
    echo -e " ⚠️  提示: 若公网 IP 无法打开，请检查云服务器后台安全组是否放行了 ${port} 端口！"
    echo -e "${GREEN}==================================================================${NC}"
}

modify_domain() {
    clear
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "${BOLD}修改绑定域名 / 访问模式${NC}"
    echo -e "${CYAN}==================================================================${NC}"
    local old_domain
    old_domain="$(get_current_domain)"
    echo -e "当前配置: ${BOLD}${old_domain}${NC} (localhost 表示纯 IP 模式)\n"

    local new_domain=""
    prompt_input "请输入新域名 (恢复 IP 模式请直接输 localhost)" "$old_domain" new_domain

    if [ -n "$new_domain" ]; then
        local is_https="false"
        [ "$new_domain" != "localhost" ] && is_https="true"
        sed -i -E "s/^hostname = .*/hostname = \"${new_domain}\"/" "$CONF_FILE"
        sed -i -E "s/^https = .*/https = ${is_https}/" "$CONF_FILE"
        local compose_cmd
        compose_cmd="$(detect_compose_cmd)"
        if [ -n "$compose_cmd" ] && [ -f "$COMPOSE_FILE" ]; then
            cd "$INSTALL_DIR" && $compose_cmd restart nitter 2>/dev/null || true
        fi
        log_success "配置已更新并已生效！"
    fi
    read -rp "按回车键返回..."
}

run_health_check() {
    clear
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "${BOLD}Nitter 实例运行自检${NC}"
    echo -e "${CYAN}==================================================================${NC}"

    local port
    port="$(get_current_port)"
    local compose_cmd
    compose_cmd="$(detect_compose_cmd)"

    log_info "1. 容器运行状态:"
    cd "$INSTALL_DIR" && $compose_cmd ps

    echo ""
    log_info "2. 本地端口响应 (http://127.0.0.1:${port}):"
    local http_code
    http_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:${port}" 2>/dev/null || echo "000")"
    [ "$http_code" == "200" ] && log_success "本地 Web 服务正常 (HTTP 200)" || log_warn "本地响应码: ${http_code}"

    echo ""
    log_info "3. 测试推特 RSS 抓取与 Token 连通性:"
    local rss_sample
    rss_sample="$(curl -s --max-time 10 "http://127.0.0.1:${port}/Twitter/rss" 2>/dev/null || echo "")"
    if echo "$rss_sample" | grep -q "<rss"; then
        log_success "推特数据抓取成功！"
    elif echo "$rss_sample" | grep -qi "rate limit"; then
        log_error "抓取失败: 触发推特 Rate Limit 限制，请在凭证管理中补充更多小号。"
    else
        log_warn "未能获取推特数据，请检查小号 Token 是否有效或网络是否受限。"
    fi

    echo ""
    read -rp "按回车键返回..."
}

manage_credentials_menu() {
    while true; do
        clear
        local acc_count=0
        [ -f "$SESSIONS_FILE" ] && acc_count="$(grep -c "auth_token" "$SESSIONS_FILE" 2>/dev/null || echo 0)"
        echo -e "${CYAN}==================================================================${NC}"
        echo -e "${BOLD}Twitter 小号凭证管理 (当前已存小号数: ${acc_count})${NC}"
        echo -e "${CYAN}==================================================================${NC}"
        echo -e " 1. 查看已存凭证 (脱敏)"
        echo -e " 2. 追加新小号凭证"
        echo -e " 3. 清空所有凭证"
        echo -e " 0. 返回主菜单"
        echo -e "${CYAN}==================================================================${NC}"
        read -rp "请选择 [0-3]: " c_opt
        case "$c_opt" in
            1)
                echo ""
                if [ "$acc_count" -eq 0 ]; then
                    log_warn "暂无凭证。"
                else
                    local idx=1
                    while IFS= read -r line; do
                        local at ct
                        at="$(echo "$line" | sed -E 's/.*"auth_token": *"([^"]+)".*/\1/')"
                        ct="$(echo "$line" | sed -E 's/.*"ct0": *"([^"]+)".*/\1/')"
                        echo " [$idx] auth_token: ${at:0:6}****${at: -4} | ct0: ${ct:0:8}****"
                        idx=$((idx + 1))
                    done < "$SESSIONS_FILE"
                fi
                echo ""
                read -rp "按回车键继续..."
                ;;
            2)
                interactive_add_account
                local compose_cmd
                compose_cmd="$(detect_compose_cmd)"
                if [ -n "$compose_cmd" ] && [ -f "$COMPOSE_FILE" ]; then
                    cd "$INSTALL_DIR" && $compose_cmd restart nitter 2>/dev/null || true
                    log_success "Nitter 容器已重启以应用新凭证。"
                fi
                read -rp "按回车键继续..."
                ;;
            3)
                read -rp "确定清空全部凭证？[y/N]: " confirm_c
                if [[ "$confirm_c" =~ ^[Yy]$ ]]; then
                    > "$SESSIONS_FILE"
                    log_success "凭证已清空。"
                fi
                read -rp "按回车键继续..."
                ;;
            0) break ;;
        esac
    done
}

uninstall_nitter() {
    clear
    echo -e "${RED}==================================================================${NC}"
    echo -e "${BOLD}卸载 Nitter 服务${NC}"
    echo -e "${RED}==================================================================${NC}"
    read -rp "确认彻底卸载 Nitter？[y/N] (输入 q 退出): " confirm_un
    [[ ! "$confirm_un" =~ ^[Yy]$ ]] && { log_info "已取消卸载。"; return; }

    local compose_cmd
    compose_cmd="$(detect_compose_cmd)"
    [ -n "$compose_cmd" ] && [ -f "$COMPOSE_FILE" ] && { cd "$INSTALL_DIR" && $compose_cmd down -v || true; }

    read -rp "是否删除配置与凭证目录 [${INSTALL_DIR}]？[y/N]: " del_dir
    [[ "$del_dir" =~ ^[Yy]$ ]] && { rm -rf "$INSTALL_DIR"; log_success "数据目录已删除。"; }

    log_success "卸载完成！"
    read -rp "按回车键返回..."
}

main_menu() {
    local compose_cmd
    compose_cmd="$(detect_compose_cmd)"

    while true; do
        clear
        local cur_domain
        cur_domain="$(get_current_domain)"
        local cur_port
        cur_port="$(get_current_port)"
        local acc_num=0
        [ -f "$SESSIONS_FILE" ] && acc_num="$(grep -c "auth_token" "$SESSIONS_FILE" 2>/dev/null || echo 0)"

        echo -e "${CYAN}==================================================================${NC}"
        echo -e "${BOLD}                     Nitter 运维管理控制面板                    ${NC}"
        echo -e "   访问模式: [${cur_domain}]  |  端口: ${CYAN}${cur_port}${NC}  |  小号数: ${YELLOW}${acc_num}${NC}"
        echo -e "${CYAN}==================================================================${NC}"
        echo -e " 1. 重新部署 / 覆盖安装 Nitter"
        echo -e " 2. 修改访问模式 / 绑定域名"
        echo -e " 3. 管理 Twitter 小号凭证 (查看 / 追加 / 清空)"
        echo -e " 4. 运行服务连通性自检"
        echo -e " 5. 启动 / 重启 / 停止服务"
        echo -e " 6. 实时查看运行日志"
        echo -e " 7. 彻底卸载 Nitter"
        echo -e " 0. 退出"
        echo -e "${CYAN}==================================================================${NC}"
        read -rp "请选择编号 [0-7]: " choice

        case "$choice" in
            1) install_wizard; read -rp "按回车键返回..." ;;
            2) modify_domain ;;
            3) manage_credentials_menu ;;
            4) run_health_check ;;
            5)
                echo " 1. 启动服务 | 2. 重启服务 | 3. 停止服务"
                read -rp "选择: " sc
                cd "$INSTALL_DIR"
                case "$sc" in
                    1) $compose_cmd up -d && log_success "已启动" ;;
                    2) $compose_cmd restart && log_success "已重启" ;;
                    3) $compose_cmd stop && log_success "已停止" ;;
                esac
                read -rp "按回车键继续..."
                ;;
            6)
                cd "$INSTALL_DIR"
                log_info "输出最近 100 行日志 (Ctrl+C 退出日志监控)..."
                sleep 1
                $compose_cmd logs -f --tail=100
                read -rp "按回车键继续..."
                ;;
            7) uninstall_nitter ;;
            0|q|Q) exit 0 ;;
            *) log_warn "无效输入。"; sleep 1 ;;
        esac
    done
}

main() {
    if [ -f "$COMPOSE_FILE" ] && [ -f "$CONF_FILE" ]; then
        main_menu
    else
        install_wizard
    fi
}

main "$@"
