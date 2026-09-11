# 测试用例与代码覆盖率计划

> 创建日期：2026-09-11
> 基准来源：DevEco Studio「Local Test with Coverage」官方覆盖率报告（`hvigorw test` 亦会重新生成）
> 基准报告：`entry/.test/default/outputs/test/reports/index.html`（coverageReport.json）
> Instrument Test 覆盖率当前 IDE 不可用，本计划仅以 LocalUnit 覆盖率为量化基准；真机部分用 ohosTest 用例数/冒烟清单管理。

---

## 1. 覆盖率基准

### 当前基线（2026-09-11，Phase 1 快速赢面落地后）

| 指标 | Phase 1 前（2026-09-11 晨） | **Phase 1 后（当前）** |
|---|---|---|
| 全局行覆盖 | 27.11%（1772 / 6537） | **34.61%（2271 / 6561）** |
| 全局分支覆盖 | 25.13%（349 / 1389） | **30.29%（422 / 1393）** |
| **逻辑层行覆盖（可测基数口径）** | ≈27% | **50.92%（2195 / 4311）** |
| **逻辑层分支覆盖（可测基数口径）** | ≈25% | **43.37%（396 / 913）** |

- 逻辑层口径冻结在 `scripts/check-coverage.mjs`（46 个文件：common 全部 + entry 的 crypto/steam/oath/utils，剔除真机 only 与 UI 胶水），数字随 `scripts/coverage-baseline.json` 入库，CI 禁止回退。
- 测试规模：252 条 LocalUnit 用例（Phase 1 前 ≈200 条）。

### Phase 1 前分目录（历史存档，行覆盖 = covered/total 插桩行）

| 区域 | Phase 1 前 | Phase 1 后 |
|---|---|---|
| entry/ets/crypto（PureHash） | 93.7%（224/239） | 不变（已饱和） |
| common/ets/utils/proto | 89.8%（141/157） | 不变 |
| entry/ets/steam + proto | 72.5% / 83.5% | SteamClient **97.4%（223/229）** |
| common/ets/utils/importers | 38.9%（35/90） | TokenImporter 17/18；TwoFA 语义已有 Node 套件 |
| common/ets/utils（39 文件） | 15.1%（639/4225） | 大幅提升：TokenGroupStore 55/59、AppPreference 128/163、CloudBackupCrypto 98/161、Base64Util 19/22、SnackBar 8/22、TokenBatchProgress 8/9、CommonUtils 6/7 |
| entry/ets/utils | 4.3%（8/188） | ResponsiveLayoutPolicy 9/11（common 侧） |
| CloudBackupCrypto / TokenGroupStore / AppPreference | **均 0%** | **全部脱离 0%** |
| entry pages/dialogs/components/shell/widget、entryability 系 | 无数据 | 无数据（归 UI 口径） |
| uikit、wearable 模块 | 无数据 | 无数据（纯 UI） |

### 口径说明（重要）

- 报告共 65 个文件条目；entry 的 pages(29)/dialogs(7)/components(20)/oath(4)/shell(3) **完全不在报告中（无数据 ≠ 0%）**，uikit/wearable 亦无条目。这些文件未来若进入插桩基数，全局百分比会被稀释。
- 因此**所有目标按「逻辑层可测基数」定义，不以全局插桩行定义**；全局数字仅作防基数漂移的参考，与 `coverage-baseline.json` 的 `globalReference` 一致。

### LocalUnit 运行时限制（2026-09-11 实测新增）

- `util.Base64Helper`（@ohos.util）：**静默返回空数据**（encodeToStringSync 返回 ''、decodeSync 返回空数组，不抛异常）。CloudBackupCrypto 已加 `Base64Codec` 注入；Base64Util 的用例固化了该行为，若 LocalUnit 未来支持会主动失败提醒迁移。
- `systemDateTime.getTime()` 与 `Date.now()`：被 stub、不与真实时钟对齐——时间差/耗时段言不可写，只能断言返回有限数值。
- 其余已知限制见 AGENTS.md 第 10 节（cryptoFramework、generateRandomUUID、TextDecoder 等）。

