# Cloud Mail API 文档

本文档基于 `mail-worker/src/api`、`mail-worker/src/security/security.js` 与对应 service 实现整理，覆盖当前项目后端可用接口。

## 1. 基础信息

- 基础前缀：`/api`
- Worker 内部实际路由：`/xxx`，通过 `mail-worker/src/index.js` 自动把 `/api` 前缀转发给 Hono
- 内容类型：
  - 默认 `application/json`
  - `POST /email/send` 支持 `multipart/form-data`（前端通过 axios 直接提交 form）
  - `GET /file/*` 返回二进制流
- 通用响应（JSON）：
  - 成功：`{ "code": 200, "message": "success", "data": ... }`
  - 失败：`{ "code": number, "message": string }`

## 2. 认证与权限

### 2.1 认证头

- Header：`Authorization: <token>`
- token 来源：`POST /api/login` 返回的 `data.token`

### 2.2 免认证接口

以下路径无需登录：

- `POST /api/login`
- `POST /api/register`
- `GET /api/file/*`
- `GET /api/setting/websiteConfig`
- `POST /api/webhooks`
- `GET /api/init/:secret`
- `/api/test...`（当前无实际接口实现）

### 2.3 需要权限点的接口

除登录态外，以下路径还需要权限校验（管理员邮箱 `env.admin` 例外）：

- 邮件：`/email/send`、`/email/delete`
- 邮箱账户：`/account/list`、`/account/add`、`/account/delete`
- 个人：`/my/delete`
- 角色：`/role/add`、`/role/list`、`/role/delete`、`/role/tree`、`/role/set`、`/role/setDefault`
- 全局邮件：`/allEmail/list`、`/allEmail/delete`
- 设置：`/setting/query`、`/setting/set`、`/setting/setBackground`、`/setting/physicsDeleteAll`
- 用户：`/user/list`、`/user/add`、`/user/delete`、`/user/setPwd`、`/user/setStatus`、`/user/setType`、`/user/resetSendCount`
- 统计：`/analysis/echarts`
- 注册码：`/regKey/add`、`/regKey/list`、`/regKey/delete`、`/regKey/clearNotUse`、`/regKey/history`

## 3. 常用枚举

### 3.1 用户状态 `user.status`

- `0`：正常
- `1`：禁用

### 3.2 邮件类型 `email.type`

- `0`：收件
- `1`：发件

### 3.3 邮件状态 `email.status`

- `0`：接收完成
- `1`：已发送
- `2`：投递成功（delivered）
- `3`：退信（bounced）
- `4`：投诉（complained）
- `5`：延迟（delivery_delayed）
- `6`：保存中
- `7`：无人收件（noone）

### 3.4 软删除标记 `isDel`

- `0`：正常
- `1`：已删除

## 4. 接口明细

---

## 4.1 认证模块

### 4.1.1 登录

- 方法/路径：`POST /api/login`
- 认证：否
- Body
  - `email` string 必填
  - `password` string 必填
- 返回 `data`
  - `token` string

### 4.1.2 注册

- 方法/路径：`POST /api/register`
- 认证：否
- Body（根据站点配置动态生效）
  - `email` string 必填，且域名必须在 `env.domain`
  - `password` string 必填，长度 `6~30`
  - `token` string 可选（开启注册验证码时必填，用于 Turnstile）
  - `code` string 可选/必填（当 regKey=OPEN 必填，OPTIONAL 可选）
- 返回：`code=200`，`data` 一般为空

### 4.1.3 退出登录

- 方法/路径：`DELETE /api/logout`
- 认证：是
- Body/Query：无
- 返回：空 `data`

---

## 4.2 个人信息模块（my）

### 4.2.1 获取当前登录用户信息

- 方法/路径：`GET /api/my/loginUserInfo`
- 认证：是
- 返回 `data` 主要字段
  - `userId` number
  - `email` string
  - `accountId` number（主邮箱账户ID）
  - `name` string
  - `sendCount` number
  - `permKeys` string[]（当前权限key）
  - `role` object（角色信息；管理员会返回固定 admin 角色配置）

### 4.2.2 修改当前用户密码

- 方法/路径：`PUT /api/my/resetPassword`
- 认证：是
- Body
  - `password` string 必填（最小6位）
- 返回：空 `data`

### 4.2.3 注销当前用户

- 方法/路径：`DELETE /api/my/delete`
- 认证：是 + 权限 `my:delete`
- 返回：空 `data`

---

## 4.3 邮箱账户模块（account）

### 4.3.1 获取当前用户邮箱账户列表

- 方法/路径：`GET /api/account/list`
- 认证：是 + 权限 `account:query`
- Query
  - `accountId` number 可选（游标，默认0，只查大于该ID）
  - `size` number 可选（最大30）
