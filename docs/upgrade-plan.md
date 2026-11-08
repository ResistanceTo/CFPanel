# CFPanel 升级方案（2.0）

> 2026-11-08 第二版。在第一版基础上，对照两份官方资料重新整理：
> - **Cloudflare API 文档**（developers.cloudflare.com/api）：抓取了 128 个产品分组中与手机运维相关的 63 个，共 1,227 个接口，逐条和 CFPanel 现有调用比对。
> - **Cloudflare 网页版 Dashboard**：依据官方文档仓库里的 Dashboard 路由表（163 个页面）、产品文档里的操作路径、2025–2026 年 changelog 和截图整理。没有登录实际账号查看。
>
> 标注 ⚠️ 的条目尚未完全核实，动手前需要再确认。

## 0. 结论

1. **结构上向 Dashboard 看齐**。用户已经熟悉 Dashboard 的分组和叫法，CFPanel 沿用同样的心智模型：账号层（首页、域名、构建、防护与连接、账号管理）+ 域名层（概览、DNS、SSL/TLS、安全、缓存……）。iPad 侧边栏基本照搬 Dashboard，iPhone 压缩成 4 个 tab 加搜索。
2. **交互上抄 Dashboard 做得好的，改掉不适合手机的**。可以照搬的有：域名概览的「快捷操作」、星标和最近访问、快速搜索、安全概览的待办列表、DNS 记录页的新交互（含官方自己的手机卡片布局）、告警静音。需要改的是：Dashboard 用单个开关切换的高风险操作，手机上要加确认，防止误触。
3. **功能上补「出事时用得上」的接口**。CFPanel 目前只覆盖了相关接口的约 10%。优先补应急工具箱：IP 封禁、Zone Hold、软清除缓存、账号级「仅 DNS」开关、证书状态、吊销 Token、告警。然后补开发者平台：Worker 日志、实时日志、回滚、构建、Workflows、Tunnel。
4. **长尾功能用「在 Dashboard 中打开」兜底**。Dashboard 每个页面都有深链接（`dash.cloudflare.com/?to=/:account/:zone/...`），app 不需要把 128 个产品全做一遍。

---

## 1. 现状

### 1.1 1.1.1 已经处理的问题（分支 `fix/cloudflare-api-compat`，未合并）

| 问题 | 状态 |
|---|---|
| `foundation_dns` 字段 11 月 23 日下线导致 DNS 设置页打不开 | 已修复 |
| 编辑 DNS 记录时还能改类型（Cloudflare 6 月 30 日起不支持） | 已锁定类型 |
| 登录后所有请求错误都不提示 | 已修复：用户操作失败一律提示，自动加载仍然静默 |
| Pages / Workers 只能进前 3 个 | 已修复 |
| 安全级别 Low/Medium/High 选择器失效 | 已移除，只保留 Under Attack 开关 |
| 审计日志被 app 自己的读取（`view`）刷屏 | 已过滤 |

1.1.1 还没做的：暂停站点加确认、深色模式登录页、改版本号、**确认 OAuth 客户端已公开**（Cloudflare 2026-06-03 起新建的 OAuth 客户端默认私有，不公开的话其他用户无法用 OAuth 登录）。

### 1.2 接口覆盖情况

| | 数量 |
|---|---|
| API 文档中的产品分组 | 128 |
| 其中与手机运维相关的分组（本次分析范围） | 63 |
| 这 63 个分组的接口总数 | 1,227 |
| CFPanel 调用的接口 | 89 个路径，涉及 14 个分组，约覆盖 130 个接口（约 10%） |

覆盖较多的是 Workers、Pages、DNS、Email Routing、KV；完全没有覆盖的包括告警、IP 访问规则、Rules Lists、SSL 证书、Security Center、成员与 Token 管理、Tunnel、Workflows、Workers 构建、Registrar、Web Analytics、Bot 管理等。完整对照见附录 A。

**接口健康检查**
- ⚠️ Email Sending 用的路径 `/zones/{id}/email/security/sending_subdomains` 已经不在当前 API 文档里，文档里的是 `/zones/{id}/email/sending/subdomains`。实测旧路径还能路由（返回需要认证，不存在的路径会返回 "No route"），所以目前没坏，但应该在 1.2 迁移。
- Workers 新增了一套以 Worker 为主体的接口（`/accounts/{id}/workers/workers`），和现在用的 `workers/scripts` 并存。⚠️ 需要确认是否会取代旧接口。

### 1.3 体验上的主要问题（第一版诊断，仍然成立）

- 功能入口分散：同一个开关出现在两处；安全设置一半在「安全」tab，一半在「站点 → 高级设置」；应急中心有两个入口。
- 只支持一个账号，切换账号要退出重登。
- 很多功能只能看不能改：DNS 设置、Worker 部署（不能回滚）、邮件路由规则、R2/D1/Queues 只有元数据、规则不能新建。
- 交互：常用操作路径长；成功提示是模态弹窗；只有 DNS 有搜索；没有长按菜单、复制、撤销。
- 视觉：系统列表和 31 处手写卡片两套风格并存；118 处写给开发者的说明文字；深色模式层次消失；无障碍标签只有 5 处。用 iOS 27 SDK 编译已无法关闭 Liquid Glass。
- 工程：没有测试和 CI；41 个 view model 逐个注入；路由绑死在各 tab，难做深链。
- App Store 唯一的用户反馈：希望支持 Tunnel；希望有「功能 → 所需权限」清单。

