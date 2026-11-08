# CFPanel 升级方案（2.0）

> 2026-11-08 整理。依据：代码盘点、模拟器实测、App Store 用户反馈、Cloudflare 最新 API 与废弃公告、iOS 26/27 设计规范与 SDK。
> 标注 ⚠️ 的条目尚未完全核实，动手前需要再确认。

## 0. 结论

把 CFPanel 从「按 Cloudflare 产品目录排列的一组设置页」，升级成「手机上的 Cloudflare 值班台」：

- **看一眼**：打开 app 几秒内就知道所有站点和服务有没有出问题。
- **出事时**：从打开到执行应急操作不超过 2 次点击（加必要的确认）。
- **日常操作**：改 DNS、看部署、查资源顺手，安全确认统一、可预期。

分 6 步推进：先修 bug（1.1.1），再打地基（1.2），然后换导航、交互和视觉（2.0），最后补运维能力（2.1）、接入新产品（2.2）、做系统集成（2.3）。

---

## 1. 现状诊断

### 1.1 做得好的地方（升级时保留）

- 设备直连 Cloudflare 的信任模型：OAuth 用了 PKCE 和 state 校验，凭证存在 Keychain。
- 状态分层清楚：`AppStores` + 各功能 context，有会话版本号防止旧响应覆盖新数据。
- 覆盖面广：14 个功能区，8 种语言。
- 用 Xcode 27.1 编译零警告。

### 1.2 Bug 和已经失效的功能（建议放进 1.1.1）

| 问题 | 证据 | 影响 |
|---|---|---|
| 登录后所有请求错误都不提示 | `RootView.swift:23` 登录后把 `suppressInterruptingErrorAlerts` 设为 `true`，`AppModel.swift:49` 之后只写日志 | 开关 Under Attack、清缓存、保存 DNS 失败时用户完全不知道 |
| Pages / Workers 只能进前 3 个 | `CorePlatformStatusCards.swift:59,142` 写死 `prefix(3)`，没有其他入口 | 第 4 个之后的项目无法查看和操作 |
| 深色模式下登录页看不清 | 登录页背景是硬编码的浅色渐变，文字随系统变白（模拟器实测） | 深色模式用户第一屏就是浅底白字 |
| 暂停站点没有确认 | `SiteSectionViews.swift:49-60` | 误触会让全部流量绕过 Cloudflare |
| 安全级别选择器已经没有意义 | Cloudflare 2026-04-16 更新：安全级别只用来开关 Under Attack，威胁分数恒为 0 | 选 Low/Medium/High 不再有效果，会误导用户 |
| 审计日志会被 app 自己的读取刷屏 | Cloudflare 2026-10-13 起，审计日志 v2 把 GET 请求记为 `view` 操作，API 会返回这些记录 | CFPanel 每次刷新都会在审计日志里留下一串 `view`，真正的改动被淹没 |

### 1.3 功能边界

- **站点相关的操作被拆散在多处**：
  - 安全设置一部分在「安全」tab，一部分在「站点 → 高级设置 → 安全控制」。
  - Always Use HTTPS 在 SSL/TLS 和「高级 → 流量控制」各有一份。
  - 开发模式和 Always Online 在「缓存」和「流量控制」各有一份。
  - 应急中心在「监控」和「安全」各有一个入口。
- **切换站点不方便**：切换入口藏在「站点」tab 里，另外还有「所有站点」列表和设置里的「默认站点」，一共 3 个地方；站点多时没有搜索。
- **只支持一个账号**：
  - Keychain 里只有一个凭证。
  - OAuth 登录默认取账号列表里的第一个。
  - 站点列表可能来自多个账号，但平台功能只用一个账号 ID，可能对不上。
  - 想切换账号只能退出重登。
- **很多功能只能看不能改**：
  - DNS 设置、Worker 部署和版本（不能回滚，Pages 却可以）、邮件路由规则。
  - R2 / D1 / Queues / Vectorize / Hyperdrive 只有元数据。
  - 规则不能新建或编辑（`addZoneRule` 写了但没有调用）。
  - 没有 WAF 事件、IP 访问规则、Worker 日志。