---

## 2. 代码分类结论（三分法）

- **A 类（纯逻辑，LocalUnit 现在就能测）**：common 的 proto/importers/TokenUtils 纯函数部分、TokenConfig、GoogleAuthMigration、OtpAuthParser、SteamAuth、entry 的 crypto/steam（除 NetworkHttpTransport）、ResponsiveLayoutPolicy（改签名后）等。项目已有成熟注入先例：PureHash、HttpTransport、Sleeper、TagTransport、setSnackBarImpl。
- **B 类（业务逻辑但耦合系统 API，需解耦后可测）**：TokenStore（KvManager/RdbManager/Asset/SteamSecretStore）、CloudBackupCrypto（cryptoFramework）、CryptoUtils、AppPreference（preferences）、KvManager（distributedKVStore）、BleTokenTransfer（ble）、WearEngineTransfer（wearEngine）、CloudBackupManager（fileIo/cloudSync）、各 SecretStore（asset）等。
- **C 类（UI，LocalUnit 永远测不了）**：entry pages/dialogs/components/shell/widget/pages、uikit 全部（1167 行 @Component）、wearable 全部（955 行）。

### 真机 only（从可测基数剔除，归 ohosTest 责任区）

PermissionManager、DlpAntiPeepManager、PhotoPickerUtils、IconThumbnailTask、RdbManager、HuaweiAccountManager 登录流程、BleTokenTransfer 的 GATT/scan 部分（~280/403 行）、WearEngineTransfer 的 P2P/权限部分（~180/262 行）、KvManager 的 distributedKVStore 调用、AssetSecretStore 的 asset 调用、NfcOathReader/NfcTagTransport、NetworkHttpTransport、TokenSwitchPerf、EntryAbility 系。
估算剔除后**逻辑层可测基数 ≈ 4,900~5,000 插桩行**。

---

## 3. 高风险清单（数据丢失/密钥安全，必须优先脱离 0%）

| 文件 | 风险 | 现状 |
|---|---|---|
| TokenStore | 令牌主存储，KV+ASSET 双写、迁移三重验证、900 字节降级——出错即用户全部令牌丢失 | 0% |
| CloudBackupCrypto | 云备份加密格式，加密有 bug 即备份不可恢复 | 0% |
| CloudBackupManager / CloudSyncTask | 备份/恢复编排与记录解析 | 0% / 无数据 |
| AssetSecretStore / SteamSecretStore | TEE 密钥读写与分片，丢失不可再生 | 均 0% |
| CryptoUtils | 本地备份 + BLE 传输加密 | 0% |
| TokenBackup | 本地文件备份管线（magic/version/加密） | 0% |
| BackupRestoreHelper + BackupExtension | 换机迁移明文 KV 中转窗口 | 0% |
| KvManager | 持久化底层 + 旧版本数据迁移 | 0% |
| TokenGroupStore | merge/reconcile 可能破坏用户分组 | 1.8% |

以上合计约 1,400 插桩行，其中约 60% 可经接口抽取后在 LocalUnit 覆盖；其余由 ohosTest 真机回归覆盖（现有 AssetConcurrency/TokenBatch 雏形需扩展为备份/恢复/迁移套件）。

---

## 4. 阶段计划

### 逻辑层（common 全部 + entry 的 crypto/steam/oath/utils）

