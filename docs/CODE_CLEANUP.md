# 工程代码优化记录（P0 修复 → Google Auth 迁移 → 重复函数合并）

本文记录一次系统性工程优化的**改动、依据与验证方式**。三阶段按用户确认的顺序执行，
每阶段都跑 `hvigorw test`（ArkTS 单测）+ `npm run check`（node 离线回归）+ 全模块构建 + 真机安装。

## 0. 起点审计结论

| 问题 | 审计结论 |
|---|---|
| C++/nanopb 是否无用 | **不是无用，是只剩兜底**：`libotpcutils.so` 仅在 protobufjs 解码失败/为空时被调用（`GoogleAuthUtils.ets:118/:141`）；`entry/src/main/cpp` 共 730 文件 / 9.38 MB，其中 nanopb 子模块 721 文件，CMake 只编译 4 个 `.c` |
| Google Auth 能否复用手写 ArkTS protobuf codec | **能**：`ProtoReader/ProtoWriter` 是通用 wire-format 编解码器，GA schema 只用 varint + length-delimited，`repeated OtpParameters` 不是 packed |
| 可复用/可合并函数 | 27 组重复、约 47 个可合并函数、约 640 行、涉及 36 个文件（详见 §3） |

## 1. P0：正确性问题修复

| # | 问题 | 修复 | 测试 |
|---|---|---|---|
| P0-1 | 卡片 `generateCardOTP()` 的 SHA256 分支与默认分支相同，**SHA256/SHA512 令牌在桌面卡片显示错误验证码** | 卡片哈希实现补齐 SHA-1/224/256/384/512（HMAC 通用化）；MD5/SM3 需要 cryptoFramework，改为返回等长占位符 `-`，不再返回看似正常的错码 | `CardOTPUtils.test.ets`：RFC 6238 附录 B 向量（SHA256 T=59 → 46119246、SHA512 → 90693936）+ SHA224/384 由 node:crypto 交叉算出 |
| P0-2 | base32 解码容错不一致：卡片静默跳过非法字符，主界面抛错 → `generateOTP` 返回 0 → 显示 `000000` | `TokenUtils.base32Decode` 与卡片一致：容忍空格/连字符/换行并跳过非法字符（先过滤再按长度分配输出） | `Base32.test.ets`：`MZ XW6===` / `MZX-W6===` / `MZ!XW6===` 均得同一结果 |
| P0-3 | 云备份 salt/iv 用 `Math.random()` 生成（可预测，AES-CBC 可被离线攻击） | 改用 `CryptoUtils.randomBytes()`（`cryptoFramework.createRandom()` CSPRNG），并导出该函数 | 既有云备份回归 `token-batch.test.mjs` |
| P0-4 | 时间基准两套：卡片 `Date.now()` vs 手机/手表 `systemDateTime` | 新增 `CommonUtils.nowUnixSeconds()`，手机/手表 7 处内联全部改用它（卡片进程不能 import common，保留 `Date.now()` 并注释说明） | 既有用例 + 构建 |
| P0-5 | 大端计数器编码 4 份且溢出行为不同（卡片 `setUint32` 截断、主界面有符号右移） | 统一为 8 字节大端 BigInt 实现：`TokenUtils.counterToBytes64()`（common）与卡片内等价实现 | `Base32.test.ets`：`counterToBytes64(4294967297)` / `(2^31)` / `(2^53-1)`；`CardOTPUtils.test.ets`：counter=2^32+1 结果与 counter=1 不同 |

## 2. Google Auth 迁移改用手写 ArkTS codec，并删除 C++/protobufjs

### 2.1 实现

- **codec 上移**：`ProtoReader.ets` / `ProtoWriter.ets` 从 `entry/src/main/ets/steam/proto/` 移到
  `common/src/main/ets/utils/proto/`（Steam 与 Google Auth 共用一份，9 处 import 同步更新）。
- **新增** `common/src/main/ets/utils/GoogleAuthMigration.ets`：
  - `parseMigrationPayload()`：按 `google_auth.proto` 的字段号解码（1 repeated message / 2-5 int32）
  - `decodeBase64Url()`：GA 的 `data=` 是 **base64url**（`-_`、无 padding），旧实现按标准 base64 解码会失败
  - 批次合并：`batch_size/batch_index/batch_id` 真正合并（先收齐再落库，按 index 排序），旧实现直接丢令牌
  - 枚举缺省：UNSPECIFIED/未知值回退 SHA1 / 6 位 / TOTP（避免 `digits=0` 算出 1 位码）
  - Steam 条目自动映射为 `otpType.Steam`（5 位字母码）
- **入口改造**：`Index.start_quick_scan()` 直接调用 `decodeGoogleAuthMigration()`，并提示批次进度；
  取消扫码时 `resetGoogleAuthBatch()` 丢弃未收齐的批次。
- **删除**：`entry/src/main/ets/utils/GoogleAuthUtils.ets`、`google_auth.js`(41 KB)、`google_auth.d.ts`(11.7 KB)、
  `entry/src/main/cpp/`（含 nanopb 子模块，9.38 MB / 730 文件）、`entry/build-profile.json5` 的 `externalNativeOptions`、
  ohpm 依赖 `libotpcutils.so` 与 `long`、根 `oh-package.json5` 的 `@ohos/protobufjs`、`.gitmodules`。

### 2.2 效果

| 指标 | 之前 | 之后 |
|---|---|---|
| HAP 体积 | 11,096,709 B | **7,183,725 B（−3.9 MB / −35%）** |
| HAP 内 `.so` | `libotpcutils.so`（arm64 + x86_64） | **无** |
| Google Auth 解码实现 | protobufjs 生成代码 + nanopb 原生兜底 | **纯 ArkTS，一份 codec** |
| 单测覆盖 | ohosTest 里是空壳 | `GoogleAuthMigration.test.ets`（7 例）+ 真机 2 例 |

