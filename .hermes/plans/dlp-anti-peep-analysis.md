# 防窥保护（DlpAntiPeep）集成方案分析

> 分支：`feature/dlp-anti-peep` | 分析日期：2026-05-02 | 状态：仅分析，未修改代码

---

## 1. 项目兼容性评估

| 维度 | 要求 | 现状 | 结果 |
|------|------|------|------|
| SDK 版本 | ≥ 6.0.0(20) | `compatibleSdkVersion: 6.1.0(23)` | ✅ 满足 |
| 设备类型 | PHONE | `deviceTypes: [phone, tablet, 2in1, wearable]` | ✅ 包含 phone |
| 权限声明 | `ohos.permission.DLP_GET_HIDE_STATUS` | 未声明 | ❌ 需添加 |
| AGC ACL 申请 | 受限权限需在 AGC 申请 | 未知 | ❌ 需确认/申请 |

**结论**：SDK 版本完全满足（6.1.0 已支持所有 API，包括 6.1.0 新增的 `requestAntiPeepOptions` 和 `publishAntiPeepInformation`）。核心差距在于权限配置。

---

## 2. 现有安全机制盘点

ohtotptoken 已有多层安全保护：

| 机制 | 文件 | 实现方式 |
|------|------|----------|
| 窗口隐私模式 | `EntryAbility.applySettings()` + `SecuritySheet` | `windowClass.setWindowPrivacyMode(true)` |
| 应用锁 | `EntryAbility.onCreate/onBackground` + `AppLockOverlay` | 前后台切换触发，生物认证解锁 |
| 隐藏令牌 | `SecuritySheet` + `TokenPreference.app_safety_hide_token_enable` | 开关控制，TokenItem 响应式隐藏数字 |
| 后台模糊 | `SecuritySheet` + `AppLockOverlay` | `foregroundBlurStyle` 模糊遮盖 |
| 锁屏数据保护 | `module.json5` | `ohos.permission.PROTECT_SCREEN_LOCK_DATA` |

**防窥保护的定位**：与现有机制协同但不重叠。现有安全机制处理的是「应用切换/锁屏」场景，防窥保护处理的是「使用中被人从侧面偷看」场景。

---

## 3. 三层实现方案

### 第 1 层：基础设施（必须）

改动文件：**4 个**

#### 1.1 module.json5 — 添加 ACL 权限

在 `requestPermissions` 数组末尾添加：

```json5
{
  "name": "ohos.permission.DLP_GET_HIDE_STATUS",
  "reason": "$string:dlp_anti_peep_reason",
  "usedScene": {
    "abilities": ["EntryAbility"],
    "when": "inuse"
  }
}
```

**前置条件**：需先在 AppGallery Connect 申请该 ACL 权限。

#### 1.2 resources/string.json — 添加权限说明文案

```json
{
  "name": "dlp_anti_peep_reason",
  "value": "用于检测他人窥视屏幕以保护您的令牌隐私"
}
```

#### 1.3 AppPreference.ets — 添加偏好键和默认值

在 `PREF_KEYS` 枚举中添加：

```typescript
/** 防窥保护开关 */
SAFETY_DLP_ANTI_PEEP_ENABLE = 'app_safety_dlp_anti_peep_enable',
```

在 `AppPreference.settings_default` 中添加默认值：

```typescript
[PREF_KEYS.SAFETY_DLP_ANTI_PEEP_ENABLE, false],
```

在 `TokenPreference` 类中添加 `@Trace` 属性：

```typescript
@Trace app_safety_dlp_anti_peep_enable = false;
```

在 `loadTokenAppearance()` 中添加加载逻辑。

---

### 第 2 层：核心防窥引擎（新建文件）

新建文件：`entry/src/main/ets/utils/DlpAntiPeepManager.ets`

这是一个单例管理器，封装所有 DlpAntiPeep API 调用：

