# Nitter 一键容器化部署脚本 (极简自用版)

适用于 Linux 服务器的 Nitter 快速部署工具。默认采用 **IP + 端口** 模式，开箱即用，零配置、零 Nginx 依赖，非常适合个人使用或配合 QQ / Telegram 机器人插件（如 AstrBot）拉取推特 RSS。

---

## 镜像来源说明

本脚本基于 Docker 编排，所有镜像均拉取自 Docker Hub 官方源：

| 组件 | 镜像名称与 Tag | 适用架构 | 来源与说明 |
| :--- | :--- | :--- | :--- |
| **Nitter 主服务** | `zedeus/nitter:latest` | x86_64 / amd64 | [Docker Hub - zedeus/nitter](https://hub.docker.com/r/zedeus/nitter) (官方构建) |
| **Nitter 主服务** | `zedeus/nitter:latest-arm64` | aarch64 / arm64 | [Docker Hub - zedeus/nitter](https://hub.docker.com/r/zedeus/nitter) (ARM64 官方构建) |
| **Redis 缓存** | `redis:alpine` | 全架构通用 | [Docker Hub - library/redis](https://hub.docker.com/_/redis) (官方 Alpine 轻量镜像) |

---

## 快速使用

### 1. 一键运行部署脚本

在你的 Linux 服务器终端执行：

```bash
curl -fsSL https://raw.githubusercontent.com/shitianyaa/nitter-installer/main/nitter.sh -o nitter.sh && chmod +x nitter.sh && ./nitter.sh
```

### 2. 交互式输入 (一路按回车即可)
- **服务端口**：默认 `8080` (直接回车)
- **绑定域名**：个人自用直接按回车保持默认 (`localhost`) 即可通过公网 IP 访问
- **网络代理**：国内服务器需填 HTTP/SOCKS5 代理，海外服务器直接回车跳过
- **Twitter 凭证**：直接粘贴小号的 `auth_token` 与 `ct0`，也可回车跳过后续再填

---

## 访问与对接插件 (例如 AstrBot)

部署完成后：
- **Web 界面访问**：`http://<你的服务器IP>:8080`
- **RSS 订阅地址**：`http://<你的服务器IP>:8080/Twitter/rss`
- **机器人插件对接**：在插件配置中的 Nitter 实例地址直接填写 `http://<你的服务器IP>:8080` 即可！

> ⚠️ **注意**：如果公网 IP 打不开，请检查云厂商控制台（如腾讯云、阿里云、甲骨文）的**安全组 / 防火墙**，确保放行了 TCP `8080` 端口入站规则。

---

## Twitter 小号凭证获取指引 (auth_token 与 ct0)

自 2024 年起 Twitter 取消了免登录访客接口，自建 Nitter 必须填入推特小号凭证方可抓取推文：

1. **登录小号**：电脑浏览器打开 `https://x.com` 登录推特临时小号（切勿用主力大号）。
2. **打开控制台**：按 `F12` -> 切换到 **Application (应用)** 或 **Storage (存储)**。
3. **定位 Cookie**：左侧展开 **Cookies** -> 点击 `https://x.com`。
4. **复制两项关键值**：
   - `auth_token`：约 40 位哈希字符。
   - `ct0`：较长的 CSRF 字符。
5. **填入脚本**：可在安装时粘贴，或随时运行 `./nitter.sh` 选 `[3] 管理 Twitter 小号凭证` 进行追加。

---

## 日常管理面板

后续随时在服务器执行 `./nitter.sh` 即可打开控制面板：

```text
==================================================================
                     Nitter 运维管理控制面板                    
   访问模式: [localhost]  |  端口: 8080  |  小号数: 1
==================================================================
 1. 重新部署 / 覆盖安装 Nitter
 2. 修改访问模式 / 绑定域名
 3. 管理 Twitter 小号凭证 (查看 / 追加 / 清空)
 4. 运行服务连通性自检
 5. 启动 / 重启 / 停止服务
 6. 实时查看运行日志
 7. 彻底卸载 Nitter
 0. 退出
==================================================================
```

---

## （可选）高级：绑定自定义域名

若后续确实需要绑定域名：
1. 运行 `./nitter.sh` -> 选择 `[2] 修改访问模式 / 绑定域名`，输入你的域名（如 `nitter.example.com`）。
2. 配合 Cloudflare Zero Trust Tunnel、Nginx 或宝塔反代到 `http://127.0.0.1:8080` 即可。