### 1.4 交互

常用操作的路径（iPhone）：

| 操作 | 现在 | 目标 |
|---|---|---|
| 编辑 DNS 记录 | 5 次点击，中间一个 sheet 关闭后再弹另一个 | 3 次 |
| 开启 Under Attack | 3 次点击 + 等 3 秒 + 确认 | 2 次 + 确认 |
| 清除全部缓存 | 4 次 + 等 3 秒 + 确认 + Face ID | 2 次 + 确认（Face ID 可选） |
| 查看 Worker 部署 | 4 次，而且只限前 3 个 Worker | 3 次，带搜索 |
| 读取 KV 值 | 5 层，没有搜索 | 4 层，支持前缀搜索 |
| 切换账号 | 不支持 | 2 次 |

其他问题：
- 安全确认不一致：Under Attack 只有倒计时；清缓存要倒计时加 Face ID；暂停站点、SSL 模式、HSTS、WAF 开关点一下就立即生效。
- 成功提示是模态的「Done」弹窗（30 处），每次都要多点一下。
- 只有 DNS 有搜索；只有 DNS 和规则支持左滑；没有长按菜单、复制、分享、撤销；触感反馈只在 Under Attack 一处。

### 1.5 视觉

- 两套风格并存：一部分是系统 `Form`/`List`，另一部分是 `ScrollView` 加 31 处手写卡片（圆角 24、不透明背景）。
- 118 处脚注说明文字，很多是写给开发者的，比如 "This page is a directory only…"。
- 深色模式下卡片和页面背景都是黑色，看不出层次。
- 无障碍标签只有 5 处；登录页用了固定字号。
- 还在用旧的 `.tabItem` 写法。**用 iOS 27 SDK 编译时已经无法关闭 Liquid Glass**（`UIDesignRequiresCompatibility` 被忽略），所以下一个版本无论如何都会换上新外观，手写卡片和不透明背景会和它冲突。

### 1.6 工程

- 没有测试 target，没有 CI。
- 41 个 view model 在 `CFPanelApp.swift` 里逐个用 `.environment` 注入，漏掉一个就会运行时崩溃。
- 路由枚举是各 tab 私有的，Pages/Worker 的页面只注册在「平台」tab 的导航栈里，很难做深链和跨 tab 跳转。
- 有一批死代码（`DashboardHomeSections.swift`、`AccountPlatformStatusCards.swift`、`ProductSurfaceStyle` 等）。
- 文档和代码不一致：
  - 文档写 `@CloudStorage`/iCloud KVS，代码用的是 `@AppStorage`。
  - dev.md 承诺的 user token 和请求日志都不可用。
  - `.github/copilot-instructions.md` 还在描述旧架构。

### 1.7 用户反馈与权限

- App Store 唯一一条评价（中国区）提了两点：**希望支持 Cloudflare Tunnel**；**希望给出「app 功能 → 所需 Token 权限」清单**。
- ⚠️ **最需要先确认的一项**：Cloudflare 从 2026-06-03 起，新建的 OAuth 客户端默认是私有的，只有所属账号的成员能授权。要公开，需要填写名称、logo、网址，并在域名上加一条 `cloudflare_oauth_client_publisher=` 开头的 TXT 记录完成验证，公开后不可撤回。CFPanel 的 OAuth 是 2026-07 随 1.1.0 上线的，如果客户端没有公开，其他用户都无法用 OAuth 登录。请到 Cloudflare 后台确认客户端的可见性。
- ⚠️ OAuth 没有申请 `offline_access`。Cloudflare 的 OAuth 服务可能因此不发 refresh token，访问令牌过期后需要重新登录。验证方法：登录后看请求日志里的 `refreshTokenPresent`。
- ⚠️ Hyperdrive 在 OAuth 权限目录（`OAuthScopeCatalog.swift`）里没有对应 scope，OAuth 用户可能用不了。需要用 `GET /client/v4/oauth/scopes`（要带凭证）核对。

---

## 2. 目标与原则

**原则**

