# CloudMail Mobile（Flutter）

## 1. 运行方式

```bash
flutter pub get
flutter run
```

## 2. 打包 APK

```bash
flutter build apk --release
```

产物默认位于：`build/app/outputs/flutter-apk/app-release.apk`

## 3. 功能映射（网页 -> 移动端 -> API）

| 网页功能 | 移动页面 | API |
|---|---|---|
| 登录 | 登录页 | `POST /api/login` |
| 退出登录 | 我的页 | `DELETE /api/logout` |
| 当前用户信息 | 我的页 | `GET /api/my/loginUserInfo` |
| 修改密码 | 安全设置 | `PUT /api/my/resetPassword` |
| 注销账号 | 安全设置 | `DELETE /api/my/delete` |
| 邮箱账户列表/增删改名 | 账户管理页 | `GET /api/account/list` `POST /api/account/add` `PUT /api/account/setName` `DELETE /api/account/delete` |
| 收/发件列表 | 收件箱、发件箱 | `GET /api/email/list` |
| 拉取最新收件 | 收件箱下拉刷新/轮询 | `GET /api/email/latest` |
| 邮件详情/附件 | 邮件详情页 | `GET /api/email/attList` `GET /api/file/*` |
| 写邮件/回复/附件 | 写信页 | `POST /api/email/send` |
| 删除邮件 | 列表与详情操作 | `DELETE /api/email/delete` |
| 星标/取消/列表 | 星标页与列表快捷操作 | `POST /api/star/add` `DELETE /api/star/cancel` `GET /api/star/list` |
| 用户管理 | 管理-用户 | `GET /api/user/list` `POST /api/user/add` `PUT /api/user/setStatus` `PUT /api/user/setType` `PUT /api/user/resetSendCount` `DELETE /api/user/delete` `PUT /api/user/restore` |
| 角色管理 | 管理-角色 | `GET /api/role/list` `POST /api/role/add` `PUT /api/role/set` `DELETE /api/role/delete` `PUT /api/role/setDefault` `GET /api/role/permTree` `GET /api/role/selectUse` |
| 全局邮件管理 | 管理-全局邮件 | `GET /api/allEmail/list` `DELETE /api/allEmail/delete` |
| 系统设置 | 管理-设置 | `GET /api/setting/query` `PUT /api/setting/set` `PUT /api/setting/setBackground` `DELETE /api/setting/physicsDeleteAll` |
| 注册码管理 | 管理-注册码 | `GET /api/regKey/list` `POST /api/regKey/add` `DELETE /api/regKey/delete` `DELETE /api/regKey/clearNotUse` `GET /api/regKey/history` |
| 分析统计 | 管理-分析图表 | `GET /api/analysis/echarts` |

## 4. 权限矩阵（permKeys）

页面入口与操作按钮均通过 `permKeys` 控制：

- 用户：`user:query` `user:add` `user:set-status` `user:set-type` `user:reset-send` `user:delete`
- 角色：`role:query` `role:add` `role:set` `role:delete`
- 全局邮件：`all-email:query` `all-email:delete`
- 设置：`setting:query` `setting:set` `setting:clean`
- 注册码：`reg-key:query` `reg-key:add` `reg-key:delete`
- 分析：`analysis:query`
- 账户：`account:query` `account:add` `account:delete`
- 邮件：`email:send` `email:delete`
- 个人：`my:delete`

## 5. 目录说明

- `lib/core`：网络、错误处理、路由、主题、存储、通用组件
- `lib/features/auth`：登录、会话恢复、安全退出
- `lib/features/mail`：收发件、详情、星标、写信、草稿、离线缓存
- `lib/features/account`：邮箱账户管理
- `lib/features/profile`：我的、密码、注销、本地清理
- `lib/features/admin`：用户/角色/设置/注册码/分析/全局邮件管理
- `lib/features/settings`：主题、轮询间隔等偏好

## 6. 已实现/未实现清单

### 已实现

- 动态站点地址 + 记住我 + 自动恢复会话
- 邮件核心流程（列表、详情、发送、附件上传、星标、删除、回复）
- 本地草稿与最近邮件缓存
- 账户管理、个人信息与安全设置
- 管理模块（按权限显示并支持核心读写）
- 统一错误处理与日志抽象
- 单元测试与基础 Widget 测试

### 暂未实现

- 推送通知与后台常驻轮询
- 真正的 HTML 富文本可视化拖拽编辑能力（当前以插件基础能力 + HTML 内容发送为主）

## 7. 截图

截图放置在：`doc/mobile/`