---

## 2. 官方 Dashboard 现在长什么样

### 2.1 账号层导航（2026 年）

```
账号切换器 · 快速搜索（⌘K 或 /）· + Add · Ask AI · Support · 用户菜单
─────────────────────────────
Account home
Recents（最近访问，可固定页面）
Observability：Logs · Analytics · Alerts（原 Notifications）· 导出  ⚠️ 2026-10 推断
Domains
── Build ──
  Compute：Workers & Pages、Workers for Platforms、Containers、Durable Objects、
           Queues、Workflows、Browser Run、VPC、Email Service（Routing / Sending）
  AI：Workers AI、AI Gateway、Vectorize、AI Search
  Storage & databases：R2、Workers KV、D1、Hyperdrive、Analytics Engine、Pipelines、Secrets Store
  Media：Stream、Images、Realtime
── Protect & Connect ──
  Application security：Security insights、Security analytics、Security events、WAF、Turnstile……
  Zero Trust（2026-10 起并入主导航）
  Networking：Tunnels、Mesh、Insights、Routes、Firewall policies、L3/4 DDoS、DNS Firewall……
  Delivery & performance：Bulk redirects、Load Balancing、Web tag management
  Domain registration：Manage / Transfer / Register domains
──
Manage account：Members、Billing、Account API tokens、OAuth clients、Audit logs、
                Abuse reports、Configurations（Lists、Custom Pages、DNS Settings……）
```

2025–2026 年的主要变化：Compute 和 AI 拆成两组；Queues 移到 Compute；Security Center、WAF、Turnstile 合并为 Application security；Notifications 改名 Alerts；Tunnels 移到 Networking；Zero Trust 并入主导航；Magic WAN 等改名 Cloudflare WAN。

### 2.2 域名层导航

```
← Back to Domains · 域名切换器 · ☆ 星标 · 套餐标签
Overview
AI Crawl Control
Analytics & logs：HTTP Traffic、Security、Performance、Web analytics、Workers、Instant Logs……
Version Management
DNS：Records、Analytics、Settings
Email：Email Routing、DMARC Management、Email Security
SSL/TLS：Overview、Edge Certificates、Client Certificates、Origin Server、Custom Hostnames
Security：Overview、Analytics、Web assets、Security rules、Settings
Speed：Observatory、Real user monitoring……
Caching：Overview、Configuration、Cache Rules、Tiered Cache、Cache Reserve
Workers Routes
Rules：Overview、Snippets、Cloud Connector、Trace、Page Rules（已弃用）
Error Pages · Network
Traffic：Load Balancing、Health Checks、Waiting Room……
```

菜单项按套餐显示，Free 套餐的列表短很多。

### 2.3 值得参考的页面和交互

| 页面 / 模式 | Dashboard 的做法 | CFPanel 怎么用 |
|---|---|---|
| 域名列表 | 搜索、按星标筛选（最多 10 个，筛选会被记住）；每行显示状态、安全洞察数、访客迷你图、套餐、⋯ 快捷操作 | 首页和域名列表照此设计 |
| 域名概览 | 右侧「Quick Actions」：Under Attack 开关、Zone Hold 开关；「Advanced Actions」：暂停 Cloudflare、移出 Cloudflare；名称服务器和「重新检查激活」；Zone ID / Account ID 带复制按钮 | 做成应急主屏 |
| 安全概览 | 「安全待办」按严重程度（Critical / Moderate / Low）排序，可按类型和类别筛选；归档时要选原因（误报 / 接受风险 / 其他）；「检测工具 5/6 运行中」；流量拆成「已拦截 / Cloudflare 响应 / 源站响应」 | 安全 tab 的落地页 |
| Security rules | 自定义规则、限速规则、托管规则例外合并到一页，有模板 | 规则只做查看、开关和模板，不做表达式编辑器 |
| DNS 记录 | 推荐项（如「添加 DMARC 记录」）、搜索、筛选、代理状态（橙色云 / 灰色云）、多选后批量改代理或删除（删除要输入 `DELETE`）、影子记录和配额告警；**官方为手机做了卡片布局** | 直接参考官方手机布局 |
| Worker 详情 | Overview（24 小时请求 / 错误 / CPU、部署、域名）· Metrics（图上标出每次发布）· Deployments · Observability · Settings | 手机上保留 4 个：概览、部署、日志、指标，其余放「更多」 |
| R2 桶 | 存储类别、公开访问、大小、A/B 类操作数；Objects · Metrics · Settings | 桶详情照此 |
| Alerts | 告警历史、通知策略、静音（Mute 1h / 12h / 24h / 自定义） | 首页显示告警，一键静音 |
| 快速搜索 | ⌘K 或 `/`，能搜页面，也能执行命令（如「复制账号 ID」） | 搜索 tab：页面 + 资源 + 命令 |
| 键盘快捷键 | `g h` 首页、`g w` Workers、`s z` 切换域名、`s .` 星标、`p .` 固定页面 | iPad 外接键盘照搬 |
| 高风险操作 | Under Attack、开发模式、Zone Hold 是单个开关；清除全部缓存弹警告；批量删除要输入 `DELETE`；暂停放在「Advanced Actions」里；2026-09 新增「软清除」 | 见 5.1 |
| 深链接 | `dash.cloudflare.com/?to=/:account/:zone/<路径>` 自动替换成当前账号和域名 | 每个页面提供「在 Dashboard 中打开」 |
| AI 助手 | Agent Lee（原 Cloudy），每次写操作都要用户批准，没有公开 API | 不集成；以后做 AI 功能时沿用「写操作需批准」的原则 |

