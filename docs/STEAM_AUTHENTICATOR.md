# Steam 账号登录与令牌迁移

本文档说明 OTP Token 的 Steam 账号能力（登录 / 添加 / 迁移 / 扫码登录 / 交易确认 / 撤销）的实现结构、协议流程与安全约定。

> 面向维护者。用户侧使用方式见 [README_CN.md](README_CN.md)。

## 1. 功能范围

| 能力 | 入口 | 说明 |
|---|---|---|
| 登录 Steam 并迁移令牌 | 添加菜单 → Steam 令牌 → 顶部「登录 Steam 迁移令牌」 | 账号密码 + 两步验证 → 自动判定「新增验证器」或「迁移已有验证器」 |
| mafile / 手动 / 扫码导入 | 同一页面 | **保留原有路径**，供不愿登录账号的用户使用 |
| 扫码登录（批准网页登录） | Steam 令牌右键菜单 →「Steam 扫码登录」 | 扫描 `https://s.team/q/<version>/<clientId>` |
| 交易确认 | 右键菜单 →「交易确认」 | 列表 + 逐条批准/拒绝 |
| 撤销验证器 | 右键菜单 →「撤销 Steam 验证器」 | 二次确认后调用 `RemoveAuthenticator` |

## 2. 代码结构

```
entry/src/main/ets/steam/
├── proto/
│   ├── ProtoWriter.ets        ArkTS 手写 protobuf 编码器（varint / LEN / fixed64 / 嵌套）
│   ├── ProtoReader.ets        ArkTS 手写解码器（字段迭代 + 强类型读取 + skip）
│   └── SteamMessages.ets      18 个消息的 encode/decode + 枚举（字段号取自官方 .proto）
├── PureHash.ets               纯 ArkTS SHA-1 / SHA-256 / HMAC（不依赖 cryptoFramework）
├── SteamCrypto.ets            base64 / UTF-8 / 字节序 / RSA-1024 PKCS#1 v1.5 / JWT exp
├── SteamCode.ets              Steam 5 位动态码 + server_time 偏移校正
├── SteamError.ets             EResult 表 + 中文文案 + SteamApiError
├── SteamHttp.ets              HttpTransport 接口 + NetworkKit 实现 + Steam 协议封装
├── SteamClient.ets            全部 API（登录/2FA/轮询/添加/完成/迁移/撤销/刷新/扫码/确认）
├── SteamFlow.ets              流程纯逻辑（响应 → SteamAuth / TokenConfig）
└── SteamService.ets           单例客户端 + 时间/设备 ID 工具

entry/src/main/ets/components/SteamLoginFlow.ets   AddSteamTokenPage 内嵌的 8 步引导
entry/src/main/ets/pages/SteamConfirmationsPage.ets 交易确认列表页
entry/src/main/ets/utils/SteamActions.ets          右键菜单动作（扫码登录/撤销/错误文案）
common/src/main/ets/utils/SteamAuth.ets            凭证模型 + mafile 兼容 + 分片工具
common/src/main/ets/utils/SteamSecretStore.ets     凭证的 ASSET 存取
```

## 3. 协议流程

### 3.1 登录

```
GET  /IAuthenticationService/GetPasswordRSAPublicKey/v1/?account_name=<acct>   （JSON）
  → RSA1024/PKCS1 v1.5 加密密码（EM = 00 02 PS 00 M）
POST /IAuthenticationService/BeginAuthSessionViaCredentials/v1/                （protobuf）
  → client_id / request_id / interval / allowed_confirmations / steamid
POST /IAuthenticationService/UpdateAuthSessionWithSteamGuardCode/v1/           （需要验证码时）
POST /IAuthenticationService/PollAuthSessionStatus/v1/                         （按 interval 轮询）
  → refresh_token / access_token / account_name
```

- 请求体统一为 `application/x-www-form-urlencoded`，字段 `input_protobuf_encoded=<base64>`
  - **必须对 base64 做 percent-encode**：`+` 在表单里会被解析为空格，否则只在载荷恰好含 `+` 时偶发失败（参考实现靠 `url.URLParams` 隐式编码，我们显式 `encodeURIComponent`）