## 3. P1：重复函数合并

| 合并项 | 之前 | 之后 |
|---|---|---|
| 纯 ArkTS 哈希/HMAC | `steam/PureHash.ets`（SHA1/256）+ `widget/utils/CardOTPUtils.ets`（自带 SHA1/HMAC） | `entry/src/main/ets/crypto/PureHash.ets` 单份，覆盖 SHA-1/224/256/384/512 + 通用 HMAC；Steam 与卡片共同引用（卡片不依赖 common HAR） |
| `padZero` | CommonUtils / SyncTimeHelper / CloudBackupManager 三份 | 统一 `CommonUtils.padZero` |
| `formatTimestamp` | SyncTimeHelper / CloudBackupManager / CloudSyncTask 三处 | CloudBackupManager 改用 `SyncTimeHelper.formatTimestamp`；CloudSyncTask 因 `@Concurrent` 仅复用 `padZero` |
| 资源→文案 `textOf` | SteamLoginFlow / SteamConfirmationsPage 两份 | 统一 `UiUtils.resourceText(uiContext, res)` |
| `delay` | SteamLoginFlow / SteamActions / SteamClient 三处 | 统一 `CommonUtils.delay(ms)`（`RealSleeper` 作为可注入接口保留） |
| `emptyCardData` | TokenCardStore / EntryFormAbility 两份 | 统一 `TokenCardStore.emptyCardData()` |
| 死代码 | `SteamUtils.SteamAPI`（空回调类）、`SteamUtils.LoginWithQR`（空函数）、`TokenUtils.stringToArray`（无生产调用） | 删除，约 40 行 |

**有意保留的"重复"**（审计结论，勿盲目合并）：

- `common/SnackBar.ets` 与 `entry/HdsSnackBarUtils.ets`：端口注入设计，手表无 HDS 系统 HSP；
- `common/MaterialStyleBridge.ets` 与 `entry/MaterialTheme.ets`：`common` 不引用 API 26 材质符号；
- 纯 ArkTS 哈希与 `cryptoFramework` 两条路径：Previewer/LocalUnit 下 `doFinalSync()` 静默返回空；
- `SteamCrypto` 手写 base64/UTF-8：规避 Previewer 下 `util.Base64Helper`/`TextEncoder` 行为差异；
- 卡片进程零依赖：不得 import `common`（会连带加载 KvManager/RdbManager/AppStorage）。

## 4. 工具整合

`package.json` 新增统一入口（`scripts/README.md` 同步说明）：

```sh
npm run check          # 字符串资源 + Steam 字段号 + 全部 node 回归（离线）
npm test               # node --test "scripts/*.test.mjs"
npm run check:strings
npm run check:fields
npm run probe:steam    # 真实服务端编码探针（需网络）
npm run golden:steam   # 重新生成 Steam 黄金向量（需 protobufjs）
```

## 5. 验证记录

| 项 | 结果 |
|---|---|
| ArkTS 单测 `hvigorw test -p module=entry@default` | **181/181** |
| node 离线回归 `npm test` | **72/72** |
| 字符串资源 `npm run check:strings` | 四语言齐全（`steam_*` 74 条） |
| Steam 字段号 `npm run check:fields` | PASS，0 处不一致 |
| 全模块构建 `hvigorw assembleHap` | BUILD SUCCESSFUL（entry/common/uikit/wearable） |
| 真机 ohosTest `SteamSecretStoreDeviceTest` | **3/3 通过**（KV 剥离高权限凭证 / 旧 mafile 迁移 / 云备份 CSPRNG） |
| 真机 Google Auth 解析 `aa test ... -s class GoogleAuthUtilsTest` | **2/2 通过**（设备运行时下 ArkTS codec 正常） |
| 真机安装 | `test.yylx.totptoken` 安装成功 |

### 5.1 校验入口的可移植性

依赖参考工程（`.ai/`，不进仓库）的脚本在干净 clone 上会直接失败，因此：

- **参考快照固化进仓库**：`scripts/reference/steam-field-numbers.json`
  （官方 `.proto` + protobufjs 生成代码抽取出的「字段号/wireType」集合，
  用 `scripts/generate-steam-field-manifest.mjs` 生成，勿手改）；
- `scripts/verify-steam-field-numbers.mjs` **默认只读快照**，干净 clone 可运行；
  设置 `STEAM_PROTO_REF=<steamapi 目录>` 时额外校验快照是否与上游一致（防过期）；
  负向验证：把某字段号改错（13/2）脚本会 FAIL 并指出字段，证明校验非空转；
- **node 回归已接入 CI**：`.github/workflows/quality.yml` 新增 `Node offline checks`
  作业（字符串资源 / 字段号 / TokenStore-KvManager 套件，无需 SDK 与 npm 依赖）。

## 6. 仍待处理（未在本次范围内）

- **卡片 MD5/SM3 令牌显示占位符**：这两个算法需要 cryptoFramework，卡片进程不可用；如确有需求，
  可在 `entry/crypto/PureHash.ets` 补纯 ArkTS 实现后去掉占位符。
- **多批次二维码的 UI 引导**：解析层已支持合并与进度提示，但连续扫描仍由用户手动完成（无"还剩 N 张"的独立界面）。
- **`otpauth-migration://` 剪贴板/URI 导入**：`UriImportSheet` 目前只接受 `otpauth:` 前缀，粘贴迁移链接会被拒绝。
- **EResult 文案本地化**：`SteamError.eresultMessage()` 仍是中文硬编码（29 条，由非 UI 层调用）。
