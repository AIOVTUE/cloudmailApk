# CloudMail

Cloud-Mail 基于 Cloudflare 的简约响应式邮箱服务，支持邮件发送、附件收发
项目地址 [cloud-mail](https://github.com/maillab/cloud-mail)
本项目是基于该项目制作的安卓apk
## 预览图
收件箱
![](https://pic1.imgdb.cn/item/69f6205ebd91a69b7b941eec.png)
设置页
![](https://pic1.imgdb.cn/item/69f6208bbd91a69b7b941f56.png)
邮件预览页面
![](https://pic1.imgdb.cn/item/69f620d2bd91a69b7b941fee.png)


## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter |
| 状态管理 | Riverpod |
| 网络请求 | Dio |
| 路由导航 | GoRouter |
| 数据类 | Freezed + JSON Serializable |
| 安全存储 | flutter_secure_storage |
| 本地存储 | shared_preferences |
| 图表 | fl_chart |

## 功能特性

### 邮件核心功能
- 收件箱 / 发件箱 / 草稿箱
- 邮件详情查看与附件下载
- 写信、回复、转发
- 星标邮件管理
- 本地草稿保存
- 离线缓存支持

### 账户与个人设置
- 多邮箱账户管理（添加、删除、重命名）
- 个人资料管理
- 修改密码 / 注销账号
- 主题切换（浅色/深色/跟随系统）
- 邮件轮询间隔设置

### 管理员功能（按权限显示）
- 用户管理（增删改、禁用/启用、权限分配）
- 角色管理
- 全局邮件管理
- 系统设置
- 注册码管理
- 数据分析图表

### 技术特性
- 动态站点地址配置
- 记住密码 + 安全令牌存储
- 会话自动恢复
- 统一响应解析与错误处理
- 401 自动退出登录
- 请求日志与耗时监控（日志脱敏处理）

## 项目结构

```
lib/
├── main.dart                      # 应用入口
└── src/
    ├── app.dart                   # 主应用组件
    ├── core/                      # 核心公共模块
    │   ├── auth/                  # 认证与会话
    │   ├── config/                # 配置格式化
    │   ├── logging/               # 日志模块
    │   ├── network/               # 网络请求与响应解析
    │   ├── routing/               # 路由配置
    │   ├── storage/               # 本地存储
    │   ├── theme/                 # 主题配置
    │   ├── widgets/               # 通用组件
    │   └── providers.dart         # 全局 Provider
    └── features/                  # 功能模块
        ├── account/               # 账户管理
        ├── admin/                 # 管理后台
        ├── auth/                  # 登录认证
        ├── mail/                  # 邮件功能
        ├── profile/               # 个人中心
        └── settings/              # 应用设置
```

## 运行项目

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run
```

## 打包构建

### Android APK
```bash
flutter build apk --release
```
产物位于：`build/app/outputs/flutter-apk/app-release.apk`

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web
```

## API 接口映射

| 功能 | 接口路径 |
|------|----------|
| 登录 | `POST /api/login` |
| 退出登录 | `DELETE /api/logout` |
| 当前用户信息 | `GET /api/my/loginUserInfo` |
| 修改密码 | `PUT /api/my/resetPassword` |
| 邮箱账户列表 | `GET /api/account/list` |
| 收件箱/发件箱 | `GET /api/email/list` |
| 邮件详情/附件 | `GET /api/email/attList` |
| 发送邮件 | `POST /api/email/send` |
| 删除邮件 | `DELETE /api/email/delete` |
| 星标操作 | `POST /api/star/add` / `DELETE /api/star/cancel` |
| 用户管理 | `GET/POST/PUT/DELETE /api/user/*` |
| 角色管理 | `GET/POST/PUT/DELETE /api/role/*` |
| 系统设置 | `GET/PUT /api/setting/*` |
| 注册码管理 | `GET/POST/DELETE /api/regKey/*` |
| 数据分析 | `GET /api/analysis/echarts` |

## 权限说明

管理员功能通过 `permKeys` 权限标识控制：

| 模块 | 权限标识 |
|------|----------|
| 用户管理 | `user:query` `user:add` `user:set-status` `user:set-type` `user:reset-send` `user:delete` |
| 角色管理 | `role:query` `role:add` `role:set` `role:delete` |
| 全局邮件 | `all-email:query` `all-email:delete` |
| 系统设置 | `setting:query` `setting:set` `setting:clean` |
| 注册码 | `reg-key:query` `reg-key:add` `reg-key:delete` |
| 数据分析 | `analysis:query` |
| 账户管理 | `account:query` `account:add` `account:delete` |
| 邮件操作 | `email:send` `email:delete` |

## 测试

项目包含单元测试和 widget 测试，位于 `test/` 目录：

```bash
flutter test
```