⚠️ 未核实：2026-10 之后账号侧边栏的确切结构；Account home 现在显示什么；域名概览快捷操作是否包含开发模式；星标、固定、最近访问是否有公开 API（目前按「没有」处理，存在本地并通过 iCloud 同步）。

---

## 3. 原则

1. 继续纯客户端、无后端，不做依赖推送服务器的功能。
2. **分组和命名跟 Dashboard 一致**：Records、Proxied / DNS only、Security rules、Web assets、Alerts、Workers & Pages、Account API tokens……中文翻译尽量对齐 Dashboard 官方中文界面的用词（⚠️ 需要逐个对照）。
3. **手机端优先应急**：Dashboard 是「什么都能配」，CFPanel 是「出事时最快处理」，所以快捷操作、告警、日志排在前面，复杂配置留给网页。
4. 一个功能只有一个主入口（Under Attack 例外：Dashboard 本身就在概览和安全设置两处都放了）。
5. 导航层交给系统控件和 Liquid Glass，不再手绘外框。
6. 权限按需申请，缺权限时直接说明缺哪一项，并给出 Cloudflare 403 响应里附带的文档链接。

**不做**：完整替代 Dashboard、计费管理、规则表达式编辑器、Zero Trust 策略配置、需要服务器的推送。

---

## 4. 信息架构

### 4.1 iPhone：4 个 tab + 搜索

| Tab | 对应 Dashboard | 内容 |
|---|---|---|
| **首页** | Account home + Alerts + Recents | 星标域名（状态、访客迷你图、安全待办数）；正在生效的应急状态（Under Attack、开发模式剩余时间、Zone Hold）；最近告警（可静音）；最近访问 |
| **域名** | Domains → 域名层 | 域名列表（搜索、星标、按状态/套餐/标签筛选）→ 域名主页（见 4.3） |
| **构建** | Build | Compute（Workers & Pages、Workflows、Queues、Durable Objects、Containers）· Storage & databases（R2、KV、D1、Hyperdrive、Secrets Store）· AI（AI Gateway、Vectorize）· Media（跳转网页） |
| **防护与连接** | Protect & Connect | 账号级安全洞察、Turnstile；Tunnels；Load Balancing；域名注册 |
| **搜索** | 快速搜索（⌘K） | `Tab(role: .search)`：页面、资源（域名、DNS 记录、Worker、桶……）、命令（「对 example.com 开启 Under Attack」「复制 Zone ID」「清除某个 URL」） |

- **右上角头像** = Dashboard 的用户菜单 + Manage account：账号切换、成员、Account API tokens、审计日志、告警策略、账单用量、Configurations（Lists）、OAuth 授权管理，以及 app 自身设置。
- **有应急状态生效时**，用 `tabViewBottomAccessory` 常驻提示，例如「example.com：Under Attack 已开启 2 小时 · 关闭」。

### 4.2 iPad：侧边栏照搬 Dashboard

`.sidebarAdaptable` 让 iPad 显示侧边栏，结构和 2.1 节基本一致（首页、Recents、Domains、Build、Protect & Connect、Manage account），进入域名后侧边栏换成域名层菜单，顶部有「← 返回域名」。iPhone 的 4 个 tab 就是这套侧边栏的压缩版，两者用同一套路由，尺寸变化时不丢位置。

### 4.3 域名主页（顺序沿用 Dashboard 域名层，只显示该套餐有的项）

```
example.com   ☆   Pro   [在 Dashboard 中打开]
├─ 概览：状态、名称服务器（待激活时可「重新检查」）、套餐、Zone ID / Account ID 复制
│        快捷操作：Under Attack · 开发模式（显示剩余时间）· Zone Hold
│        高级操作：暂停 Cloudflare
├─ 分析与日志：HTTP 流量、安全、性能、Web Analytics
├─ DNS：Records、Settings（含 DNSSEC）
├─ 邮件：Email Routing、Email Sending、DMARC
├─ SSL/TLS：概览（加密模式）、Edge Certificates（证书状态与到期时间、HTTPS、HSTS、最低 TLS）
├─ 安全：Overview（安全待办）、Analytics、Security rules、Settings（Bot、泄露凭证检测）
├─ AI 爬虫管控
├─ 缓存：Overview（清除 / 软清除）、Configuration（缓存级别、浏览器 TTL、开发模式）、Cache Rules
├─ Workers 路由
├─ 规则：Overview（按执行顺序列出所有规则）
└─ 流量：Load Balancing、Health Checks、Waiting Room（有才显示）
```