```typescript
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppPreference, PREF_KEYS } from './AppPreference';

export class DlpAntiPeepManager {
  private static instance: DlpAntiPeepManager;
  private isSubscribed: boolean = false;
  private hasShownMask: boolean = false;

  public static getInstance(): DlpAntiPeepManager {
    if (!DlpAntiPeepManager.instance) {
      DlpAntiPeepManager.instance = new DlpAntiPeepManager();
    }
    return DlpAntiPeepManager.instance;
  }

  // 检查设备能力
  public isSupported(): boolean {
    return canIUse('SystemCapability.Security.DlpAntiPeep');
  }

  // 检查开关状态
  public async isSwitchOn(): Promise<boolean> {
    try {
      return await dlpAntiPeep.isDlpAntiPeepSwitchOn();
    } catch (error) {
      console.error(`DlpAntiPeep isSwitchOn failed: ${(error as BusinessError).message}`);
      return false;
    }
  }

  // 启动防窥保护（订阅 + 引导设置）
  public async start(windowClass: window.Window): Promise<void> { ... }
  
  // 停止防窥保护（取消订阅）
  public stop(): void { ... }

  // 拉起系统蒙层
  public async showMaskLayer(windowClass: window.Window): Promise<void> { ... }
  
  // 重置蒙层标志（页面切换时）
  public resetMaskFlag(): void { ... }
}
```

**关键方法实现要点**：

`start()` 方法流程：
1. `canIUse` 检查设备能力 → 不支持则直接返回
2. `isDlpAntiPeepSwitchOn()` 检查开关
3. 已开启 → `dlpAntiPeep.on('dlpAntiPeep', callback)` 订阅
4. 未开启 → `requestAntiPeepOptions(context)` 弹窗引导
5. callback 中：`HIDE` 状态 → `setAntiPeepMaskLayer(windowId)` 拉蒙层；`PASS` 状态 → 恢复

`stop()` 方法：
- `dlpAntiPeep.off('dlpAntiPeep', callback)` 取消订阅

`showMaskLayer()` 方法：
- 通过 `windowClass.getWindowProperties().id` 获取 windowId
- 调用 `dlpAntiPeep.setAntiPeepMaskLayer(windowId)`

---

### 第 3 层：UI 集成（改动现有文件）

改动文件：**3 个**

#### 3.1 EntryAbility.ets — 生命周期集成

在 `onWindowStageCreate` 的 `loadContent` 回调中（获取到 `windowClass` 后），调用防窥保护初始化：

```typescript
// 在 applySettings(windowClass) 之后
if (AppPreference.getPreference(PREF_KEYS.SAFETY_DLP_ANTI_PEEP_ENABLE)) {
  DlpAntiPeepManager.getInstance().start(windowClass);
}
```

#### 3.2 SecuritySheet.ets — 设置入口

在现有的安全设置列表中（例如「后台模糊」下方），添加新的 `SubItemToggle`：

```typescript
SubItemDivider()

SubItemToggle({
  icon: $r('sys.symbol.eye_trianglebadge_exclamationmark'),
  title: $r('app.string.setting_dlp_anti_peep'),
  isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_DLP_ANTI_PEEP_ENABLE) as boolean,
  description: $r('app.string.setting_dlp_anti_peep_des'),
  onChange: (IsOn: boolean) => {
    AppPreference.setPreference(PREF_KEYS.SAFETY_DLP_ANTI_PEEP_ENABLE, IsOn);
    if (IsOn) {
      DlpAntiPeepManager.getInstance().start(this.window.WindowClass!);
    } else {
      DlpAntiPeepManager.getInstance().stop();
    }
  }
})
```

**注意**：`SecuritySheet` 中 `@Local window: AppWindowInfo` 已有 `WindowClass` 引用，可直接传给 Manager。

#### 3.3 TokenListPage.ets / Index.ets — 页面级蒙层状态重置

在 `onPageShow()` 中调用 `DlpAntiPeepManager.getInstance().resetMaskFlag()`，确保每次进入页面都能正确响应新的窥视事件。

---

## 4. 需要添加的资源字符串

| 键名 | 中文 | 英文 |
|------|------|------|
| `dlp_anti_peep_reason` | 用于检测他人窥视屏幕以保护您的令牌隐私 | Used to detect screen peeping to protect your token privacy |
| `setting_dlp_anti_peep` | 防窥保护 | Anti-Peep Protection |
| `setting_dlp_anti_peep_des` | 检测到他人窥视时自动遮盖屏幕内容 | Auto-mask screen when peeping detected |

