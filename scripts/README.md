# 辅助脚本

## 统一入口（npm scripts）

```sh
npm run check          # 字符串资源 + Steam 字段号 + 全部 node 回归（离线，无需设备）
npm test               # 仅 node --test "scripts/*.test.mjs"
npm run check:strings  # 字符串资源完整性
npm run check:fields   # Steam 字段号三方交叉校验
npm run probe:steam    # 真实服务端编码探针（需网络）
npm run golden:steam   # 重新生成 Steam 黄金向量（需 protobufjs）
```

ArkTS 侧单测/门禁仍走 DevEco：

```sh
hvigorw test -p module=entry@default --no-daemon
```

## 批量令牌操作回归

运行 `node --test scripts/*.test.mjs`（或 `npm test`）。覆盖生产 TokenStore/KvManager 的分块、事务回滚、事件次数及并发顺序。
真机 Hypium 构建、执行与数据保护约定见 [TOKEN_BATCH_TESTS.md](TOKEN_BATCH_TESTS.md)。

## 材质策略回归测试

需要 Node.js ≥ 22.13.0（使用 `node:module` 的 `stripTypeScriptTypes` API）。在仓库根目录运行：

```sh
node --test scripts/material-theme.test.mjs
```

脚本加载生产 `MaterialTheme.ets`，通过 SDK mock 验证材质偏好、低 API 防护及 HDS 等级策略委托。偏好 fixture 应与 `common/src/main/ets/utils/AppPreference.ets` 的 `MaterialPreference` 默认值同步。

该脚本尚未接入 CI/钩子，不替代 Hypium LocalUnit / Quality CI，也不验证设备渲染效果。真机或模拟器上的材质开关、五档厚度、交互光感、菜单/弹窗背板与低版本降级仍需单独验证并补充截图。

## Steam 黄金向量生成

```sh
npm i --no-save protobufjs@7.4.0
node scripts/steam-golden-vectors.mjs
```

用独立实现（protobufjs + node:crypto）产出 Steam 消息字节、HMAC 签名、Steam 动态码与 RSA 密文的期望值，用于交叉验证 `entry/src/main/ets/steam/` 下的 ArkTS 手写实现。输出需要手工同步到 `entry/src/test/SteamMessages.test.ets`、`SteamCrypto.test.ets`、`SteamClient.test.ets` 的常量中；RSA 每次运行都会重新生成密钥对，必须成对更新。

实现结构与协议说明见 [docs/STEAM_AUTHENTICATOR.md](../docs/STEAM_AUTHENTICATOR.md)。

## Steam 字段号交叉校验

```sh
node scripts/verify-steam-field-numbers.mjs
```

只读脚本，比对三方：官方 `.proto`（权威）、参考工程生成的 protobufjs 代码（独立第二来源）、以及本仓库 `entry/src/main/ets/steam/proto/SteamMessages.ets` 手写实现（被校验对象）。比较「字段号 + wireType」集合，任一不一致即退出码 1。无需安装任何依赖。

## 字符串资源完整性校验

```sh
node scripts/check-string-keys.mjs
```

扫描全部 `$r('app.string.KEY')` 引用，检查 base 是否齐全（缺失即失败，退出码 1），并报告各语言缺失情况（缺失会回退到 base）。同时打印 `steam_*` 键在四种语言中的覆盖情况。

## Steam 实时探针（需网络）

```sh
node scripts/steam-live-probe.mjs
```

加载真实生产 ArkTS 源码（仅替换网络层），用不存在的假账号向 Steam 发一次失败登录，验证手写 protobuf 编码 + RSA 加密 + 表单编码能被真实服务端接受，并用「损坏载荷」做反向对照。需要 Node ≥ 22.13.0 且能访问 `api.steampowered.com`；请勿高频运行。