和现在相比：「安全」tab 并入域名主页；「站点 → 高级设置」里的开关按含义归到 SSL/TLS、缓存、安全；同一个开关只出现一次。

### 4.4 账号模型

1. 一个凭证下的多个账号：账号切换器（`GET /memberships`、`GET /organizations`）；域名按账号分组；构建、防护与连接跟随当前账号。
2. 多凭证（例如公司和个人），Keychain 每个配置一条。
3. 星标、最近访问、固定页面存为非敏感偏好，通过 iCloud KVS 同步。

---

## 5. 交互

### 5.1 高风险操作的确认分级

Dashboard 的分级思路可以沿用，但手机误触更容易，所以整体比网页重一级：

| 级别 | 例子 | Dashboard | CFPanel |
|---|---|---|---|
| 可撤销的小改动 | 切换单条记录代理、开关一条规则、改缓存 TTL | 直接生效 | 直接生效 + 底部提示条带「撤销」 + 触感反馈 |
| 影响线上流量 | Under Attack、开发模式、Zone Hold、改 SSL 模式、回滚 Worker | 单个开关 | 从按钮弹出确认框，写清影响范围；不再强制等 3 秒（改为可选设置） |
| 大范围影响 | 清除全部缓存、暂停 Cloudflare、账号级「仅 DNS」 | 警告弹窗 / 放在高级操作里 / 只有 API | 确认框 + Face ID；清除前先推荐「软清除」；「仅 DNS」放在高级危险模式后面，写明会暴露所有站点的源站 IP |
| 不可逆删除 | 删除记录、删除项目、吊销 Token | 删除确认；批量删除要输入 `DELETE` | Face ID + 确认；批量删除同样要求输入 `DELETE` |

自动失效的状态显示倒计时：开发模式 3 小时后自动关闭，Zone Hold 可以设到期时间。

### 5.2 反馈

- 成功：底部提示条，不再用模态「Done」弹窗。
- 失败：一律可见。页面内错误条 + 重试；权限不足时说明缺哪个权限，附上 403 响应里的文档链接，并跳转到「功能 → 所需权限」清单。

### 5.3 列表和详情

- 目录型列表都有搜索、排序、加载更多；支持左滑和长按菜单（复制值、复制 ID、在 Dashboard 中打开、分享）。
- 详情页用 Dashboard 的 tab 结构，手机上用顶部分段控件，最多 4 段，其余放「更多」。
- 编辑用 sheet（系统的取消 / 保存按钮），不再一个 sheet 关掉再弹另一个。
- 所有 ID 旁边都有复制按钮。

### 5.4 DNS 记录页（参考官方新版）

- 顶部推荐项（如「缺少 DMARC 记录」）。
- 搜索 + 筛选；列表卡片显示名称、类型、内容、代理状态（可直接点云朵切换）、TTL、备注。
- 多选后批量改代理状态或删除（`POST /zones/{id}/dns_records/batch`，删除要输入 `DELETE`）。
- 记录配额告警（`GET /zones/{id}/dns_records/usage`）和影子记录提示（列表请求加 `include_shadow_metadata=true`）。
- **重新支持改类型**：用批量接口在一个事务里「删除旧记录 + 新建记录」，界面上说明会生成新的记录 ID。

### 5.5 搜索

对应 Dashboard 的快速搜索：
- **页面**：域名主页各项、构建下各产品、账号管理各项。
- **资源**：已加载的域名、DNS 记录、Worker、Pages 项目、桶、命名空间。
- **命令**：开启 / 关闭 Under Attack、清除某个 URL、复制 Zone ID、在 Dashboard 中打开当前页。

### 5.6 iPad 与键盘

照搬 Dashboard 快捷键：`/` 搜索、`g h` 首页、`g w` Workers、`s z` 切换域名、`s .` 星标、`p .` 固定当前页；同时放进 iPadOS 菜单栏。

---

## 6. 视觉

- **Liquid Glass**：tab bar、侧边栏、工具栏、sheet 交给系统；删掉页面上的不透明背景和自绘底栏。
- **三种页面模板，对应 Dashboard 的三类页面**：
  1. **概览页**（域名概览、Worker 概览、安全概览）：顶部数字条 + 快捷操作 + 待办 / 下一步。
  2. **列表页**（域名、DNS 记录、Worker、规则）：系统 `List` + 搜索 + 筛选 + 多选。
  3. **设置页**（SSL/TLS、缓存配置）：系统 `Form`。
  删掉 31 处手写卡片，概览页的数字卡统一用一个组件（同心圆角）。
