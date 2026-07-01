# CFPanel

[English](./README.md)

面向 iPhone 和 iPad 的原生 Cloudflare 管理工具。

CFPanel 是一个独立开发的 iOS 客户端，适合那些希望在移动设备上查看基础设施状态、处理突发情况、以及直接对 Cloudflare 进行有针对性操作的用户，而不是在手机浏览器里勉强使用桌面控制台。

## 相关链接

- App Store: [CFPanel 下载页](https://apps.apple.com/us/app/cfpanel/id6760587250)
- 官网: [cfpanel.zhaohe.org](https://cfpanel.zhaohe.org)
- GitHub: [resistanceto/CFPanel](https://github.com/resistanceto/CFPanel)

## 截图

<table>
  <tr>
    <td><img src="./docs/images/IMG_9122.webp" alt="CFPanel 截图 1" width="240"></td>
    <td><img src="./docs/images/IMG_9123.webp" alt="CFPanel 截图 2" width="240"></td>
    <td><img src="./docs/images/IMG_9124.webp" alt="CFPanel 截图 3" width="240"></td>
  </tr>
</table>


## 为什么会有 CFPanel

Cloudflare 已经成为很多人日常开发、部署和运维的一部分，但当你真的需要在手机上快速处理事情时，移动端网页控制台通常并不好用。

CFPanel 之所以能够存在，也离不开 Cloudflare 对开发者生态的开放。它让个人开发者和小团队也能接触到原本并不容易获得的基础设施能力，这也是像 CFPanel 这样的第三方工具能够成立的重要原因。

CFPanel 就是为这些场景而做的：

- 快速查看站点或账户状态
- 不在电脑前时也能检查基础设施
- 处理紧急 DNS 或安全操作
- 在手机上查看 Workers、Pages、存储资源和平台级资产

## 能做什么

CFPanel 聚焦于真实的运维工作流，包括：

- 使用 Cloudflare OAuth 或 Scoped Token 登录
- 浏览站点和 Zone
- 管理 DNS 记录
- 查看和调整 TLS、缓存与安全设置
- 查看 Workers 脚本与路由
- 查看 Pages 项目与部署情况
- 查看 KV、R2、D1、Queues、Vectorize 等账户级资源
- 处理 Rulesets 和部分应急操作

## 信任模型

CFPanel 的设计原则很简单：

- 设备直接连接 Cloudflare
- 没有中继凭证的后端服务
- 只请求必要的权限
- 敏感凭证存放在 Keychain
- 业务数据按需实时获取

对于 Cloudflare 管理类应用来说，这一点很重要。CFPanel 不只是要“能用”，还必须“值得信任”。

## 为什么是免费的

同类工具里，很多都会把关键能力放到订阅或付费功能里。

CFPanel 不这样做。

这个项目从一开始就是抱着回馈社区的想法去做的，我不希望把核心的基础设施操作能力锁进付费墙里。

## 支持 CFPanel

如果 CFPanel 确实帮你节省了时间，或者让你在手机上管理 Cloudflare 更高效，那么你的支持会帮助这个项目持续下去。

这些支持主要会用于：

- 持续维护
- App Store 上架相关成本
- 测试设备
- Cloudflare API 兼容性维护
- UI 和认证体验打磨

支持完全是自愿的，但确实很重要。

- 支持 CFPanel: [afdian.com/a/ResistanceTo](https://afdian.com/a/ResistanceTo)

你也可以通过这些方式帮助项目：

- 分享给别人
- 提交有价值的反馈
- 给项目点 Star
- 在 App Store 留下评价

## 项目说明

- CFPanel 是一个独立第三方客户端
- 面向 Cloudflare 生态构建，并直接使用 Cloudflare 官方公开 API
- Cloudflare 相关名称和商标归 Cloudflare, Inc. 所有