- 结果判定看响应头 `x-eresult`（`1` = OK）
- 设备信息固定为移动端：`platform_type=3`、`os_type=-500`、`gaming_device_type=528`
- 公钥长度按响应**动态推导**（线上为 2048 位，256 字节 EM）；不要写死 1024 位——参考实现硬编码 `RSA1024|PKCS1`，在当前 Steam 上会失败

### 3.2 添加 / 迁移

```
POST /ITwoFactorService/AddAuthenticator/v1/?access_token=…
  成功 → confirm_type（1=SMS / 3=邮件）→ 用户输入激活码
       → FinalizeAddAuthenticator（want_more 时用**新码**重试）
  x-eresult=29 (DuplicateRequest) → 账号已有验证器 → 迁移分支
POST /ITwoFactorService/RemoveAuthenticatorViaChallengeStart/v1/     （触发短信）
POST /ITwoFactorService/RemoveAuthenticatorViaChallengeContinue/v1/  （短信码 + generate_new_token）
  → replacement_token{shared_secret, identity_secret, revocation_code, uri, …}
```

迁移要求账号已绑定并验证手机号，否则返回 `EResult 92 / 123`。

### 3.3 扫码登录

二维码内容 `https://s.team/q/<version>/<clientId>`；签名：

```
HMAC-SHA256(shared_secret, version:2B LE ‖ clientId:8B LE ‖ steamid:8B LE) → base64 → urlencode
POST /IAuthenticationService/UpdateAuthSessionWithMobileConfirmation/v1/?access_token=…
```

### 3.4 交易确认

```
GET  https://steamcommunity.com/mobileconf/getlist?p=<device_id>&a=<steamid>&t=<sec>&m=react&tag=conf&k=<sig>
POST https://steamcommunity.com/mobileconf/multiajaxop?…&op=allow|cancel&cid[]=…&ck[]=…
Cookie: dob=;steamid=<id>;steamLoginSecure=<id>||<access_token>
sig = HMAC-SHA1(identity_secret, seconds:8B BE ‖ "conf") → base64 → urlencode
```

`p=<device_id>` 必须与添加验证器时写入的 `device_id` 一致（形如 `android:<UUID>`）。

## 4. 存储模型

| 数据 | 位置 | 原因 |
|---|---|---|
| `TokenSecret`（= base32(shared_secret)） | ASSET + 加密 KV | 动态码计算；手表只靠它显示 5 位码 |
| `identity_secret`、`revocation_code` | **仅 ASSET**（`opt_steam_sec_{uuid}_id` / `_rev`） | 高权限凭证，绝不进 KV（KV 会被手表同步原样序列化） |
| `refresh_token` | **仅 ASSET**，超 900 字节自动分片（`_rt_0..n`） | JWT 可能超出 ASSET 单条上限 |
| `steamid`、`account_name`、`device_id`、`token_gid`、`uri`、`server_time` | 加密 KV（`TokenConfig.SteamAuth`） | 非敏感元数据 |
| `access_token` | 仅内存（按 JWT `exp` 缓存） | 短期凭证 |

- `TokenStore.persistTokens()` 写入 KV 前统一调用 `TokenConfig.sanitizedForTransfer()`
- `BleTokenTransfer` / `WearEngineTransfer` 下发手表前同样剥离，双重保险
- 云备份载荷在 `CloudBackupManager.backupToCloud()` 中经 `sanitizedForBackup()` 剥离后序列化
- 旧版 `SteamMaFile` 在加载时转换为 `SteamAuth`，密钥补写 ASSET，后续保存从 KV 剥离

### 各条外发路径的能力对照