- **状态语义和 Dashboard 一致**：代理状态用橙色云 / 灰色云；严重程度用 Critical / Moderate / Low 三色；部署状态用成功 / 进行中 / 失败。
- **品牌色**：AccentColor 目前为空，需要定一个主色；状态色只用于表达含义。
- **图表**：指标和 Dashboard 保持一致（请求、带宽、访客、威胁、「已拦截 / Cloudflare 响应 / 源站响应」）；Worker 指标图上标出每次发布；所有套餐都开放 30 天范围。
- **深色模式**：修好登录页；层次用系统语义色。
- **文案**：删掉写给开发者的说明，每页最多一句提示；文案定稿后统一做 8 种语言翻译，中文对齐 Dashboard 官方中文用词。
- **无障碍**：动态字体全量检查，图标按钮加标签。
- **登录页**：品牌头 + 「使用 Cloudflare 登录」主按钮 + 「使用 API Token」次按钮；利用 OAuth 可选 scope（只有站点读取是必需的），去掉 app 内的权限开关墙；附「功能 → 所需权限」清单。

---

## 7. 功能补充（按 Dashboard 分组，标注对应接口）

### 7.1 P0：应急工具箱（2.1）

| 功能 | Dashboard 位置 | 接口 | 说明 |
|---|---|---|---|
| Zone Hold | 域名概览 · 快捷操作 | `GET/POST/PATCH/DELETE /zones/{id}/hold` | 防止域名被误加到别的账号；解除时可设时长 |
| 重新检查激活 | 域名概览 · 名称服务器 | `PUT /zones/{id}/activation_check` | 新域名待激活时常用 |
| 软清除缓存 | 缓存 · 概览 | `POST /zones/{id}/invalidate_cache` | 2026-09 新增；源站故障时仍可返回旧内容；要求源站返回 ETag 或 Last-Modified |
| IP 访问规则 | Security rules | `/{accounts\|zones}/{id}/firewall/access_rules/rules` | 按 IP、IP 段、ASN、国家封禁 / 质询 / 放行，最典型的应急操作 |
| IP 列表 | Manage account · Configurations · Lists | `/accounts/{id}/rules/lists`、`…/items` | 把 IP 加进规则引用的列表，一处修改多条规则生效 |
| 账号级「仅 DNS」开关 | Dashboard 没有，只有 API | `PATCH /accounts/{id}/dns_settings`（`enforce_dns_only`） | 差异化功能；影响账号下全部站点 |
| 告警 | Observability · Alerts | `/accounts/{id}/alerting/v3/history`、`/policies`、`/silences` | 首页展示最近告警；一键静音 1 / 12 / 24 小时；策略开关 |
| 安全待办 | Security · Overview | `/{accounts\|zones}/{id}/security-center/insights`、`…/dismiss`、`…/classification`、`…/severity` | 按严重程度排序；归档时选原因 |
| 证书状态 | SSL/TLS · Edge Certificates | `GET /zones/{id}/ssl/certificate_packs`、`PATCH …/{pack}`（重新验证）、`GET /zones/{id}/ssl/universal/settings` | 到期提醒、验证失败时重试 |
| DNSSEC | DNS · Settings | `GET/PATCH/DELETE /zones/{id}/dnssec` | 查看和开关；关闭前提示先删注册商处的 DS 记录 |
| DNS 批量与配额 | DNS · Records | `POST /zones/{id}/dns_records/batch`、`GET …/dns_records/usage` | 见 5.4 |
| 成员 | Manage account · Members | `/accounts/{id}/members` | 安全事件时移除成员 |
| Account API tokens | Manage account | `/accounts/{id}/tokens`、`PUT …/{token}/value`（轮换）、`DELETE` | Token 泄露时立即轮换或吊销 |

### 7.2 P1：开发者平台（2.2）