- 返回：账户数组（`accountId/email/name/userId/...`）

### 4.3.2 新增邮箱账户

- 方法/路径：`POST /api/account/add`
- 认证：是 + 权限 `account:add`
- Body
  - `email` string 必填，必须合法邮箱且域名在 `env.domain`
  - `token` string 可选（开启 addEmailVerify 时用于 Turnstile）
- 返回：新增账户对象

### 4.3.3 修改邮箱账户名称

- 方法/路径：`PUT /api/account/setName`
- 认证：是
- Body
  - `accountId` number 必填
  - `name` string 必填（长度 <= 30）
- 返回：空 `data`

### 4.3.4 删除邮箱账户（软删除）

- 方法/路径：`DELETE /api/account/delete`
- 认证：是 + 权限 `account:delete`
- Query
  - `accountId` number 必填
- 返回：空 `data`

---

## 4.4 邮件模块（email）

### 4.4.1 邮件列表（按账户+类型）

- 方法/路径：`GET /api/email/list`
- 认证：是
- Query
  - `accountId` number 必填
  - `type` number 必填（`0`收件、`1`发件）
  - `emailId` number 可选（游标）
  - `timeSort` number 可选（`1`升序拉新；否则降序）
  - `size` number 可选（最大30）
- 返回 `data`
  - `list` 邮件数组（含 `attList`、`isStar`）
  - `total` number
  - `latestEmail` object | null

### 4.4.2 拉取最新收件

- 方法/路径：`GET /api/email/latest`
- 认证：是
- Query
  - `accountId` number 必填
  - `emailId` number 必填（只查大于该ID）
- 返回：邮件数组（最多20条，含 `attList`）

### 4.4.3 删除邮件（软删除）

- 方法/路径：`DELETE /api/email/delete`
- 认证：是 + 权限 `email:delete`
- Query
  - `emailIds` string 必填，逗号分隔（如 `1,2,3`）
- 返回：空 `data`

### 4.4.4 邮件附件列表

- 方法/路径：`GET /api/email/attList`
- 认证：是
- Query：透传给 `attService.list`，常用为邮件ID相关查询
- 返回：附件数组

### 4.4.5 发送邮件

- 方法/路径：`POST /api/email/send`
- 认证：是 + 权限 `email:send`
- Body（JSON 或 multipart form）
  - `accountId` number 必填（发件账户）
  - `name` string 可选（发件人名称，不填默认邮箱名前缀）
  - `sendType` string 可选（`reply` 表示回复）
  - `emailId` number 可选（回复时必填，被回复邮件ID）
  - `receiveEmail` string[] 必填（收件人邮箱列表）
  - `manyType` string 必填（`merge` / `divide`）
  - `subject` string 可选
  - `text` string 可选（纯文本）
  - `content` string 可选（HTML内容）
  - `attachments` array 可选（附件列表；`manyType=divide` 时不支持）
- 返回：已发送邮件记录数组（每条含 `emailId`、`status`、`attList` 等）

---

## 4.5 星标模块（star）

### 4.5.1 添加星标

- 方法/路径：`POST /api/star/add`
- 认证：是
- Body
  - `emailId` number 必填
- 返回：空 `data`

### 4.5.2 取消星标

- 方法/路径：`DELETE /api/star/cancel`
- 认证：是
- Query
  - `emailId` number 必填
- 返回：空 `data`

### 4.5.3 星标列表

- 方法/路径：`GET /api/star/list`
- 认证：是
- Query
  - `emailId` number 可选（游标，默认很大值）
  - `size` number 可选
- 返回 `data`
  - `list` 邮件数组（固定 `isStar=1`，含 `attList`）

---

## 4.6 用户管理模块（user）

### 4.6.1 用户列表

- 方法/路径：`GET /api/user/list`
- 认证：是 + 权限 `user:query`
- Query（常用）
  - `num` number 页码（从1开始）
  - `size` number 页大小（最大50）
  - `email` string 可选（前缀匹配）
  - `status` number 可选（`0/1`）
  - `isDel` number 可选（`0/1`）
  - `timeSort` number 可选
- 返回 `data`
  - `list` 用户数组（含统计字段：收件数/发件数/邮箱数及删除态统计）
  - `total` number

### 4.6.2 新增用户

- 方法/路径：`POST /api/user/add`
- 认证：是 + 权限 `user:add`
- Body
  - `email` string 必填
  - `password` string 必填（最小6位）
  - `type` number 必填（角色ID）
- 返回：空 `data`

### 4.6.3 删除用户（物理删除）

- 方法/路径：`DELETE /api/user/delete`
- 认证：是 + 权限 `user:delete`
- Query
  - `userId` number 必填