| 路径 | TokenSecret（显示动态码） | 高权限凭证 | 说明 |
|---|---|---|---|
| 手表同步（BLE / WearEngine） | ✅ 下发 | ❌ 剥离 | 手表只显示动态码，无网络也无确认/撤销 UI |
| 云备份（华为云盘） | ✅ 保留 | ❌ 剥离 | 恢复后需重新登录一次才能用交易确认/撤销 |
| 换机克隆 | ✅ | ✅ | 走 ASSET 的 `SYNC_TYPE.TRUSTED_DEVICE`，随硬件保护通道迁移 |
| 文件导出/导入（用户主动） | ✅ | ✅ | 与既有 TokenSecret 行为一致；可选密码加密，明文导出时界面有风险提示 |

## 5. 安全约定

- 密码只在内存中存在到发起登录为止，`SteamLoginFlow.doLogin()` 立即清空，组件销毁时再清一次，任何日志都不打印
- 错误提示只包含 EResult 文案，不含密钥内容
- 高权限凭证（`identity_secret` / `refresh_token` / `revocation_code`）只留在本机 ASSET，不下发手表、不进云备份载荷
- 相比参考实现修正的缺陷：
  - `pollTokens` 只调一次、忽略服务端 `interval`、不校验空 `refresh_token` → 改为按 interval 轮询并校验
  - `authenticator_time` 传浮点秒进 uint64 → 取整
  - 登录后无条件跳转导致 `allowed_confirmations` 为空时崩溃 → 显式判定
  - 迁移分支靠字符串比较错误消息 → 改用 `EResult 29`
  - `generateAccessToken` 缓存比较秒与毫秒且缺 `return` → 修正
  - 解析失败时把含密钥的 JSON 打进 toast → 不复现
  - JSON 反序列化后的 `SteamAuth` 是**裸对象**（无原型方法），右键菜单构建期调用 `auth.hasConfirmationCredentials()` 抛 `TypeError: undefined is not callable` → 应用被杀（扫码登录后长按 Steam 令牌复现）→ 能力判定改为字段自由函数 `steamAuthHasConfirmationCredentials()` / `steamAuthCanRevoke()`，`copyTokenConfig()` 统一用 `SteamAuth.fromPlain()` 还原原型，KV 读取路径全部归一化
- `cryptoFramework` 在 LocalUnit/Previewer 运行时 `doFinalSync()` 静默返回空数据，因此哈希/HMAC/RSA 全部改为纯 ArkTS 实现，保证 CI 门禁能真正验证密码学正确性

## 5.1 交互细节（UX）

- **编辑页与绑定状态合一**：`AddSteamTokenPage` 在 `steamAuth` 存在时不再显示「登录 Steam 迁移令牌」，而是展示 Steam 账户面板——
  - 账号名 / SteamID
  - 能力状态：`交易确认 / 扫码登录`、`撤销验证器` 各自显示「可用」或「需要重新登录」
  - 功能入口：`交易确认`（复用 `OPEN_STEAM_CONFIRMATIONS` 事件）、`Steam 扫码登录`、`撤销 Steam 验证器`（二次确认后删除本地令牌并退出编辑页）
  - 凭证不完整（maFile 导入或云备份恢复）时给出说明，并把「重新登录 Steam（更换密钥）」作为补救入口；重新登录会再次迁移验证器并更换密钥
  - 已绑定的令牌隐藏「从 maFile 文件导入」与标题栏扫码入口，避免密钥与 Steam 侧验证器不一致
- **「去 Steam 绑定手机号」的应用内网页**（`WebPage`）是全屏路由，与设置里的半模态网页共用同一组件但安全区处理不同：
  - 全屏路由（`fullScreen = true`，由 `AppShell` 传入）：`HdsNavigation` + MINI 标题栏 + `avoidLayoutSafeArea` 避让状态栏，`PageScaffold({ avoidBottom: true })` 避让底部导航条，网页内容从标题栏下方开始
  - 半模态内嵌（`AgreementSheet` / `FeedbackSheet`）：安全区由半模态容器负责，保持原 MODAL 标题栏，不叠加内边距（否则双重留白）
