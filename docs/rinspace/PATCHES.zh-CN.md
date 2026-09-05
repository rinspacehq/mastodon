# Rinspace fork 补丁清单

[English](./PATCHES.md)

本文档是 Mastodon 上游与公开 Rinspace fork 之间的升级边界，不代表允许开启联邦或执行生产部署。Rinspace 第一期保持严格本地；每个行为变化都必须是可评审的明确补丁，不能来自未记录的服务器热改。

## 基线

| 字段 | 值 |
| --- | --- |
| Fork 仓库 | `lunifans/mastodon` |
| 上游仓库 | `mastodon/mastodon` |
| Fork 提交 | `0a32b4a831838ef1f363a915c2e71e2a1b52cf0d` |
| 核查时上游 `main` | `0a32b4a831838ef1f363a915c2e71e2a1b52cf0d` |
| Describe | `v4.7.0-beta.1-180-g0a32b4a83` |
| Rinspace 逻辑补丁数量 | `10`（工作树状态，不是发布版） |
| 记录日期 | `2026-09-05` |

实现尚未提交时，下列编号代表可独立评审的逻辑补丁。正式发布必须把工作树标记替换为不可变提交，并拒绝发布 dirty 工作树。

## 补丁分类

- `upstreamable`：适用于一般 Mastodon 实例、可向上游提交的修复或改进。
- `rinspace-product`：Rinspace 表里世界专有行为，例如共享壳层或 `/p/:id/:slug` 网页路由。
- `long-lived-safety`：每次上游升级都必须保留的边界，例如严格本地的联邦控制。

## 当前清单

| ID | 分类 | 上游基线 | 变更区域 | 验证 | 许可证/API 影响 | 升级说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `RIN-001` | `long-lived-safety` | `0a32b4a831838ef1f363a915c2e71e2a1b52cf0d` | local-only Rack/Sidekiq 门禁、抓取/搜索/信息流/API 边界、边缘和出口策略、审计任务 | local-only 聚焦 RSpec；发布前运行 `rails rinspace:local_only:audit` | 不扩展公开 API；运营方必须提供本 AGPL fork 源码 | 每次升级重新审计 resolver、联邦路由、worker、FASP 与出站请求 |
| `RIN-002` | `rinspace-product` | 同上 | `/p/:id/:slug`、slug v1、REST/Web 元数据和客户端链接；旧帖子地址 404 | Ruby/TypeScript 共享 fixture、请求测试和路由审计 | 公开网页 URL 改变；ActivityPub 标识保持不变 | rebase 后复查帖子、引用、通知、搜索、分享和 oEmbed 链接生成器 |
| `RIN-003` | `rinspace-product` | 同上 | 固定 `world-shell` 制品、共享顶栏、里世界布局与 adapter | `yarn typecheck`、生产 Vite 构建、锁文件摘要校验 | 打包兼容 AGPL 的公开包并保留源码清单 | 正式版必须重新安装 clean、不可变制品，不能发布当前 dirty 开发锁 |
| `RIN-004` | `long-lived-safety` | 同上 | 客户端路由规范化、路由清单、PWA 启动地址、Service Worker 缓存与 push 落点 | `yarn audit:rinspace-routes`；Service Worker 与路径聚焦 Vitest | 改变 PWA 导航及缓存行为 | 新增上游路由必须先进入公开契约，否则审计失败 |
| `RIN-005` | `long-lived-safety` | 同上 | 预配 OIDC 身份、签名身份/标签/关注 API、资料与 handle 生命周期 | binding、服务签名、OIDC 和领域服务聚焦测试 | 新增私有集成 API；密钥仅留服务端 | 保留冲突 fail closed 与删除终态语义 |
| `RIN-006` | `long-lived-safety` | 同上 | 全局受治理写入身份门禁和 Control Plane 审核 | 写入口请求测试与审核客户端测试 | 改变 mutation 行为并依赖审核服务 | 每次 rebase 重新枚举全部上游写 controller |
| `RIN-007` | `rinspace-product` | 同上 | 本地 Gorse 候选、二次权限过滤推荐、反馈与用户控制 | Gorse、推荐和偏好设置测试 | 新增本地偏好与 timeline API | Gorse 只排序，授权始终由 Mastodon 决定 |
| `RIN-008` | `rinspace-product` | 同上 | 聚合 `views_count`、Redis HMAC 去重、可见性序列化和客户端观察 | 请求、worker 与 TypeScript 检查 | REST Status 增加可选字段和本地写端点 | 浏览计数与推荐阅读反馈保持分离 |
| `RIN-009` | `long-lived-safety` | 同上 | 追加式审核/浏览量数据库迁移和校验 | 隔离 PostgreSQL 迁移与聚焦 Rails 套件 | 扩展数据库 schema | 观察后再 contract；生产只做前向修复 |
| `RIN-010` | `long-lived-safety` | 同上 | 认证写入、推荐、浏览量三个独立灰度门禁 | 分别关闭开关的请求测试；检查非测试默认值 | 增加运营环境变量且默认 fail closed | 部署新镜像不能自动开放阶段；签署灰度证据前保持 false |

## 升级检查表

1. 拉取上游并记录旧 fork 提交、旧上游基线、拟升级上游提交、Ruby/Node/包管理器版本、PostgreSQL/Redis 支持范围以及容器 tag 或 digest。
2. 新建专用升级分支，禁止 rebase 或强制移动已经部署的 release tag。
3. 按 ID 顺序重放清单中的补丁。遇到冲突时必须保留已记录不变量，或停止并重新设计；不得静默选择任一侧。
4. 按版本化 Rinspace 世界路由契约重新枚举 Rails、React Router、API、OAuth、streaming、媒体、ActivityPub、WebFinger、NodeInfo、Sidekiq delivery 和 Service Worker 路由。
5. 证明严格本地模式在边缘、应用、worker 和网络出口同时有效。只要上游新增的远端 resolver、inbox、delivery 路径或后台任务尚未分类并关闭，就阻止升级。
6. 先为每个补丁运行最小检查，再运行相关 Mastodon Ruby、JavaScript、无障碍、迁移和生产资源测试；在变更中记录准确命令和结果。
7. 审核全部 REST/entity/type 变化，并按需要更新公共 API 文档或 Rinspace 契约 fixture。
8. 审核 AGPL 源码提供方式、复制材料、依赖许可证、数据库迁移可逆性和面向运营者的配置变化。
9. 构建不可变镜像与源码制品，记录 digest、准确 fork 提交以及消费的 `@rinspace/world-shell`/世界路由版本，并在批准发布前演练回滚。

## 不可妥协的不变量

- 帖子网页地址只使用 `/p/:id` 与 `/p/:id/:slug`；上游 `/@username/:statusId` 及 `/embed` 形式返回 `404`，不重定向。
- 本地身份绑定使用稳定 Rinspace subject；handle 冲突必须 fail closed，不得生成带后缀的新账号。
- Mastodon 是本地社交关注图的唯一事实源。
- 联邦代码可以保留在源码中，但一期的入站、出站、发现、远端解析、投递和远端展示必须关闭且可观测。
- fork 只消费准确版本的公共契约制品；release 不复制未版本化的 Rinspace 前端工作树，也不使用浮动分支或 tag。