- 返回：空 `data`

### 4.6.4 管理员修改用户密码

- 方法/路径：`PUT /api/user/setPwd`
- 认证：是 + 权限 `user:set-pwd`
- Body
  - `userId` number 必填
  - `password` string 必填
- 返回：空 `data`

### 4.6.5 设置用户状态

- 方法/路径：`PUT /api/user/setStatus`
- 认证：是 + 权限 `user:set-status`
- Body
  - `userId` number 必填
  - `status` number 必填（`0/1`）
- 返回：空 `data`

### 4.6.6 设置用户角色

- 方法/路径：`PUT /api/user/setType`
- 认证：是 + 权限 `user:set-type`
- Body
  - `userId` number 必填
  - `type` number 必填（角色ID）
- 返回：空 `data`

### 4.6.7 重置用户发信计数

- 方法/路径：`PUT /api/user/resetSendCount`
- 认证：是 + 权限 `user:reset-send`
- Body
  - `userId` number 必填
- 返回：空 `data`

### 4.6.8 恢复用户（取消删除）

- 方法/路径：`PUT /api/user/restore`
- 认证：是
- Body
  - `userId` number 必填
  - `type` number 可选（传值时会同时恢复该用户邮件和账户）
- 返回：空 `data`

---

## 4.7 角色与权限模块（role）

### 4.7.1 添加角色

- 方法/路径：`POST /api/role/add`
- 认证：是 + 权限 `role:add`
- Body
  - `name` string 必填
  - `permIds` number[] 必填（可空数组）
  - `banEmail` string[] 必填（可空数组，必须是邮箱格式）
  - 其他字段：`sendCount`、`sendType`、`accountCount`、`description`、`sort` 等
- 返回：空 `data`

### 4.7.2 更新角色

- 方法/路径：`PUT /api/role/set`
- 认证：是 + 权限 `role:set`
- Body
  - `roleId` number 必填
  - `name` string 必填
  - `permIds` number[] 必填
  - `banEmail` string[] 必填
  - 其他可更新字段同新增
- 返回：空 `data`

### 4.7.3 设置默认角色

- 方法/路径：`PUT /api/role/setDefault`
- 认证：是 + 权限 `role:set`
- Body
  - `roleId` number 必填
- 返回：空 `data`

### 4.7.4 删除角色

- 方法/路径：`DELETE /api/role/delete`
- 认证：是 + 权限 `role:delete`
- Query
  - `roleId` number 必填
- 返回：空 `data`

### 4.7.5 角色列表

- 方法/路径：`GET /api/role/list`
- 认证：是 + 权限 `role:query`
- 返回：角色数组（每项含 `permIds`、`banEmail` 等）

### 4.7.6 可选角色列表（下拉）

- 方法/路径：`GET /api/role/selectUse`
- 认证：是
- 返回：`[{ roleId, name }]`

### 4.7.7 权限树

- 方法/路径：`GET /api/role/permTree`
- 认证：是
- 返回：权限树结构

---

## 4.8 全局邮件管理模块（allEmail）

### 4.8.1 全局邮件查询

- 方法/路径：`GET /api/allEmail/list`
- 认证：是 + 权限 `all-email:query`
- Query（常用）
  - `emailId` number 游标
  - `size` number 最大30
  - `type` string 可选：`send`、`receive`、`delete`、`noone`
  - `name` string 可选
  - `subject` string 可选
  - `accountEmail` string 可选（匹配 toEmail/sendEmail）
  - `userEmail` string 可选
  - `timeSort` number 可选
- 返回 `data`
  - `list` 邮件数组（含 `userEmail`、`attList`）
  - `total` number

### 4.8.2 全局邮件物理删除

- 方法/路径：`DELETE /api/allEmail/delete`
- 认证：是 + 权限 `all-email:delete`
- Query
  - `emailIds` string 必填，逗号分隔
- 返回：空 `data`

---

## 4.9 设置模块（setting）

### 4.9.1 更新系统设置

- 方法/路径：`PUT /api/setting/set`
- 认证：是 + 权限 `setting:set`
- Body：setting 表字段子集，常用：
  - `title` string
  - `register` number
  - `addEmail` number
  - `manyEmail` number
  - `send` number
  - `autoRefreshTime` number
  - `registerVerify` number
  - `addEmailVerify` number
  - `r2Domain` string
  - `siteKey` string
  - `secretKey` string
  - `resendTokens` object（会与已有 token merge）
  - `regKey` number
- 返回：空 `data`

### 4.9.2 查询系统设置（脱敏）

- 方法/路径：`GET /api/setting/query`
- 认证：是 + 权限 `setting:query`
- 返回：设置对象（`secretKey` 与 `resendTokens` 会脱敏显示）