| 功能 | Dashboard 位置 | 接口 | 说明 |
|---|---|---|---|
| Worker 日志 | Worker · Observability | `POST /accounts/{id}/workers/observability/telemetry/query` | 最近错误、按结果筛选。⚠️ 文档里只写了需要 Observability Write 权限 |
| Worker 实时日志 | Worker · Logs | `POST /accounts/{id}/workers/scripts/{name}/tails`（返回 WebSocket 地址） | 手机上看实时日志，出事时很有用；离开页面时删除 tail |
| 检测到的问题 | Worker · Issues | `GET /accounts/{id}/workers/observability/issues` | Dashboard 新增的问题视图 |
| Worker 回滚 | Worker · Deployments | `POST /accounts/{id}/workers/scripts/{name}/deployments` | 选一个旧版本设为 100%；支持回滚最近 100 个版本 |
| Secrets | Worker · Settings | `GET/PUT/DELETE …/scripts/{name}/secrets`、`PATCH …/secrets-bulk` | 泄露时轮换 |
| Workers 构建 | Worker · Deployments | `/accounts/{id}/builds/builds/latest`、`…/{uuid}/logs`、`PUT …/cancel` | ⚠️ 文档说只接受用户级 API Token，需要先支持用户级 Token |
| Workflows | Compute · Workflows | `/accounts/{id}/workflows`、`…/instances`、`PATCH …/instances/{id}/status` | 找卡住或失败的实例，暂停 / 恢复 / 终止 / 重启 |
| Tunnels | Networking · Tunnels | `GET /accounts/{id}/cfd_tunnel`、`…/{id}/connections` | 用户点名要的功能；列表的 `connections` 字段已移除，要单独查 |
| Queues | Compute · Queues | `GET …/queues/{id}/metrics`、`POST …/messages/peek` | 积压数、最旧消息时间；窥视消息排查问题 |
| D1 | Storage · D1 | `POST …/d1/database/{id}/query`、`…/time_travel/restore`、`…/undelete` | 默认只读查询；时间点恢复和 7 天内恢复删除要最重确认；结果超过 50 MB 会失败 |
| R2 对象 | Storage · R2 · Objects | `GET …/r2/buckets/{b}/objects`、`GET/DELETE …/objects/{key}` | 不用 S3 密钥浏览和删除对象 |
| 域名注册 | Domain registration | `GET /accounts/{id}/registrar/registrations`、`PATCH …/{domain}` | 到期时间、自动续费、锁定。Beta，还没有续费接口 |
| Web Analytics | 域名 · Analytics & logs | `/accounts/{id}/rum/site_info/list` + GraphQL | 免费用户常用的访客统计 |
| AI 爬虫管控 / Bot | 域名 · AI Crawl Control、Security · Settings | `GET/PUT /zones/{id}/bot_management`、`GET /zones/{id}/ai-audit/robots` | 2025–2026 年站长很关心的功能 |
| Turnstile | Application security · Turnstile | `/accounts/{id}/challenges/widgets`、`…/rotate_secret` | 查看组件、轮换密钥 |
| 健康检查 / 负载均衡 / 等候室 | 域名 · Traffic | `/zones/{id}/healthchecks`、Load Balancers pools health、`/zones/{id}/waiting_rooms` | 只对有这些功能的用户显示 |
| 泄露凭证检测 | Security · Settings | `GET/POST /zones/{id}/leaked-credential-checks` | 开关 |

### 7.3 P2：之后再看

| 功能 | 接口 | 说明 |
|---|---|---|
| Flagship 功能开关 | `/accounts/{id}/flagship/apps`、`…/flags`、`…/flags/{key}/changelog` | 在手机上切换功能开关很有价值。⚠️ 产品成熟度未确认 |
| 资源标签 | `/accounts/{id}/tags`、`…/tags/resources` | 按标签给域名分组、筛选 |
| 版本管理 | `/zones/{id}/environments`、`…/rollback` | Dashboard 的 Version Management，企业版为主 |
| AI Gateway、Containers、Durable Objects、Secrets Store | 各自接口 | 先做只读列表 |
| 账单用量 | Billing usage | Alpha，等稳定 |

### 7.4 只做「在 Dashboard 中打开」

Zero Trust 策略、Networking（Tunnel 以外）、Media（Stream、Images、Realtime）、Web tag management / Zaraz、Spectrum、Logpush 配置、Snippets、Speed、Custom Hostnames、Page Shield 等。做法：

- 每个页面工具栏放「在 Dashboard 中打开」，用 Dashboard 深链接跳到对应页面。
- 在「更多」里放一个「全部功能」目录，按 Dashboard 分组列出所有页面，点开直接跳网页。路由表来自官方文档仓库，可以在构建时生成。

---

## 8. 系统集成（无后端前提下）

| 能力 | 用途 | 方案 | 优先级 |
|---|---|---|---|
| 深链接 | `cfpanel://zone/{id}/dns` 等 | 小组件、快捷指令、搜索命令都依赖它；随路由重构一起做 | 高 |
| App Intents + 快捷指令 | 查看站点状态、清除缓存、开关 Under Attack | 在 app 进程内执行（不共享 Keychain）；改线上配置要求设备已解锁并确认 | 高 |
| 控制中心控件 | 一键开关某个站点的 Under Attack | 需要扩展共享 Keychain，做成用户可选开启 | 中 |
| 小组件 | 星标域名状态、今日流量 | 同上；组件快照会被系统缓存，要在隐私说明里写清 | 中 |
| Live Activity | Under Attack 计时、开发模式剩余时间、构建进行中 | 只在本地更新，设置过期时间 | 低 |
| Spotlight | 搜索域名 | 会把域名持久化到系统索引，和「业务数据只放内存」冲突；不做，或做成明确可选 | 低 |

推送类告警不做；在告警页引导用户把 Cloudflare 告警投递到邮件、Webhook 或 PagerDuty。

---

## 9. 工程改造

- **最低系统版本 17 → 26**（截至 2026-06，79% 的 iPhone 在 iOS 26）。
- **路由重构**：全局 `Route` + 路由器，同一套路由同时驱动 iPhone tab 和 iPad 侧边栏；支持 app 深链和 Dashboard 深链映射。
- **依赖注入**：41 个 `.environment` 合并为少量按功能分组的环境对象。
- **测试**：接口模型用真实响应 JSON 做解析测试；view model 用 `URLProtocol` 桩测试。
- **CI**：GitHub Actions 编译 + 测试。
- **接口对照脚本**：把这次的抓取和比对做成脚本，定期运行，检查 app 调用的路径是否还在官方文档里（本次就发现了 Email Sending 的旧路径）。
- **容错解析**：枚举遇到未知值降级；非关键字段可选。
- **限流**：读取 `Ratelimit` / `Retry-After` 头退避；控制并发。
- **支持用户级 API Token**：Workers 构建接口需要，dev.md 也承诺过。
- **迁移 Email Sending 路径**到 `/zones/{id}/email/sending/subdomains`。
- **清理**：删死代码、拆大文件、更新过时文档（`copilot-instructions.md` 等）。

