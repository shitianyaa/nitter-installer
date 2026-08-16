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

### 1. 如何获取 Cookie (重要操作技巧)
1. **使用无痕模式**：打开浏览器的 **无痕窗口 / 隐身模式** (`Ctrl + Shift + N`)，访问 `https://x.com` 登录推特临时小号（切勿用主力大号）。
2. **打开控制台**：按 `F12` -> 切换到 **Application (应用)** 或 **Storage (存储)**。
3. **定位 Cookie**：左侧展开 **Cookies** -> 点击 `https://x.com`。
4. **复制两项关键值**：
   - `auth_token`：约 40 位哈希字符。
   - `ct0`：较长的 CSRF 字符。
5. **直接关闭无痕窗口**：复制完成后，**直接关掉无痕窗口即可，千万不要在网页上点击「Log Out / 退出登录」**！（主动退出登录会导致推特服务器立即注销该 Token 使其作废）。

### 2. 管理面板凭证操作
随时在服务器运行 `./nitter.sh` -> 选择 **`[3] 管理 Twitter 小号凭证`**：
- **查看列表**：脱敏列出当前所有已录入的小号及序号。
- **追加小号**：继续添加备用小号形成轮询池，自动重启容器生效。
- **删除指定小号**：输入序号一键删除失效或封禁的小号，自动重启容器生效。
- **清空凭证**：一键重置所有凭证数据。

---

## 📁 部署后文件存储位置与目录结构

运行脚本部署完成后，所有相关的配置文件与持久化数据将统一存放在当前用户的家目录下：

### 1. 核心安装目录 (`~/nitter/`)
> 路径：`/root/nitter/` 或 `/home/<你的用户名>/nitter/`

```text
~/nitter/
├── nitter.conf          # Nitter 核心配置文件 (包含端口、绑定域名、HTTPS 开关、代理设置等)
├── docker-compose.yml   # 容器编排文件 (定义了 Nitter 与 Redis 容器的启动参数与端口映射)
├── sessions.jsonl       # Twitter 小号凭证池 (存放 auth_token 与 ct0 的 JSONL 文件)
└── redis-data/          # Redis 缓存数据持久化目录 (缓存推特文章与图片索引)
```

### 2. 各文件作用与维护建议
| 文件 / 目录 | 作用说明 | 维护建议 |
| :--- | :--- | :--- |
| **`nitter.conf`** | Nitter 服务主配置 | 可通过管理菜单 `[2]` 修改域名，或直接编辑后重启容器 |
| **`sessions.jsonl`** | 推特小号 Token 池 | 建议直接在脚本菜单 `[3]` 中增删，格式已内置严格校验 |
| **`docker-compose.yml`** | Docker 容器服务定义 | 包含容器自启与网络互联定义，一般无需手动修改 |
| **`redis-data/`** | 缓存数据库存储 | 缓存过期自动轮替，无需人工干预 |

### 3. 系统级反代配置 (仅当绑定了域名且使用 Nginx 时)
- 配置文件路径：`/etc/nginx/conf.d/nitter.conf`（或 `/etc/nginx/sites-enabled/nitter.conf`）
- 作用：将 `80` 端口对域名的访问精准反代转发至本地 Nitter 的 `8080` 端口。

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

---

## 🗑️ 关于彻底卸载（0 残留、无误删）

在管理面板中选择 **`[7] 彻底卸载 Nitter`** 时：
1. **停止并删除容器**：自动执行 `docker compose down -v`，删除 Nitter 容器、Redis 容器以及专属 Docker 网络。
2. **清理 Nginx 反代配置**：精准删除 `/etc/nginx/.../nitter.conf` 并自动重载 Nginx，**绝对不会误删或影响服务器上现有的其他网站**。
3. **清理数据目录**：精准删除专属的 `~/nitter` 目录，不会碰家目录下其他任何文件。
