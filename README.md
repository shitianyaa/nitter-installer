# Nitter 一键部署与管理脚本 (Cloudflare 专版)

专为 **域名托管在 Cloudflare (CF)** 场景设计的精简版 Nitter 一键容器化部署脚本。

---

## 镜像来源说明

本脚本基于 Docker 编排，镜像直接拉取自 Docker Hub 官方公共镜像源：

| 组件 | 镜像名称与 Tag | 适用架构 | 来源与说明 |
| :--- | :--- | :--- | :--- |
| **Nitter 主服务** | `zedeus/nitter:latest` | x86_64 / amd64 | [Docker Hub - zedeus/nitter](https://hub.docker.com/r/zedeus/nitter) (官方镜像) |
| **Nitter 主服务** | `zedeus/nitter:latest-arm64` | aarch64 / arm64 | [Docker Hub - zedeus/nitter](https://hub.docker.com/r/zedeus/nitter) (ARM64 官方构建) |
| **Redis 缓存** | `redis:alpine` | 全架构通用 | [Docker Hub - library/redis](https://hub.docker.com/_/redis) (官方 Alpine 轻量镜像) |

> 脚本会根据服务器架构自动匹配拉取对应镜像。

---

## 快速使用

### 1. 一键运行脚本

在你的 Linux 服务器终端执行以下命令：

```bash
curl -fsSL https://raw.githubusercontent.com/shitianyaa/nitter-installer/main/nitter.sh -o nitter.sh && chmod +x nitter.sh && ./nitter.sh
```

### 2. 交互式输入配置
运行后向导会依次确认：
1. **绑定域名**：输入你在 Cloudflare 上托管的域名（如 `nitter.yourdomain.com`）。
2. **本地端口**：默认 `8080`（直接回车即可）。
3. **网络代理**：国内服务器可输入 HTTP/SOCKS5 代理地址，海外服务器直接回车跳过。
4. **Twitter 凭证**：可直接粘贴小号的 `auth_token` 与 `ct0`，也可回车跳过后续再填。

---

## Cloudflare 域名映射配置（二选一）

部署完成后，将你在 Cloudflare 托管的域名映射到本机的 Nitter：

### 方式 A：使用云服务器公网 IP + Cloudflare 小黄云解析（常规推荐）
适合拥有独立公网 IP 的云服务器 / VPS：

1. **添加 DNS 解析**：
   - 登录 Cloudflare -> 进入你的域名 -> **DNS** -> **Records**。
   - 添加一条 `A` 记录：
     - 名称：`nitter` (即 `nitter.yourdomain.com`)
     - IPv4 地址：填入你的服务器公网 IP
     - 代理状态：保持开启（**Proxied / 橙色小云朵**）
2. **设置 SSL/TLS 加密模式 (关键)**：
   - 进入 **SSL/TLS** -> **Overview**。
   - 必须将加密模式设置为 **Full (完全)** 或 **Full (strict)**，避免死循环重定向。
3. **服务器端口转发 (关于是否需要 Nginx)**：
   - **方案 1（使用 Nginx 反代）**：在服务器上配置 Nginx 监听 80/443，将请求 `proxy_pass http://127.0.0.1:8080;`。
   - **方案 2（完全免装 Nginx）**：在 Cloudflare 控制台左侧进入 **Rules (规则)** -> **Origin Rules (源站规则)** -> 创建规则：当主机名为 `nitter.yourdomain.com` 时，将目标端口重写为 `8080`。这样无需在服务器安装 Nginx，CF 会自动将 443 请求转至后端的 8080 端口。

---

### 方式 B：使用 Cloudflare Zero Trust Tunnel（完全免装 Nginx，无公网 IP 亦可用）
适合家庭宽带、本地设备、NAS 或不想在服务器开放任何防火墙端口的场景：

1. **创建 Tunnel**：
   - 登录 Cloudflare -> 点击左侧 **Zero Trust** -> **Networks** -> **Tunnels**。
   - 点击 **Add a tunnel** -> 选择 **Cloudflared** -> 自定义隧道名称。
2. **在服务器安装并启动 cloudflared**：
   - 复制页面给出的系统安装命令，在服务器终端执行一次即可完成连接。
3. **配置域名路由**：
   - 在 Tunnel 的 **Public Hostname** 中添加一条规则：
     - **Subdomain**：`nitter`
     - **Domain**：选择你的域名
     - **Type**：`HTTP`
     - **URL**：`localhost:8080`
4. **访问测试**：
   - 保存后即可直接通过 `https://nitter.yourdomain.com` 访问，**全过程不需要安装 Nginx，不需要开放任何公网端口，自带 HTTPS 证书**。

---

## Twitter 凭证获取与配置说明 (auth_token 与 ct0)

### 为什么两者都需要？
- **`auth_token`**：推特账号的登录 Session 身份标识。
- **`ct0`**：推特的 CSRF 防伪造 Token（API 校验时必须与 Cookie 一并提交）。
> Nitter 在向推特请求数据时，必须同时携带两者才能通过推特的 GraphQL / API 鉴权，**缺一不可**。

### 详细获取步骤 (电脑浏览器)：
1. **登录小号**：使用 Chrome / Edge / Firefox 等浏览器打开 `https://x.com` 并登录一个推特临时小号（切勿使用日常主力大号）。
2. **打开控制台**：在网页任意位置按键盘 **`F12`**（或右键 -> 检查）。
3. **定位 Cookie 页面**：
   - **Chrome / Edge**：点击顶部标签栏的 **`Application (应用)`** -> 左侧菜单展开 **`Cookies`** -> 点击 **`https://x.com`**。
   - **Firefox (火狐)**：点击顶部标签栏的 **`存储 (Storage)`** -> 左侧菜单展开 **`Cookies`** -> 点击 **`https://x.com`**。
4. **复制两项关键值**：
   - 在右侧列表中找到 **`auth_token`**，双击 Value 栏复制（约 40 位哈希字符）。
   - 在列表中找到 **`ct0`**，双击 Value 栏复制（较长的 CSRF 字符）。
5. **填入脚本**：
   - 可在首次部署向导时直接粘贴；
   - 也可以在部署完成后，随时在控制面板选择 **`[3] 管理 Twitter 小号凭证`** 进行追加。脚本会自动过滤掉可能多复制的空格或引号。

---

## 日常管理菜单

后续随时在服务器执行 `./nitter.sh` 即可打开控制面板：

```text
==================================================================
               Nitter 极简管理面板 (Cloudflare 映射版)           
   绑定域名: https://nitter.yourdomain.com  |  端口: 8080  |  小号数: 1
==================================================================
 1. 重新部署 / 覆盖安装 Nitter
 2. 修改绑定的 Cloudflare 域名
 3. 管理 Twitter 小号凭证 (查看 / 追加 / 清空)
 4. 运行服务连通性自检
 5. 启动 / 重启 / 停止服务
 6. 实时查看运行日志
 7. 彻底卸载 Nitter
 0. 退出
==================================================================
```

---

## 目录结构

默认安装在当前用户的 `~/nitter` 目录下：

```text
~/nitter/
├── docker-compose.yml   # Docker Compose 编排文件
├── nitter.conf          # 自动配置好 Cloudflare 域名的 Nitter 主配置
├── sessions.jsonl       # Twitter 小号凭证池
└── redis-data/          # Redis 缓存持久化目录
```