---

## 10. 路线图

| 版本 | 主题 | 内容 | 规模 |
|---|---|---|---|
| **1.1.1** | 紧急修复 | 已完成 6 项（见 1.1）；剩余：暂停站点确认、深色模式登录页、版本号、确认 OAuth 客户端已公开 | 小 |
| **1.2** | 地基 | iOS 26；测试 + CI；接口对照脚本；容错解析；限流；路由与依赖注入重构；迁移 Email Sending 路径；用户级 Token；核实 OAuth refresh token；导出 `/oauth/scopes` 清单 | 中 |
| **2.0** | 对齐 Dashboard 的新界面 | 新导航（iPhone 4 tab + 搜索、iPad 侧边栏）；首页（星标、应急状态、告警、最近访问）；域名主页和概览快捷操作；安全概览；DNS 记录新交互；快速搜索与命令；「在 Dashboard 中打开」与全部功能目录；多账号；确认分级与提示条；Liquid Glass 视觉；新登录页 + 权限清单 | 大 |
| **2.1** | 应急工具箱 | 7.1 全部：Zone Hold、软清除、IP 访问规则、IP 列表、仅 DNS 开关、告警静音、证书状态、DNSSEC、DNS 批量、成员与 Token 管理 | 中 |
| **2.2** | 开发者平台 | 7.2：Worker 日志 / 实时日志 / 问题 / 回滚 / Secrets / 构建、Workflows、Tunnels、Queues、D1、R2 对象、域名注册、Web Analytics、AI 爬虫管控、Turnstile | 大 |
| **2.3** | 系统集成 | 快捷指令；控制中心 Under Attack；小组件（可选开启）；Live Activity | 中 |
| 之后 | P2 | Flagship、资源标签、版本管理等 | — |

---

## 11. 需要你拍板的决策

| # | 问题 | 建议 |
|---|---|---|
| 1 | 分组和命名是否全面对齐 Dashboard？ | 是。iPad 照搬侧边栏，iPhone 压缩为 4 tab |
| 2 | 中文术语是否对齐 Dashboard 官方中文界面？ | 是，需要逐个对照收集 |
| 3 | 最低版本升到 iOS 26？ | 是 |
| 4 | 多账号、多凭证？ | 2.0 先做「一个凭证多个账号」，多凭证随后 |
| 5 | 高风险操作比网页多一层确认？ | 是；3 秒倒计时改为可选设置，默认关闭 |
| 6 | 账号级「仅 DNS」开关要做吗？ | 做，放在高级危险模式后面 |
| 7 | 支持用户级 API Token？ | 支持 |
| 8 | 小组件和控制中心是否允许扩展共享 Keychain？ | 先做 app 内执行的快捷指令；扩展做成可选开启 |
| 9 | Flagship 等新产品是否纳入？ | 先观察，等产品稳定 |
| 10 | 2.0 一次性发布还是逐步替换？ | 一次性大版本；1.2 期间先发 TestFlight |

---

## 12. 风险

- **Dashboard 还在变**：2026 年改过好几次导航。对策是只对齐稳定的大分组和叫法，细节以 changelog 为准，并定期复查。
- **导航大改带来回归**：1.2 先补测试和路由。
- **OAuth scope 不确定**：所有新功能开工前先用 `GET /client/v4/oauth/scopes` 核对；没有 scope 的功能只在 Token 模式提供。
- **Beta 接口变动**：Registrar、SQL 分析、Flagship 等先做只读。
- **翻译成本**：文案定稿后统一翻译。
- **App 审核**：新功能需要同步更新审核用演示 Token 的权限。

---

## 附录 A：接口覆盖对照（63 个相关分组）

数字为「该分组接口总数 / CFPanel 已覆盖（含同一路径的其他方法）」。

| 分组 | 接口数 | 已覆盖 | | 分组 | 接口数 | 已覆盖 |
|---|---|---|---|---|---|---|
| Workers | 89 | 25 | | Alerting | 22 | 0 |
| Pages | 24 | 18 | | Firewall（IP 访问规则等） | 15 | 0 |
| DNS | 59 | 13 | | Rules Lists | 11 | 0 |
| Email Routing | 19 | 13 | | SSL | 15 | 0 |
| KV | 13 | 12 | | Security Center | 9 | 0 |
| Rulesets | 15 | 8 | | IAM | 31 | 0 |
| Zones | 42 | 7 | | Zero Trust（只算 Tunnel 等） | 113 | 0 |
| D1 | 13 | 6 | | Workers Builds | 28 | 0 |
| Hyperdrive | 7 | 6 | | Workflows | 14 | 0 |
| Queues | 25 | 6 | | Registrar | 13 | 0 |
| R2 | 46 | 5 | | RUM（Web Analytics） | 10 | 0 |
| Vectorize | 14 | 5 | | Bot Management | 4 | 0 |
| Accounts | 46 | 2 | | Turnstile | 6 | 0 |
| Cache | 24 | 1 | | Load Balancers | 35 | 0 |
| Email Sending | 14 | 0（使用旧路径） | | Waiting Rooms | 23 | 0 |

