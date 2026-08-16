# Nitter 一键容器化部署脚本 (极简自用版)

适用于 Linux 服务器的 Nitter 快速部署工具。默认采用 **IP + 端口** 模式（开箱即用、零配置、零 Nginx 依赖）；同时支持 **Cloudflare 域名全自动映射** 与 **推特小号完整增删查改**。非常适合个人自用或配合 QQ / Telegram 机器人插件（如 AstrBot）拉取推特 RSS。

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
- **绑定域名**：
  - 个人自用直接按回车保持默认 (`localhost`) 即可通过公网 IP 访问；
  - 若需绑定 Cloudflare 域名请输入你的域名（如 `nitter.yourdomain.com`），**脚本会自动为你配置好本机的 Nginx 反代并重载**。
- **网络代理**：国内服务器需填 HTTP/SOCKS5 代理，海外服务器直接回车跳过
- **Twitter 凭证**：直接粘贴小号的 `auth_token` 与 `ct0`，也可回车跳过后续再填

---

## 访问与对接插件 (例如 AstrBot)

部署完成后：
- **Web 界面访问**：`http://<你的服务器IP>:8080` (或 `https://你的域名`)
- **RSS 订阅地址**：`http://<你的服务器IP>:8080/Twitter/rss`
- **机器人插件对接**：在插件配置中的 Nitter 实例地址直接填写 `http://<你的服务器IP>:8080` (或 `https://你的域名`) 即可！

---

## Cloudflare 域名映射极简两步设置

若在脚本中填入了自定义域名，终端会打印专属配置卡片，仅需在 Cloudflare 勾选两步：

1. **DNS 解析 (Cloudflare -> DNS -> 记录)**：
   - 添加一条 `A` 记录：名称填你的二级域名前缀，内容填服务器公网 IP，开启小黄云（Proxied）。
2. **SSL 加密模式 (Cloudflare -> SSL/TLS -> 概述 Overview)**：
   - 将加密模式选择为 **【灵活 (Flexible)】**。

---

## Twitter 小号凭证管理 (完整支持 增 / 删 / 查 / 清)

自 2024 年起 Twitter 取消了免登录访客接口，自建 Nitter 必须填入推特小号凭证方可抓取推文：

### 1. 如何获取 Cookie
1. 电脑浏览器打开 `https://x.com` 登录推特临时小号（切勿用主力大号）。
2. 按 `F12` -> 切换到 **Application (应用)** 或 **Storage (存储)**。
3. 左侧展开 **Cookies** -> 点击 `https://x.com`。
4. 复制两项关键值：
   - `auth_token`：约 40 位哈希字符。
   - `ct0`：较长的 CSRF 字符。

### 2. 管理面板凭证操作
随时在服务器运行 `./nitter.sh` -> 选择 **`[3] 管理 Twitter 小号凭证`**：
- **查看列表**：脱敏列出当前所有已录入的小号及序号。
- **追加小号**：继续添加备用小号形成轮询池，自动重启容器生效。
- **删除指定小号**：输入序号一键删除失效或封禁的小号，自动重启容器生效。
- **清空凭证**：一键重置所有凭证数据。

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
 3. 🔑 管理 Twitter 小号凭证 (查看 / 增 / 删 / 清空)
 4. 🩺 运行服务连通性自检
 5. ▶️ 启动 / 🔄 重启 / ⏹️ 停止服务
 6. 📋 实时查看运行日志
 7. 🗑️ 彻底卸载 Nitter
 0. 退出
==================================================================
```