| 阶段 | 目标（对可测基数） | 出口条件 | 工作量 |
|---|---|---|---|
| **Phase 0 口径修正** | 固定基数 | 本文件剔除清单评审通过；无数据文件明确归入 UI 口径 | ✅ 完成 |
| **Phase 1 快速赢面** | 行 27%→**40~45%**；分支 25%→**33~35%** | ✅ **完成（2026-09-11）**：行 **50.92%**、分支 **43.37%** 双双超额；清单 1~10、12 落地（11 号 OathApplet 移交 Phase 2 头）；CloudBackupCrypto/TokenGroupStore/AppPreference 脱离 0%；CI 门禁 `check-coverage.mjs` + `coverage-baseline.json` 已入 quality.yml。A 类纯函数路径全覆盖（TokenUtils 文件级 37.6% 因其余为真机 API 胶水，归 B/C 口径） | 实际 1 天 |
| **Phase 2 存储与密钥解耦** | 行→**55~60%**；分支→**45%** | 建立四个接口：`KeyValueStore`、`SecretStore`、`CryptoEngine`、`FsGateway`；TokenStore 迁移决策（三重验证/降级/双写）穷举用例；高风险清单全部脱离 0%。候选入手点（当前 0% 的最大块）：CloudBackupManager(330)、IconPackCloudBackup(368)、CryptoUtils(159)、TokenStore(256)、FileUtils(77)、TokenCardStore(77)、BackupRestoreHelper(19)、OathApplet 协议层 | 3~6 周 |
| **Phase 3 备份与传输协议** | 行→**70~75%**；分支→**55~60%**（逻辑层基本到顶） | CloudBackupManager/CloudSyncTask/TokenBackup/IconPackCloudBackup 打包解析与状态机全测；BleFrameCodec/WearEngine 消息编解码纯类分支 ≥70%；ohosTest 补齐备份 round-trip、换机迁移、BLE/WearEngine 冒烟各 ≥3 条 | 4~8 周 |

**天花板**：75%/60%（行/分支）之后剩余基本是 API 调用胶水（await kvStore.put、asset.add、ble.write…），LocalUnit 永远测不了，强行 mock 只会产生"测 mock"的假覆盖。折算到当前全量 6,537 行口径约为 55~58% 行。

### 快速赢面清单（Phase 1，按行数×风险排序；✅ = 已落地 2026-09-11）

1. ✅ CloudBackupCrypto（0%→61% 行，加密引擎经 `BackupCryptoEngine`/`Base64Codec` 注入）：getMode/isMockFormat/parseTokenHeader/verifyToken/错误分支/三段式 round-trip 全测（XOR 假引擎 + PureHash 真 SHA-256）；AES/PBKDF2 数值归真机
2. ✅ TokenUtils.OTPDefaultIconPack：查表映射 + 数据完整性（无重复/小写归一/路径集合一致）
3. ✅ TokenUtils 其余纯函数（convertToken2URI、stringToIntArray、counterToBytes64 大数值边界；base32 变体此前已覆盖）
4. ✅ TokenGroupStore 纯逻辑（isValidName/rename/remove/move/merge/reconcile/写失败回退；`useKvBackendForTest` 注入内存 KV）
5. ✅ AppPreference 纯部分（默认值缓存/枚举稳定值/选项数组一致性/PREF_KEYS 无冲突/路由与外链常量/loadSettings 默认值流入 TokenPreference）
6. ✅ SteamClient 58%→**97.4%**（RSA 解析、BeginAuth float interval、newClientId 迁移、迁移/撤销/状态全链路、请求体 protobuf 回读）
7. ✅ TokenImporterRegistry 分发 + URIImporter 空实现契约（init 幂等/同 id 覆盖）
8. ✅ SnackBar 注入点（注入记录函数验证分发与默认参数）
9. ✅ Base64Util（**实测结论：util.Base64Helper 在 LocalUnit 静默返回空**——用例固化该行为并注释迁移路径；纯 TS base64 语义由 SteamCrypto 套件覆盖）
10. ✅ UiUtils.throttle 窗口、TokenBatchProgress 观察者协议（含观察者抛异常不回滚）、CommonUtils（delay resolve、nowUnixSeconds 契约、padZero）
11. ⬜ oath/OathApplet 协议层（519 行 TLV/指令构造；cryptoFramework 换 PureHash 注入后全测）— Phase 1 末或 Phase 2 头
12. ✅ ResponsiveLayoutPolicy（新增 `resolveVp(widthVp, heightVp)` 纯数值入口，`resolve` 委托换算；断点/宽高比边界全测）

### UI 层（pages/dialogs/components/shell/widget/uikit/wearable，约 1.76 万行）