1. 继续纯客户端、无后端；不做依赖推送服务器的功能。
2. 按作用范围组织功能：站点范围的放进站点，账号范围的放进平台，不再按「安全」「设置」这种横切分类拆散。
3. 一个功能只有一个入口。
4. 导航层交给系统控件和 Liquid Glass，不再手绘外框。
5. 权限按需申请，缺权限时界面直接告诉用户缺哪一项、怎么补。

**不做的事**

- 完整替代 Cloudflare Dashboard。
- 计费、套餐管理。
- 复杂的规则表达式编辑器。
- 需要服务器的推送告警。

---

## 3. 信息架构（新导航）

### 3.1 Tab 结构

使用 iOS 18+ 的 `Tab` API，iPad 上用 `.sidebarAdaptable`。

| Tab | 内容 | 对应旧版 |
|---|---|---|
| **概览** | 所有站点的健康状态（请求、5xx、威胁的迷你趋势图）、正在生效的应急状态、最近触发的告警、最近部署、最近审计事件 | 监控 |
| **站点** | 站点列表（搜索、按账号分组）→ 站点主页 | 站点 + 安全 + 部分高级设置 |
| **平台** | Workers、Pages、存储与数据库、新产品（见第 6 节） | 平台 |
| **搜索** | `Tab(role: .search)`：跨站点、DNS 记录、Workers、Pages、存储资源统一搜索和跳转 | 新增 |

- **账号与设置**：移到右上角头像按钮，点开是账号切换和设置 sheet，不再占一个 tab。
- **应急入口**：
  - 站点主页顶部固定一个「应急」区块：Under Attack、清除缓存、暂停站点。
  - 概览页的站点卡片支持长按直接操作。
  - 有应急状态生效时（Under Attack 开着、开发模式开着），用 `tabViewBottomAccessory` 常驻提示，例如「example.com：Under Attack 已开启 2 小时 · 关闭」，避免忘记关。
  - iOS 27 可选用 `Tab(role: .prominent)` 固定一个应急 tab（需要 `#available`）。

### 3.2 站点主页

```
站点主页（example.com）
├─ 应急：Under Attack · 清除缓存 · 暂停站点
├─ 流量：24H / 7D / 30D 图表（现在所有套餐都能查 30 天）、状态码、缓存命中、国家
├─ DNS：记录（列表上直接切换代理）、DNS 设置、扫描、区域文件
├─ 安全：Under Attack、WAF/安全事件、IP 访问规则、Bot、规则、安全洞察
├─ 缓存：清除 / 软清除、缓存级别、浏览器 TTL、开发模式、Always Online
├─ SSL/TLS：加密模式、最低 TLS、HTTPS 相关、HSTS
├─ 邮件：路由、发送
└─ 站点设置：概况、边缘功能、暂停/恢复
```

每个设置只出现一次。旧版「高级设置」里的流量、安全、边缘开关按含义并入上面各组。

### 3.3 平台

- **Workers**：完整列表（搜索、排序、状态）→ 详情：最近错误与日志（新）、构建（新）、部署与版本（含回滚）、路由与域名、配置。
- **Pages**：完整列表 → 部署（重试/回滚）、域名、操作。Cloudflare 建议新项目用 Workers，Pages 维持现有能力即可。
- **Workflows**（新）：实例列表、状态、暂停/恢复/终止。
- **存储与数据库**：KV / R2 / D1 / Queues / Vectorize / Hyperdrive 合并成一个分组列表，少一层目录。
- **网络**（新）：Tunnel 状态与连接。
- **账号**：告警（历史与静音）、审计日志、API Token、域名注册（beta）。

### 3.4 账号模型

1. **一个凭证下的多个账号**：账号选择器；站点按账号分组；平台功能跟随当前账号。修掉「站点来自 A 账号、平台用 B 账号」的错配。
2. **多凭证**（例如公司和个人）：Keychain 每个配置一条记录，切换不用退出。
3. 记住上次使用的站点。

---

## 4. 交互升级

### 4.1 统一的操作分级