其余未覆盖的相关分组：AI Audit、AI Gateway、Abuse Reports、Argo、Audit Logs（v1）、Billing、Containers、Custom Certificates、Custom Hostnames、Custom Pages、DDoS Protection、Durable Objects、Email Auth、Flagship、Healthchecks、Images、Leaked Credential Checks、Logpush、Logs、Memberships、Organizations、Origin CA Certificates、Page Rules、Page Shield、Pipelines、Resource Tagging、Secrets Store、Smart Shield、Snippets、Speed、Stream、User、Zaraz。

不在分析范围内的 65 个分组：Radar、Magic Transit、Network Interconnects、Addressing、Brand Protection、Intel、Cloudforce One、Realtime Kit、Calls、Browser Rendering、Workers AI 等骨干网、企业安全情报和媒体实时类产品。

## 附录 B：依据

**官方 API**
- [API 文档首页](https://developers.cloudflare.com/api/) 与 [llms.txt 索引](https://developers.cloudflare.com/api/llms.txt)
- [API 废弃公告](https://developers.cloudflare.com/fundamentals/api/reference/deprecations/)
- [Changelog](https://developers.cloudflare.com/changelog/)

**官方 Dashboard**
- [Dashboard 路由表（docs 仓库 dash-routes/core.json）](https://github.com/cloudflare/cloudflare-docs/blob/production/src/content/dash-routes/core.json)
- [统一导航（2026-10）](https://developers.cloudflare.com/changelog/post/2026-10-12-unified-dashboard-navigation/)
- [AI 分组（2026-02）](https://developers.cloudflare.com/changelog/post/2026-02-19-ai-dashboard-experience-improvements/)
- [Networking 导航（2026-01）](https://developers.cloudflare.com/changelog/post/2026-01-15-networking-navigation-update/)
- [Tunnel 移入主导航](https://developers.cloudflare.com/changelog/post/2026-02-20-tunnel-core-dashboard/)
- [新安全概览](https://developers.cloudflare.com/changelog/post/2026-03-17-new-security-overview-ui/) · [安全概览文档](https://developers.cloudflare.com/security/overview/) · [Security rules](https://developers.cloudflare.com/security/rules/)
- [新版 DNS 记录页](https://developers.cloudflare.com/changelog/post/2026-05-20-new-dns-records-ux/) · [旧版下线](https://developers.cloudflare.com/changelog/post/2026-10-30-classic-dns-records-page-retired/)
- [Worker 概览页](https://developers.cloudflare.com/changelog/post/2025-10-06-new-worker-overview-page/) · [指标图标注发布](https://developers.cloudflare.com/changelog/post/2026-09-25-release-flows-workers-metrics/)
- [R2 Dashboard 更新](https://developers.cloudflare.com/changelog/post/2025-05-01-r2-dashboard-updates/)
- [Account home 更新](https://developers.cloudflare.com/changelog/post/2025-03-26-account-home-updates/) · [星标域名](https://developers.cloudflare.com/fundamentals/manage-domains/star-zones/)
- [键盘快捷键](https://developers.cloudflare.com/changelog/post/2026-05-04-keyboard-shortcuts/)
- [Under Attack](https://developers.cloudflare.com/fundamentals/reference/under-attack-mode/) · [暂停 Cloudflare](https://developers.cloudflare.com/fundamentals/manage-domains/pause-cloudflare/) · [Zone Hold](https://developers.cloudflare.com/fundamentals/account/account-security/zone-holds/)
- [清除全部缓存](https://developers.cloudflare.com/cache/how-to/purge-cache/purge-everything/) · [软清除](https://developers.cloudflare.com/changelog/post/2026-09-28-cache-invalidation/)
- [告警](https://developers.cloudflare.com/notifications/get-started/)
- [Agent Lee](https://developers.cloudflare.com/agent-lee/)

**Apple**
- WWDC25：323、275、278；WWDC26：269、278、223
- [iOS 版本占比](https://developer.apple.com/support/app-store/)
- iOS 27.1 SDK 接口文件

**仍需核实**
- CFPanel 的 OAuth 客户端是否已公开；不申请 `offline_access` 是否下发 refresh token。
- 所有新功能对应的 OAuth scope ID（含 Hyperdrive）。
- 2026-10 之后 Dashboard 账号侧边栏的确切结构；Dashboard 官方中文用词。
- Workers 构建是否接受 OAuth token；Observability 查询的权限要求。
- `workers/workers` 新接口与 `workers/scripts` 的关系；Email Sending 旧路径何时下线。
- Flagship 的产品状态。