- 登录引导的进度与错误文案全部走字符串资源（base / en_US / zh_CN / zh_TW 四套），错误通过 `SteamFlowError` 携带 `Resource`，渲染期再取当前语言
- **扫码登录的结果反馈**（`steamApproveQrLogin()`）：每一种结局都有提示——
  - 取消扫码 → 不提示；扫码失败 → 「扫描失败」
  - 非 `https://s.team/q/...` 二维码 → 「不是有效的 Steam 登录二维码」
  - 读到二维码后先提示「正在确认登录…」，避免网络慢时用户以为没反应
  - 确认成功 → 「已批准登录。」；失败 → EResult / 网络错误文案（均停留 3 秒）
  - 系统扫码页返回瞬间窗口可能仍在恢复，提示前等待 350ms；`HdsSnackBar` 展示失败时自动退回系统 toast，保证提示不丢
- 迁移失败的「账号状态明细」只写 hilog，界面只给可操作建议（去绑定手机号）：
  `hdc shell hilog -T SteamLoginFlow`
- 交易确认页：加载超过 8 秒显示「网络较慢，仍在连接 Steam…」，失败后给出「重试」按钮，不再只显示一行红字
- 所有按钮在 `busy` 期间禁用，避免重复提交导致会话/验证码失效

## 6. 测试与黄金向量

单元测试（LocalUnit / CI 门禁）：

```
hvigorw test -p module=entry@default --no-daemon
```

| 测试文件 | 覆盖 |
|---|---|
| `SteamProto.test.ets` | 编解码器基础类型、边界、skip |
| `SteamMessages.test.ets` | 7 个请求消息**逐字节**对齐 protobufjs；6 个响应消息解码 |
| `SteamCrypto.test.ets` | base64/HMAC/SHA/动态码/RSA 与 node:crypto 对齐 |
| `SteamClient.test.ets` | 假传输层驱动轮询/迁移分支/令牌缓存/确认列表 |
| `SteamAuth.test.ets` | mafile 兼容、深拷贝、手表剥离、分片 |
| `SteamFlow.test.ets` | 响应 → SteamAuth/TokenConfig、分支判定 |
| `SteamActions.test.ets` | 菜单能力判定、错误文案、base32→base64 |

期望值由 `scripts/steam-golden-vectors.mjs` 生成（需要 `npm i --no-save protobufjs@7.4.0`），用法见文件头注释。

其余可离线执行的校验：

```sh
node --test scripts/token-batch.test.mjs      # 含「KV 写入剥离 Steam 凭证」断言（43 例）
node scripts/verify-steam-field-numbers.mjs   # 字段号三方交叉校验
node scripts/check-string-keys.mjs            # 字符串资源完整性
```

需要网络时（可选，会向 Steam 发一次假账号失败登录）：

```sh
node scripts/steam-live-probe.mjs             # 真实服务端验证 protobuf/RSA/表单编码
```

该探针加载真实生产源码、只替换网络层，实测结论：
- `GetPasswordRSAPublicKey` 返回 **2048 位**公钥（modulus 512 hex / 256 字节）
- `BeginAuthSessionViaCredentials` 返回 `EResult 5 (InvalidPassword)` → 请求编码被服务端接受
- 故意发送损坏 protobuf 返回 `EResult 0 (Invalid)` → 反向对照成立

真机层面（连接设备后）：

```sh
hvigorw assembleHap -p module=entry@ohosTest --no-daemon
hdc install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
hdc shell aa test -b <bundleName> -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 120000
```

注意：`TokenProgressDialogDeviceTest` 依赖 `@kit.TestKit` 的 `Driver`，只能在 DevEco 的 UI 测试模式下运行；用上面的 `aa test` 命令会报 `waitForComponent of null`，属预期。

## 7. 已知限制

- 无代理：直连 `api.steampowered.com` / `steamcommunity.com`，网络受限时只能提示失败
- 云备份载荷不含高权限凭证 → 恢复后需重新登录一次才能使用交易确认/撤销（动态码不受影响）
- 迁移会顶掉其他设备上的验证器（不可逆）
- 账号触发人机验证（`EResult 101`）时无法在应用内完成，需先在浏览器登录一次