| 级别 | 例子 | 交互 |
|---|---|---|
| 只读 | 查看任何数据 | 无 |
| 可撤销的即时改动 | 切换代理、开发模式、启用/停用规则、改缓存 TTL | 直接生效，底部提示条带「撤销」（约 5 秒），配合触感反馈 |
| 影响线上流量 | Under Attack、暂停站点、清除全部缓存、改 SSL 模式、回滚部署 | 从按钮处弹出确认框（`confirmationDialog(item:)`，可向下兼容到 iOS 15），写清影响范围；不再强制等 3 秒 |
| 不可逆删除 | 删 DNS 记录、删项目、删 KV | Face ID + 确认；继续放在「高级危险模式」后面 |

3 秒倒计时改成设置项，默认关闭。

### 4.2 反馈

- 成功：用不打断操作的提示条，取代 30 处模态「Done」弹窗。
- 失败：一律可见。页面内显示错误条和重试按钮；如果是权限不足，直接说明缺哪个权限、怎么添加。
- 修掉登录后错误被吞掉的 bug（1.1.1）。

### 4.3 列表和详情

- 所有目录型列表都支持搜索、排序和加载更多。
- 左滑操作和长按菜单：复制值、复制 ID、在浏览器打开 Dashboard 对应页面、分享。
- 详情用 push，编辑用 sheet（取消/保存用系统按钮角色），不再一个 sheet 关掉再弹另一个。
- DNS：在列表里直接点云朵图标切换代理，长按复制。
- KV：按前缀搜索。
- 审计日志：分页，按操作者和资源筛选。

### 4.4 iPad 与大屏

- `.sidebarAdaptable` + `NavigationSplitView`（站点列表 → 站点主页 → 详情）。一套导航状态，尺寸变化时不丢失位置。
- 键盘快捷键和 iPadOS 菜单栏命令：⌘F 搜索、⌘R 刷新、⌘K 快速跳转。
- 用 iOS 27 SDK 编译后，iPhone app 在 iPad 上会自动可调整大小，不能再假设固定宽度。

---

## 5. 视觉升级

- **采用 Liquid Glass**：tab bar、工具栏、sheet 交给系统；删掉页面上的不透明背景和自绘的底栏。
- **内容层只留两种样式**：设置类页面统一用 `List`/`Form`；仪表盘类（概览、流量）用一个统一的卡片组件（同心圆角 `ConcentricRectangle`），删掉 31 处手写卡片。
- **颜色**：AccentColor 目前是空的，需要定一个品牌主色和一组状态色（正常/警告/故障），只在表达含义时用色。
- **深色模式**：修好登录页；卡片层次用系统语义色。
- **文案**：删掉写给开发者的说明，每页最多一句提示。文案定稿后统一做一次 8 种语言的翻译。
- **图表**：Swift Charts 迷你趋势图放进站点列表行和概览卡片；保留选中交互；补上无障碍音频图表。
- **无障碍**：全量检查动态字体，图标按钮加标签，去掉固定字号。
- **登录页重做**：
  - 品牌头部 + 主按钮「使用 Cloudflare 登录」+ 次按钮「使用 API Token」。
  - 利用 OAuth 可选 scope：只有站点读取是必需的，其余由用户在 Cloudflare 授权页自行勾选，app 里不再需要一整面权限开关墙。
  - 新增「功能 → 所需权限」清单，回应 App Store 上的反馈；app 内遇到权限不足时也跳到这份清单。

---

## 6. Cloudflare 新 API

所有新功能开工前都要先用 `GET /client/v4/oauth/scopes` 查到对应的 OAuth scope ID（这次调研在公开文档里一个也没找到），没有 scope 的功能只能在 Token 登录模式下提供。

### 6.1 先处理：已有功能受到的变化

