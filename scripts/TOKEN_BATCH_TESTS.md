# 批量令牌操作回归

## 行为约定

- URI / 备份导入统一调用 `TokenStore.updateTokens()`；以 UUID 合并，已有令牌保留本地收藏与排序，同批重复 UUID 最后的内容生效。
- `setTokensFavorite()` 跳过已处于目标状态的条目，不访问 ASSET。
- `deleteTokens()` 一次计算幸存令牌的排序变化；只删除末尾或全选清空时无需重写排序。
- KV 写入/删除在一个事务中执行，每次 `putBatch` / `deleteBatch` 最多 128 条。任意分块失败则回滚整个 KV 事务；未提交的配置不发布到内存。
- 批量操作只发一次 `TOKEN_CHANGED`；空操作不发事件。单条编辑仍使用精准刷新。
- 普通令牌修改、批量修改和重新加载排队，KV 普通写入也排队，避免混入其他事务。
- ASSET 不属于 KV 事务。只有 KV 提交后才同步必要的密钥变更；ASSET 不可用时保留完整加密 KV 副本。没有引入 TaskPool 或降低 PBKDF2 迭代次数。

## 主机回归

要求支持 `node:module.stripTypeScriptTypes` 的 Node.js（当前验证环境 Node 26）。

```sh
node --test scripts/*.test.mjs
```

`token-batch.test.mjs` 加载实际生产 ArkTS，通过内存 SDK mock 验证：

- 1/127/128/129/257 条分块；1000 条全选删除零排序写入。
- URI 非法行与重复 URI、备份覆盖与收藏保留、重复 UUID、空操作。
- 收藏跳过不变项、稀疏删除、历史排序间隙。
- 事务开始/写入/删除/提交失败、后续分块失败、回滚与队列恢复。
- 提交前内存不变，排队导入/收藏/删除/重载不会丢失更新。
- 普通 KV 写入不被批量事务回滚；密钥不变跳过 ASSET、变更/清空/超限与降级。
- 批量列表刷新仅替换内容变更行的 key，NFC 会话删除合并通知。

这些 mock 测试不代替真实 KV / ASSET 测试。

## 真机 Hypium

测试源：`entry/src/ohosTest/ets/test/TokenBatch.test.ets`。

测试使用真实加密 KV、ASSET、备份文件解析与加解密。每条用例只创建随机 UUID 的测试令牌，结束后仅清理这些 UUID 和测试文件，检查原有令牌配置与顺序没有变化。失败断言不输出原有配置或密钥。请勿同时在手机上手动编辑令牌。

```sh
# 正常构建部署，不要使用 --uninstall（会影响已有数据）
devecocli run --module entry --device <serial>
# 构建测试 feature HAP
devecocli build --modules entry@ohosTest
```

DevEco CLI 当前没有测试执行子命令，因此以下使用同一 SDK 的 hdc：

```sh
hdc -t <serial> install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
hdc -t <serial> shell aa test -b smartcityshenzhen.yylx.totptoken -m entry_test \
  -s unittest OpenHarmonyTestRunner -s class TokenBatchDeviceTest -s timeout 180000
```

实际 HAP 路径以构建输出为准。Windows Git Bash 下设备绝对路径可能需要 `MSYS_NO_PATHCONV=1`。

真实 SDK 回滚用例在第二个分块放入超长 key，要求第一个分块也全部回滚。性能用例打印 `TokenBatchPerf`（仅数量与耗时，不含密钥），不以固定毫秒阈值作为断言。

另有当前/旧格式备份兼容、错误密码、连续排队操作、重载持久化和 ASSET 清理等集成验证。

判定通过必须检查 Hypium 用例数、通过/失败汇总，不能仅根据 hdc 或构建进程退出码判断。测试结束后重新启动正常 EntryAbility；不卸载整个应用。

## 第一阶段验证记录（2026-09-06）

- 主机脚本：53/53 通过。
- LocalUnit：85/85 通过，结果文件 `entry/.test/default/intermediates/test/coverage_data/test_result.txt`。时间格式用例使用固定 UTC 时间戳和本地字段作期望值，规避 Windows Previewer 的 Date 构造器/夏令时不一致；生产时间逻辑未改。
- Mate 80 Pro Max 真机 Hypium：9/9 通过（Failure=0、Error=0）。
- 已完成正常 HAP 部署；URI 页面验证 3 条有效 URI + 1 条非法行，只新增 3 条。
- 用户完成页面批量收藏/取消收藏、备份及删除操作。手动日志中 ASSET 无失败。
- 真机 257 条：导入 5979ms、收藏 163ms、取消收藏及重载合计 182ms、删除 4988ms。
- 用户 100 条场景：ASSET 写入日志首尾跨度 2227–2435ms；100/103 条删除分别 1444/1580ms。它们不是完整按钮响应时间，说明剩余主要开销仍是逐条 ASSET 操作，第一阶段未将其并发化。