### 4.9.3 网站公开配置

- 方法/路径：`GET /api/setting/websiteConfig`
- 认证：否
- 返回：前端初始化所需公开配置（注册开关、站点标题、验证码配置、背景图、域名列表等）

### 4.9.4 上传登录背景

- 方法/路径：`PUT /api/setting/setBackground`
- 认证：是 + 权限 `setting:set`
- Body
  - `background` string 必填（base64）
- 返回：上传后的对象 key

### 4.9.5 物理清理已删除数据

- 方法/路径：`DELETE /api/setting/physicsDeleteAll`
- 认证：是 + 权限 `setting:clean`
- 行为：级联清理已删除邮件、账户、用户数据
- 返回：空 `data`

---

## 4.10 注册码模块（regKey）

### 4.10.1 注册码列表

- 方法/路径：`GET /api/regKey/list`
- 认证：是 + 权限 `reg-key:query`
- Query
  - `code` string 可选（前缀匹配）
- 返回：注册码数组（含 `roleName`）

### 4.10.2 新增注册码

- 方法/路径：`POST /api/regKey/add`
- 认证：是 + 权限 `reg-key:add`
- Body
  - `code` string 必填
  - `roleId` number 必填
  - `count` number 必填
  - `expireTime` string 必填（日期时间）
- 返回：空 `data`

### 4.10.3 删除注册码

- 方法/路径：`DELETE /api/regKey/delete`
- 认证：是 + 权限 `reg-key:delete`
- Query
  - `regKeyIds` string 必填，逗号分隔
- 返回：空 `data`

### 4.10.4 清理无效注册码

- 方法/路径：`DELETE /api/regKey/clearNotUse`
- 认证：是 + 权限 `reg-key:delete`
- 行为：删除次数为0或已过期的注册码
- 返回：空 `data`

### 4.10.5 注册码使用历史

- 方法/路径：`GET /api/regKey/history`
- 认证：是 + 权限 `reg-key:query`
- Query
  - `regKeyId` number 必填
- 返回：用户简表数组（`email`、`createTime`）

---

## 4.11 分析模块（analysis）

### 4.11.1 仪表盘统计

- 方法/路径：`GET /api/analysis/echarts`
- 认证：是 + 权限 `analysis:query`
- Query
  - `timeZone` string 必填（如 `Asia/Shanghai`）
- 返回 `data`
  - `numberCount`：总数统计
  - `userDayCount`：近15天用户增长
  - `receiveRatio.nameRatio`：收件发件人占比
  - `emailDayCount.receiveDayCount/sendDayCount`：近15天邮件趋势
  - `daySendTotal`：当日发送总数

---

## 4.12 文件与回调模块

### 4.12.1 下载/访问对象存储文件

- 方法/路径：`GET /api/file/*`
- 认证：否
- 路径参数：`*` 为对象 key（如 `attachments/xxx.png`）
- 返回：文件流（`Content-Type` 和 `Content-Disposition` 由对象元数据决定）

### 4.12.2 Resend Webhook

- 方法/路径：`POST /api/webhooks`
- 认证：否
- Body：Resend webhook 事件体
  - 关注事件：`email.delivered`、`email.complained`、`email.bounced`、`email.delivery_delayed`
  - 关键字段：`type`、`data.email_id`、`data.bounce`
- 返回：纯文本
  - 成功：`success`
  - 失败：错误信息，状态码 `500`

---

## 4.13 初始化模块

### 4.13.1 初始化/升级数据库结构

- 方法/路径：`GET /api/init/:secret`
- 认证：否
- 路径参数
  - `secret` string
- 逻辑说明
  - 当前实现中：当 `secret !== env.jwt_secret` 时直接返回 `Successfully initialized`
  - 当 `secret === env.jwt_secret` 时执行数据库初始化与迁移、刷新设置缓存并返回“初始化成功”
- 典型用途
  - 首次部署后初始化 D1/KV
  - 版本升级后执行结构同步

## 5. 错误码约定

- `200`：成功
- `401`：登录失效/认证失败
- `403`：权限不足或业务受限（例如发送权限不足、功能关闭）
- `500`：业务异常或系统异常

## 6. 前端请求参考

前端已封装请求可直接对照：

- `mail-vue/src/request/login.js`
- `mail-vue/src/request/my.js`
- `mail-vue/src/request/account.js`
- `mail-vue/src/request/email.js`
- `mail-vue/src/request/star.js`
- `mail-vue/src/request/user.js`
- `mail-vue/src/request/role.js`
- `mail-vue/src/request/setting.js`
- `mail-vue/src/request/all-email.js`
- `mail-vue/src/request/analysis.js`
- `mail-vue/src/request/reg-key.js`