| 变化 | 时间 | 对 CFPanel 的影响 | 处理 | 版本 |
|---|---|---|---|---|
| 安全级别只剩 Under Attack 开关，威胁分数恒为 0 | 2026-04-16 | Low/Medium/High 选择器失效 | 去掉选择器，只保留 Under Attack 开关 | 1.1.1 |
| 审计日志 v2 记录 `view`（GET）操作 | 2026-10-13 | app 自己的读取刷屏 | 默认隐藏 `view` 操作，提供开关 | 1.1.1 |
| 所有套餐的分析数据保留 31 天，单次查询最长 30 天 | 2026-10-02 | Free/Pro 用户的 30D 视图原来可能受限 | 30D 范围对所有套餐开放 | 1.2 |
| 任何清除缓存都会让 Cache Reserve 失效 | 2026-09-28 | 清除缓存的代价变大 | 在确认框里说明，并提供「软清除」（见 6.2） | 2.1 |
| 403 错误会附带 `documentation_url` | 2026-08-20 | 可以精确告诉用户缺什么权限 | 权限不足提示里带上这个链接 | 2.0 |
| 响应带 `Ratelimit` / `Retry-After` 头；每个 token 每 5 分钟 1200 次 | 2026-08 | 一次刷新并发请求较多 | 传输层按响应头退避重试 | 1.2 |
| 权限显示名从「Edit」改为「Write」 | 2026 | 权限清单的文字 | 按权限组 ID 匹配，不按名字 | 2.0 |
| D1 查询结果超过 50 MB 会失败 | 2026-11-04 | 只有做 D1 查询控制台才相关 | 查询加 LIMIT | 视情况 |

### 6.2 新增功能（按「手机端价值 × 纯客户端可行性」排序）

| # | 功能 | 接口 | 状态 | 为什么值得做 | 规模 | 版本 |
|---|---|---|---|---|---|---|
| 1 | **软清除缓存** | `POST /zones/{id}/invalidate_cache`，选择器同清除（URL、标签、主机名、前缀、全部） | GA，2026-09-28 | 比清除更安全：源站故障时还能返回旧内容。直接放进现有清除流程。要求源站返回 `ETag` 或 `Last-Modified` | 小 | 2.1 |
| 2 | **账号级「仅 DNS」紧急开关** | `PATCH /accounts/{id}/dns_settings`，`enforce_dns_only: true` | GA，2026-04-28 | **Dashboard 上没有，只能通过 API 操作**，是 CFPanel 的差异化功能。会暴露所有站点的源站 IP，并关闭 WAF、DDoS 防护和缓存，必须做最重的确认 | 小到中 | 2.1 |
| 3 | **Tunnel 状态** | `GET /accounts/{id}/cfd_tunnel`、`/cfd_tunnel/{id}/connections` | GA | App Store 用户点名要的功能；「隧道断了没」是典型的值班场景。列表里的 `connections` 字段 2026-10-05 起已移除，要单独查连接 | 中 | 2.2 |
| 4 | **告警中心** | Alerting v3：`/alerting/v3/history`、`/silences`（增删改查）、`/policies` | 已有 | 不需要推送也能看「刚才触发了什么」；事故期间一键静音 2 小时 | 中 | 2.2 |
| 5 | **Worker 最近错误和日志** | `POST /accounts/{id}/workers/observability/telemetry/query`（events/invocations 视图） | GA | 出事时最想看的就是报错。⚠️ 文档里只写了需要「Workers Observability Write」权限，需要实测 | 中 | 2.2 |
| 6 | **Workers 构建** | `GET /accounts/{id}/builds/workers/{tag}/builds`、`/builds/{uuid}/logs`、`PUT …/cancel` | GA | 「部署失败了吗、为什么」。⚠️ 文档说只接受用户级 API Token，CFPanel 目前只支持账号 Token 和 OAuth | 中 | 2.2 |
| 7 | **Workflows 实例** | `/accounts/{id}/workflows/{name}/instances`、`PATCH …/instances/{id}/status`（暂停、恢复、终止、重启） | GA | 找卡住或失败的实例并处理 | 中 | 2.2 |
| 8 | **安全洞察** | `GET /zones/{id}/security-center/insights`、`PUT …/{issue}/dismiss` | 已有 | 悬空 DNS、缺 DMARC、管理员没开 MFA 等问题一览，只读、低风险 | 小 | 2.1 |
| 9 | **数据服务补强** | Queues `GET /queues/{id}/metrics`（积压数、最旧消息时间）；D1 `undelete`（7 天内）和时间点恢复；R2 `GET /r2/buckets/{b}/objects` 浏览对象 | GA | 「消费者是不是卡住了」「误删的库能不能找回」「不用 S3 密钥看桶里有什么」 | 中 | 2.1 |
| 10 | **审计日志资源历史** | `GET /accounts/{id}/logs/audit/{id}/history` | GA，2026-07-27 | 「这条记录是谁、什么时候改的」 | 小 | 2.1 |
| 11 | **域名注册** | `GET /accounts/{id}/registrar/registrations`、`PATCH …/{domain}`（自动续费、锁定） | Beta，**还没有续费接口** | 到期提醒、自动续费和锁定状态；旧的注册商接口 2026-09-27 已下线 | 小 | 2.2 |
| 12 | **SQL 分析接口** | `POST /client/v4/analytics/sql` | Beta，2026-10-02 | 一个接口查 HTTP、安全事件、Workers 日志；用的是 CFPanel 已申请的 `account-analytics.read`。先保留 GraphQL，等它 GA 再迁移 | 中 | 观察 |
| 13 | **紧急轮换** | 账号 Token `PUT /accounts/{id}/tokens/{id}/value`；Workers 批量 secrets（2026-06-03） | GA | 凭证泄露时在手机上立即轮换 | 小到中 | 2.2 |