| 阶段 | 策略 |
|---|---|
| Phase 1~2 | **不上 UI 自动化**。只做两件事：(a) UI 文件里零星纯函数（TokenListPage.toVMs、颜色换算、describeError 等 <300 行）顺手抽走归入逻辑层；(b) 真机手工冒烟清单文档化（加令牌/编辑/删除/备份恢复/卡片刷新 5 条主路径） |
| Phase 3（可选） | ArkUITest 黑盒冒烟 10~20 条关键路径（列表渲染/搜索/排序/添加三类型/应用锁），**不做 UI 覆盖率门禁**；若需要数字，行覆盖 15~25% 仅为参考值 |
| widget | CardOTPUtils 已 100%，FormExtension 生命周期留真机；不设目标 |
| wearable | 不设 LocalUnit 目标，列入真机 ohosTest/手工冒烟清单 |

UI 层度量方式：关键路径 ohosTest/ArkUITest 用例通过率 + 手工冒烟清单勾选，**不用行覆盖率**（信噪比低，深挖性价比远低于逻辑层分支覆盖）。

---

## 5. 度量与复现

```powershell
# 重新生成基准（二选一）：
# 1) DevEco Studio：右键 entry/src/test → Run 'Tests in 'test'' with Coverage
# 2) CLI（无需特殊参数，test 任务默认重写覆盖率报告）：
./hvigorw test -p module=entry@default --no-daemon
# 报告输出：entry/.test/default/outputs/test/reports/index.html + coverageReport.json

# 逻辑层覆盖率门禁（CI quality.yml localunit job 亦执行）：
node scripts/check-coverage.mjs
# 口径冻结于脚本内 INCLUDES/EXCLUDES；数字对比 scripts/coverage-baseline.json，
# 有意提升覆盖率后重新生成 baseline 随代码提交（只进不退）。
```

- CI 门禁：quality.yml 解析 test_result.txt 的现有逻辑不变，其后追加 `node scripts/check-coverage.mjs`——逻辑层行/分支覆盖低于基线（0.1pp 容差）即失败。
- 每阶段合入后更新本文件第 1 节的基准数字与日期。

### 门禁盲区登记（2026-09-11 红方评审后加固）

- **分母逃逸**：coverageReport.json 只含测试导入图可达的文件，未加载的口径内文件对覆盖率完全不可见。`check-coverage.mjs` 现将磁盘口径文件与报告路径求差集，豁免清单冻结于 `coverage-baseline.json` 的 `expectedAbsentFromReport`（当前 9 个，只允许缩小）：common 的 AppWindowInfo/AppFonts/CloudSyncTask/CommonConstants，entry 的 oath/NfcSessionTokens、oath/OathApplet、oath/TagTransport、utils/BackupImportOperation、utils/TokenBatchOperation。给文件补导入触达用例后应移除对应条目；OathApplet 随快速赢面 11 号（Phase 2 头）自然消除。
- **baseline 防篡改**：baseline 含 `fileCount`（磁盘口径文件数），门禁对「删文件缩分母」「报告缺文件」双重拦截；覆盖率提升后重新生成 baseline 并随代码提交（同一提交内下调 baseline 属违反流程，review 时应拒绝）。
- **未守护目录**（三分法有意排除，写入即不受门禁约束）：entry 的 pages/dialogs/components/shell/widget、entryability/entryformability 系、uikit/wearable 模块。gate 每次运行都会打印此提示。

---

## 6. 结论摘要

1. 合理终点：**逻辑层（可测基数 ≈5,000 行）三阶段 40% → 60% → 75% 行覆盖，分支 33% → 45% → 60%**；全局口径终态约 55%。UI 层不设行覆盖目标。
2. 分 Phase 0 + 3 个实施阶段；UI 前两阶段零投入，Phase 3 可选黑盒冒烟。
3. 最高优先级是高风险清单（TokenStore/CloudBackupCrypto/各 SecretStore/备份恢复路径）；Phase 3 前，真机备份 round-trip 用例必须存在。
4. 解耦成本低：PureHash、HttpTransport、Sleeper、TagTransport、setSnackBarImpl 五个先例证明 B 类解耦是沿用既有模式；BLE/WearEngine/NFC/cloudSync/asset 真机部分明确剔除，交给 ohosTest。