---

## 5. 文件变更清单（摘要）

| 文件 | 改动类型 | 改动量 |
|------|----------|--------|
| `entry/src/main/module.json5` | 修改 | +8 行 |
| `resources/base/element/string.json` | 修改 | +6 行 |
| `resources/zh_CN/element/string.json` | 修改 | +6 行 |
| `entry/.../utils/AppPreference.ets` | 修改 | +5 行 |
| `entry/.../utils/DlpAntiPeepManager.ets` | **新建** | ~120 行 |
| `entry/.../entryability/EntryAbility.ets` | 修改 | +5 行 |
| `entry/.../pages/setting/SecuritySheet.ets` | 修改 | +14 行 |
| `entry/.../pages/Index.ets` 或 `TokenListPage.ets` | 修改 | +2 行 |

**总计**：1 个新文件 + 7 个修改文件，约 160 行新增代码。

---

## 6. 风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| AGC ACL 权限未申请 | 🔴 高 | 需在 AGC 完成 ACL 权限申请流程 |
| 设备不支持（非 phone 或无硬件） | 🟡 中 | `canIUse` 前置检测，不支持设备隐藏入口或提示 |
| 人脸识别未设置 | 🟡 中 | `requestAntiPeepOptions` 返回 1020600004 时 Toast 提示 |
| 蒙层频繁触发 | 🟢 低 | `hasShownMask` 标志位防抖 |
| 与现有隐私模式冲突 | 🟢 低 | 防窥蒙层是独立系统级覆盖层，不与 `setWindowPrivacyMode` 冲突 |
| wearable/tablet 设备 | 🟡 中 | DeviceSecurityKit 仅限 PHONE；平板/穿戴设备需 `canIUse` 跳过 |

---

## 7. 行为流程

```
用户打开 ohtotptoken
        │
        ▼
EntryAbility.onWindowStageCreate()
  ├─ loadContent('pages/Index')
  ├─ windowClass = getMainWindowSync()
  ├─ applySettings(windowClass)  ─── 隐私模式 / 颜色模式
  └─ if 防窥开关已开启:
       DlpAntiPeepManager.start(windowClass)
         ├─ canIUse('SystemCapability.Security.DlpAntiPeep') ?
         │    NO → 返回（不支持）
         ├─ isDlpAntiPeepSwitchOn() ?
         │    YES → on('dlpAntiPeep', callback)
         │    NO  → requestAntiPeepOptions(context) → 弹窗引导
         └─ callback:
              ├─ PASS → 正常（蒙层消失/不动作）
              └─ HIDE → setAntiPeepMaskLayer(windowId) → 系统蒙层遮盖
                         (+ 可选: publishAntiPeepInformation → 5s 实况窗提醒)

用户前往 SecuritySheet 关闭防窥
        │
        ▼
  onChange(false):
    DlpAntiPeepManager.stop()
      └─ off('dlpAntiPeep', callback)
```

---

## 8. 待确认事项

1. **AGC ACL 权限状态**：`ohos.permission.DLP_GET_HIDE_STATUS` 是否已在 AppGallery Connect 申请？若未申请，需先完成此步骤才能进行代码集成。
2. **实况窗提醒**：`publishAntiPeepInformation()` 是否启用？建议作为可选项（默认关闭），避免骚扰用户。
3. **穿戴设备策略**：当前 `deviceTypes` 包含 `wearable`。防窥 API 仅支持 PHONE，穿戴设备上需完全跳过初始化。
4. **字符串资源文件位置**：项目使用 `$r('app.string.xxx')` 引用，需确认具体的 `element/string.json` 路径。

---

## 9. 实施建议优先级

| 优先级 | 任务 | 依赖 |
|--------|------|------|
| P0 | AGC ACL 权限申请 | 无 |
| P1 | 创建 DlpAntiPeepManager + 添加偏好键 | P0 |
| P2 | EntryAbility 生命周期集成 | P1 |
| P3 | SecuritySheet 设置开关 | P1 |
| P4 | 实况窗提醒（可选） | P2 |
| P5 | 平板/穿戴设备适配 | P2 |