**先不做**：Containers、Secrets Store、AI Gateway 日志、AI Search、Logpush、发送测试邮件、账单用量（alpha）、自定义告警 Monitors（还没有 API）。

### 6.3 OAuth 相关的新能力

- **可选 scope**（2026-08-20）：`optional_scopes` 是 `scopes` 的子集，用户可以在授权页拒绝其中一部分。CFPanel 可以只把站点读取设为必需，其余设为可选，登录页的「权限墙」就能大幅简化（见第 5 节登录页重做）。
- **客户端默认私有**（2026-06-03）：见 1.7，需要先确认。
- **授权码 + PKCE（S256）是原生 app 唯一支持的方式**，CFPanel 已符合。
- 账号管理员可以关闭「Public OAuth App access」，这种账号不会出现在授权结果里。要处理这种情况，并给出改用 Token 的提示。

---

## 7. 系统集成（在无后端前提下）

两个限制：
- 小组件推送、控件推送、Live Activity 远程更新都需要服务器，所以不做远程推送。
- 扩展（小组件、控制中心控件）要调用 Cloudflare，就得和主 app 共享 Keychain，属于安全敏感改动，必须做成用户自己开启。

| 能力 | 用途 | 方案 | 优先级 |
|---|---|---|---|
| 深链 | `cfpanel://zone/{id}/dns` 等 | 小组件、快捷指令、通知跳转都依赖它；随路由重构一起做 | 高（基础） |
| App Intents + 快捷指令 | 查看站点状态、清除缓存、开关 Under Attack | 在 app 进程内执行（不共享 Keychain）；改线上配置的操作要求设备已解锁并确认 | 高 |
| 控制中心控件 | 一键开关某个站点的 Under Attack | 需要共享 Keychain，做成可选开启 | 中 |
| 小组件 | 站点状态、今日流量 | 需要共享 Keychain，可选开启；组件快照会被系统缓存，要在隐私说明里写清楚 | 中 |
| Live Activity | Under Attack 开启计时、部署进行中 | 只在本地更新，并设置过期时间 | 低 |
| Spotlight 索引 | 搜索站点名 | 会把站点名持久化到系统索引，和「业务数据只放内存」冲突，不做或做成明确可选 | 低 |

---

## 8. 工程改造

- **最低系统版本 17 → 26**：截至 2026 年 6 月，79% 的 iPhone、近四年机型中 86% 已在 iOS 26。升级后 Liquid Glass、tab 底部附件、工具栏间隔、搜索 tab 都不用写兼容分支，只有 iOS 27 新 API 需要 `#available`。
- **路由**：全局 `Route` 枚举加一个路由器，支持深链和跨 tab 跳转；统一使用基于值的 `NavigationLink`。
- **依赖注入**：41 个 `.environment` 合并成少量按功能分组的环境对象，或由 `AppContainer` 集中提供，避免漏注入导致崩溃。
- **测试**：
  1. 每个接口模型用真实响应 JSON 做解析测试（这次 `foundation_dns` 就是这类问题）。
  2. view model 用 `URLProtocol` 桩做请求测试。
  3. 关键路径 UI 测试（可选）。