## 7.1 与 Google Authenticator 共用同一份 protobuf codec

`ProtoReader` / `ProtoWriter` 已从 `entry/src/main/ets/steam/proto/` 上移到
`common/src/main/ets/utils/proto/`：Steam 服务层与 Google Authenticator 迁移导入
（`common/src/main/ets/utils/GoogleAuthMigration.ets`）共用同一份实现。
原 protobufjs 生成代码（`google_auth.js`）与 nanopb 原生库（`libotpcutils.so`）已删除，
HAP 体积 11.1 MB → 7.2 MB。迁移导入同时修正了 base64url 解码、`batch_*` 合并与枚举缺省。
详见 [CODE_CLEANUP.md](CODE_CLEANUP.md)。

## 8. 参考与归属
本实现的协议细节与字段号取自 Steam 官方 `.proto`，并参考了以下 MIT 项目：

- [iamhyc/Aigis](https://github.com/iamhyc/Aigis) — ArkTS 手写 protobuf 解码思路
- [Wei Guo / Authenticator](https://github.com/) — Steam 登录/迁移流程参考（仓库内 `.ai/Authenticator-main`，不参与构建）

## 9. 真机验收清单（需真实 Steam 账号）

自动化测试无法覆盖真实账号流程（涉及凭据与不可逆的验证器迁移），需人工执行：

| # | 步骤 | 预期 |
|---|---|---|
| A1 | 添加菜单 → Steam 令牌 → 「登录 Steam 迁移令牌」 | 出现账号/密码输入，密码框为密码态 |
| A2 | 输入账号密码 → 登录 | 按账号情况进入「验证码」或「等待其他设备确认」 |
| A3 | 完成两步验证 | 进入「添加验证器」页，显示账号名 |
| A4 | 点「添加 / 迁移」 | 新账号 → 进入激活码页；已绑定 → 进入迁移警告页 |
| A5 | 输入短信/邮件码完成 | 提示成功，返回列表并出现新令牌 |
| A6 | **与 Steam 官方 App 对比 5 位码** | 必须完全一致（时间步内） |
| B1 | 令牌右键 → Steam 扫码登录 → 扫网页登录二维码 | 先提示「正在确认登录…」，随后提示「已批准登录」，网页自动登录 |
| B2 | 扫码时取消 / 扫非 Steam 二维码 / 断网后扫码 | 分别给出取消（无提示）、二维码无效、网络或 EResult 失败提示 |
| C1 | 令牌右键 → 交易确认 | 列表显示待处理项；批准/拒绝后列表刷新 |
| C2 | 断网或走代理不稳定时打开交易确认 | 超过 8 秒出现「网络较慢」，失败后显示错误 +「重试」按钮 |
| G1 | 编辑已绑定的 Steam 令牌 | 显示 Steam 账户面板（账号名/SteamID/能力状态）与交易确认、扫码登录、撤销入口 |
| G2 | 面板内点「交易确认」「Steam 扫码登录」「撤销 Steam 验证器」 | 与令牌右键菜单行为一致 |
| G3 | 面板内点「重新登录 Steam（更换密钥）」 | 账号名已预填，完成迁移后密钥更新并保存 |
| G4 | 登录流程中点「去 Steam 绑定手机号」 | 网页全屏打开，标题栏与底部导航条均不遮挡网页内容，可正常滚动 |
| D1 | 令牌右键 → 撤销 Steam 验证器 → 确认 | 提示已撤销，本地令牌被删除 |
| E1 | 手表同步后查看该令牌 | 手表显示同一 5 位码 |
| F1 | 编辑令牌后保存、删除令牌 | 本地数据正常，无残留 ASSET 条目 |

排错线索：

- 失败提示来自 `SteamError.eresultMessage()`，可直接对照 EResult 数值
- `hilog` 关键字：`SteamActions`、`SteamConfirmationsPage`、`SteamLoginFlow`、`TokenStore`
- 网络不通表现为连接失败（无代理，直连 `api.steampowered.com`）