- **CI**：GitHub Actions 编译加测试（`CODE_SIGNING_ALLOWED=NO` 已验证能编译）。
- **容错解析**：枚举遇到未知值降级为 unknown；非关键字段一律可选，Cloudflare 改字段时页面不至于直接加载失败。
- **限流**：传输层读取 `Ratelimit` / `Retry-After` 响应头做退避；控制一次刷新的并发请求数。
- **支持用户级 API Token**：目前只支持账号 Token。Workers 构建接口只接受用户级 Token，dev.md 里也承诺过这一项。
- **跟踪 API 变更**：每月对照一次 Cloudflare 废弃公告；⚠️ 可以评估用 Cloudflare 官方 OpenAPI 描述写一个接口对照脚本。
- **清理**：删死代码；拆大文件（`AuthenticationView` 961 行；`SettingsView` 657 行，里面混着站点设置页面）。
- **文档**：让 `Architecture.md`、`dev.md`、`.github/copilot-instructions.md` 和代码保持一致。
- **本地化**：用字符串拼出来的提示消息改成可本地化的写法。

---

## 9. 分阶段路线

| 版本 | 主题 | 内容 | 规模 |
|---|---|---|---|
| **1.1.1** | 紧急修复 | API 兼容（已完成，分支 `fix/cloudflare-api-compat`）；错误提示被吞；Pages/Workers 只显示前 3 个；暂停站点加确认；去掉失效的安全级别选择器；审计日志默认隐藏 `view`；改版本号。**另外请确认 OAuth 客户端已公开** | 小 |
| **1.2** | 地基 | 最低版本升到 iOS 26；测试 target + CI；容错解析；限流退避；路由与依赖注入重构；深色模式修复；30D 分析对所有套餐开放；清理死代码和文档；核实 OAuth refresh token；导出一份 `/oauth/scopes` 清单 | 中 |
| **2.0** | 新界面 | 新 tab 结构、站点主页、全局搜索；多账号；统一操作分级、提示条、撤销；Liquid Glass 视觉；新登录页（可选 scope）+ 权限清单；概览页重做 | 大 |
| **2.1** | 补齐运维能力 | 软清除缓存；账号级「仅 DNS」紧急开关；Worker 回滚；WAF/安全事件；安全洞察；IP 访问规则；常用规则模板；DNS 设置可编辑；邮件路由规则编辑；KV 前缀搜索；审计日志分页和资源历史；Queues 积压、D1 恢复、R2 对象浏览 | 中到大 |
| **2.2** | 新产品 | Tunnel 状态；告警中心；Worker 错误与日志；Workers 构建（需要用户级 Token）；Workflows；域名注册（beta）；紧急轮换 Token/Secrets | 中到大 |
| **2.3** | 系统集成 | 快捷指令；控制中心 Under Attack 开关；小组件（可选开启）；Live Activity | 中 |

为什么是这个顺序：
- 1.2 先做，因为 2.0 要大改导航，没有测试和路由基础，回归风险高。
- 2.0 的新导航决定了 2.1、2.2 的新功能放在哪里，所以新功能排在它后面。

---

## 10. 需要你拍板的决策

| # | 问题 | 建议 |
|---|---|---|
| 1 | 最低版本升到 iOS 26？ | 是 |
| 2 | 多账号、多凭证？ | 2.0 先做「一个凭证多个账号」，多凭证随后 |
| 3 | 小组件和控制中心是否允许扩展共享 Keychain？ | 先只做 app 内执行的快捷指令；扩展做成用户可选开启 |
| 4 | 保留 3 秒倒计时吗？ | 改成设置项，默认关闭；确认框保留 |
| 5 | 规则编辑做到什么程度？ | 开关 + 常用模板（封 IP/国家、限速），不做表达式编辑器 |
| 6 | 8 种语言都保留吗？ | 文案大改后要整体重译，需要评估翻译方式 |
| 7 | 2.0 一次性发布还是逐步替换？ | 一次性作为大版本发布，1.2 期间可以先发 TestFlight |
| 8 | 支持用户级 API Token 吗？ | 支持。Workers 构建接口只接受它，dev.md 也承诺过 |
| 9 | 账号级「仅 DNS」紧急开关要做吗？它影响账号下所有站点 | 做，但放在「高级危险模式」后面，确认框写明全部后果 |

---

## 11. 风险

- **导航大改带来回归**：1.2 先补测试和路由。
- **翻译成本**：文案定稿后再统一翻译，避免反复。
- **OAuth scope 不确定**：每个新功能开工前先用 `/client/v4/oauth/scopes` 核对。
- **Beta 接口变动**：新产品先做只读。
- **App 审核**：新功能需要更新给审核用的演示 token 权限。

---

## 附录：依据

**代码与实测**
- 代码盘点：导航、功能、交互、视觉、工程（文中 `文件:行号` 均指 `CFPanel/` 目录）。
- 模拟器实测（iPhone 18 Pro，iOS 27 SDK）：登录页浅色正常，深色模式背景不变、文字变白。
- App Store 数据：1.1.0，2026-07-02 发布，1 条评价。

**Cloudflare**
- [API 废弃公告](https://developers.cloudflare.com/fundamentals/api/reference/deprecations/)
- [Changelog](https://developers.cloudflare.com/changelog/)
- [创建 OAuth 客户端（默认私有、公开验证）](https://developers.cloudflare.com/fundamentals/oauth/create-an-oauth-client/)
- [OAuth 可选 scope](https://developers.cloudflare.com/changelog/post/2026-08-20-oauth-optional-scopes/)
- [OAuth scope 列表接口](https://developers.cloudflare.com/api/resources/iam/subresources/oauth_scopes)
- [安全级别](https://developers.cloudflare.com/waf/tools/security-level/)
- [审计日志 changelog](https://developers.cloudflare.com/changelog/product/audit-logs/)
- [软清除缓存](https://developers.cloudflare.com/changelog/post/2026-09-28-cache-invalidation/)
- [仅 DNS 紧急开关](https://developers.cloudflare.com/dns/proxy-status/enforce-dns-only/)
- [所有套餐 30 天分析](https://developers.cloudflare.com/changelog/post/2026-10-02-30-days-analytics-on-every-plan/)
- [SQL 分析接口](https://developers.cloudflare.com/analytics/sql-api/)
- [Workers Observability 查询](https://developers.cloudflare.com/api/resources/workers/subresources/observability/subresources/telemetry/methods/query/)
- [Workers 构建 API](https://developers.cloudflare.com/workers/ci-cd/builds/api-reference/)
- [Workflows API](https://developers.cloudflare.com/api/resources/workflows/)
- [Alerting API](https://developers.cloudflare.com/api/resources/alerting/)
- [Tunnel API](https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/)
- [Registrar API](https://developers.cloudflare.com/api/resources/registrar/)
- [Security Center](https://developers.cloudflare.com/api/resources/security_center/)
- [403 附带文档链接](https://developers.cloudflare.com/changelog/post/2026-08-20-contextual-403s/)
- [API 限流](https://developers.cloudflare.com/fundamentals/api/reference/limits/)
- [从 Pages 迁移到 Workers](https://developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/)

**Apple**
- WWDC25：323 Build a SwiftUI app with the new design；275 App Intents；278 Widgets。
- WWDC26：269 What's new in SwiftUI；278 Modernize your UIKit app；223 Live Activities。
- [iOS 版本占比](https://developer.apple.com/support/app-store/)（2026-06-07：79% 的 iPhone 在 iOS 26）
- iOS 27.1 SDK 接口文件（API 名称和可用版本以此为准）。

**仍需核实**
- CFPanel 的 OAuth 客户端是否已公开。
- 不申请 `offline_access` 时是否会下发 refresh token。
- 所有新功能对应的 OAuth scope ID，包括 Hyperdrive。
- Workers 构建接口是否接受 OAuth token；Observability 查询的权限要求。
- `invalidate_cache` 的权限名和套餐限制。
