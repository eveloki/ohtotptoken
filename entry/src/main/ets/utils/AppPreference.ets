import { PreferenceManager } from "./PreferenceManager";
import { AppStorageV2 } from "@kit.ArkUI";

/**
 * 设置值的联合类型
 */
export type SettingValue = boolean | string | number | SettingColorMode;

/**
 * 颜色模式枚举
 */
export enum SettingColorMode {
  /** 跟随系统 */
  System,
  /** 深色模式 */
  Dark,
  /** 浅色模式 */
  Light,
}

/**
 * 顶部模糊效果类型枚举
 */
export enum SettingTopEffectType {
  /** 关闭模糊效果 */
  DISABLE,
  /** 通用模糊 */
  COMMON_BLUR,
  /** 过渡模糊 */
  GRADUAL_BLUR,
  /** 渐变模糊 */
  GRADIENT_BLUR,
  /** 沉浸式渐变模糊（需要API23支持） */
  IMMERSIVE_GRADIENT_BLUR
}

/**
 * 枚举选择选项接口
 * 用于SubItemEnumSelect组件，将UI显示文本与枚举值进行映射
 */
export interface EnumSelectOption {
  /** 显示文本，支持字符串或资源引用 */
  label: string | Resource;
  /** 对应的枚举值（number类型） */
  value: number;
}

/**
 * 当前支持的顶部模糊类型选项数组
 *
 * @example
 * 当API23支持后，可添加沉浸式渐变模糊选项
 */
export const AVAILABLE_TOP_EFFECT_TYPES: EnumSelectOption[] = [
  { label: $r('app.string.setting_top_effect_type_common_blur'), value: SettingTopEffectType.COMMON_BLUR },
  { label: $r('app.string.setting_top_effect_type_gradual_blur'), value: SettingTopEffectType.GRADUAL_BLUR },
  { label: $r('app.string.setting_top_effect_type_gradient_blur'), value: SettingTopEffectType.GRADIENT_BLUR },
  // 未来API23支持后可添加：
  // { label: $r('app.string.setting_top_effect_type_immersive_gradient_blur'), value: SettingTopEffectType.IMMERSIVE_GRADIENT_BLUR },
];

/**
 * 底部Tabs类型枚举
 */
export enum SettingBottomTabsType {
  /** 平铺模式 */
  FLATTEN,
  /** 悬浮模式 */
  SUSPENSION,
}

/**
 * 当前支持的底部Tabs类型选项数组
 */
export const AVAILABLE_BOTTOM_TABS_TYPES: EnumSelectOption[] = [
  { label: $r('app.string.setting_bottom_tabs_type_flatten'), value: SettingBottomTabsType.FLATTEN },
  { label: $r('app.string.setting_bottom_tabs_type_suspension'), value: SettingBottomTabsType.SUSPENSION },
];

/**
 * Token外观配置类
 * 用于存储和管理令牌的外观相关设置
 */
@ObservedV2
export class TokenPreference {
  @Trace app_safety_hide_token_enable = false;
  @Trace app_appearance_show_next_token_enable = false;
  @Trace app_appearance_swap_host_user_enable = false;
  @Trace app_appearance_item_height = 60;
  @Trace app_appearance_item_space = 10;
  @Trace app_appearance_logo_size = 40;
  @Trace app_appearance_logo_background = false;
  @Trace app_appearance_logo_background_size = 45;
  @Trace app_appearance_logo_background_radius = 5;
  @Trace app_appearance_logo_background_color = 0xffececec;
  @Trace app_appearance_logo_dark_filter = false;
  @Trace app_appearance_logo_dark_filter_color = 0xFFD6D6D6;
  @Trace app_appearance_token_color = 0xFF012EE0;
  @Trace app_appearance_token_color_dark = 0xFF638FF6;
  @Trace app_appearance_token_next_color = 0xFFD71616;
  @Trace app_appearance_token_next_color_dark = 0xFFD71616;
  @Trace app_appearance_token_counter_light_color_start = 0xFF86c1ff;
  @Trace app_appearance_token_counter_light_color_end = 0xFF254ff7;
  @Trace app_appearance_token_counter_dark_color_start = 0xFF86c1ff;
  @Trace app_appearance_token_counter_dark_color_end = 0xFF254ff7;
  @Trace app_appearance_token_counter_next_color_enable = false;
  @Trace app_appearance_token_counter_next_margin = 5;
  @Trace app_appearance_token_counter_next_light_color_start = 0xFFF18585;
  @Trace app_appearance_token_counter_next_light_color_end = 0xFFD71616;
  @Trace app_appearance_token_counter_next_dark_color_start = 0xFFF18585;
  @Trace app_appearance_token_counter_next_dark_color_end = 0xFFD71616;
  @Trace app_appearance_token_font_weight = 400;
  @Trace app_appearance_token_font_size = 30;
  @Trace app_appearance_issuer_font_size = 18;
  @Trace app_appearance_issuer_font_weight = 400;
  @Trace app_appearance_user_name_font_size = 10;
  @Trace app_appearance_user_name_font_weight = 400;
  @Trace app_appearance_item_max_width = 800;
}

/**
 * 应用偏好设置管理类
 * 提供应用设置的读取、写入和持久化功能
 */
export class AppPreference {
  /** 偏好设置管理器实例 */
  private static prefMgr = PreferenceManager.getInstance();

  private static settings_default: Map<string, SettingValue> = new Map<string, SettingValue>([
    // 安全性-隐私模式设置
    ['app_safety_privacy_enable', false],
    // 安全性-应用锁定设置
    ['app_safety_lock_enable', false],
    // 安全性-隐藏令牌
    ['app_safety_hide_token_enable', false],
    // 安全性-自动解锁
    ['app_safety_auto_unlock_enable', false],
    // 安全性-后台模糊
    ['app_safety_background_blur_enable', false],
    // 外观-显示下一个令牌
    ['app_appearance_show_next_token_enable', false],
    // 外观-颜色模式
    ['app_appearance_color_mode', SettingColorMode.System],
    // 外观-图标包
    ['app_appearance_icon_pack_selected', 0],
    // 数据库是否启用云同步
    ['app_db_rds_cloud_sync_enable', false],
    // 数据库是否启用跨设备流转
    ['app_db_rds_sync_enable', false],
    // kv数据库同步时间
    ['app_db_kv_sync_time', ''],
    // kv数据库存档时间
    ['app_db_kv_archive_time', ''],
    // kv数据库存档正在进行
    ['app_db_kv_archive_is_running',false],
    // 是否显示引导提示
    ['app_show_guide_tips', true],
    // 是否处于debug模式
    ['app_debug_mode_on', false],
    // 是否使用主密码增强安全
    ['app_use_master_key', false],
    // 是否已经配置了主密码
    ['app_use_master_key_set', false]
  ]);

  private static appearance_default: Map<string, SettingValue> = new Map<string, SettingValue>([
    // 外观-自定义
    ['app_appearance_swap_host_user_enable', false],
    ['app_appearance_logo_background', false],
    ['app_appearance_item_height', 60],
    ['app_appearance_item_space', 10],
    ['app_appearance_logo_size', 40],
    ['app_appearance_logo_background_size', 45],
    ['app_appearance_logo_background_radius', 5],
    ['app_appearance_logo_background_color', 0xffececec],
    ['app_appearance_logo_dark_filter', false],
    ['app_appearance_logo_dark_filter_color', 0xFFD6D6D6],
    ['app_appearance_token_color', 0xFF254ff7],
    ['app_appearance_token_next_color', 0xFFD71616],
    ['app_appearance_token_color_dark', 0xFF638FF6],
    ['app_appearance_token_next_color_dark', 0xFFD71616],
    ['app_appearance_token_counter_light_color_start', 0xFF86c1ff],
    ['app_appearance_token_counter_light_color_end', 0xFF254ff7],
    ['app_appearance_token_counter_dark_color_start', 0xFF86c1ff],
    ['app_appearance_token_counter_dark_color_end', 0xFF254ff7],
    ['app_appearance_token_counter_next_color_enable', false],
    ['app_appearance_token_counter_next_margin', 5],
    ['app_appearance_token_counter_next_light_color_start', 0xFFF18585],
    ['app_appearance_token_counter_next_light_color_end', 0xFFD71616],
    ['app_appearance_token_counter_next_dark_color_start', 0xFFF18585],
    ['app_appearance_token_counter_next_dark_color_end', 0xFFD71616],
    ['app_appearance_token_font_weight', 400],
    ['app_appearance_token_font_size', 30],
    ['app_appearance_issuer_font_size', 18],
    ['app_appearance_issuer_font_weight', 400],
    ['app_appearance_user_name_font_size', 10],
    ['app_appearance_user_name_font_weight', 400],
    ['app_appearance_item_max_width', 800],
    // 外观-顶部模糊类型
    ['app_appearance_top_effect_type', SettingTopEffectType.GRADUAL_BLUR],
    // 外观-底部Tabs类型
    ['app_appearance_bottom_tabs_type', SettingBottomTabsType.FLATTEN]
  ]);

  private static settings: Map<string, SettingValue> = new Map<string, SettingValue>([
    ...Array.from(AppPreference.settings_default.entries()),
    ...Array.from(AppPreference.appearance_default.entries())
  ]);

  /**
   * 获取偏好设置值
   * @param key - 设置键名
   * @returns 设置值，如果不存在则返回空字符串
   */
  public static getPreference(key: string): SettingValue {
    return AppPreference.settings.get(key) ?? '';
  }

  /**
   * 设置偏好设置值
   * @param key - 设置键名
   * @param value - 设置值
   */
  public static setPreference(key: string, value: SettingValue): void {
    AppPreference.settings.set(key, value);
    AppPreference.prefMgr.setValue<SettingValue>(key, value);
  }

  /**
   * 从持久化存储加载所有设置
   * @returns Promise对象，表示加载操作完成
   */
  public static async loadSettings(): Promise<void> {
    const promises = Array.from(AppPreference.settings.keys()).map(async (k) => {
      await AppPreference.prefMgr.getValue<SettingValue>(k).then((val) => {
        if (val !== undefined && val !== null) {
          AppPreference.settings.set(k, val);
        }
      })
    });
    await Promise.all(promises);
    AppPreference.loadTokenAppearance();
  }

  /**
   * 加载Token外观设置到AppStorageV2
   * 从偏好设置中读取外观相关配置并更新到TokenPreference对象
   */
  private static loadTokenAppearance(): void {
    let token_appearance: TokenPreference = AppStorageV2.connect(TokenPreference, () => new TokenPreference())!;
    token_appearance.app_safety_hide_token_enable = AppPreference.getPreference('app_safety_hide_token_enable') as boolean;
    token_appearance.app_appearance_show_next_token_enable = AppPreference.getPreference('app_appearance_show_next_token_enable') as boolean;
    token_appearance.app_appearance_swap_host_user_enable = AppPreference.getPreference('app_appearance_swap_host_user_enable') as boolean;
    token_appearance.app_appearance_logo_background = AppPreference.getPreference('app_appearance_logo_background') as boolean;
    token_appearance.app_appearance_item_height = AppPreference.getPreference('app_appearance_item_height') as number;
    token_appearance.app_appearance_item_space = AppPreference.getPreference('app_appearance_item_space') as number;
    token_appearance.app_appearance_logo_size = AppPreference.getPreference('app_appearance_logo_size') as number;
    token_appearance.app_appearance_logo_background_size = AppPreference.getPreference('app_appearance_logo_background_size') as number;
    token_appearance.app_appearance_logo_background_radius = AppPreference.getPreference('app_appearance_logo_background_radius') as number;
    token_appearance.app_appearance_logo_background_color = AppPreference.getPreference('app_appearance_logo_background_color') as number;
    token_appearance.app_appearance_logo_dark_filter = AppPreference.getPreference('app_appearance_logo_dark_filter') as boolean;
    token_appearance.app_appearance_logo_dark_filter_color = AppPreference.getPreference('app_appearance_logo_dark_filter_color') as number;
    token_appearance.app_appearance_token_color = AppPreference.getPreference('app_appearance_token_color') as number;
    token_appearance.app_appearance_token_next_color = AppPreference.getPreference('app_appearance_token_next_color') as number;
    token_appearance.app_appearance_token_color_dark = AppPreference.getPreference('app_appearance_token_color_dark') as number;
    token_appearance.app_appearance_token_next_color_dark = AppPreference.getPreference('app_appearance_token_next_color_dark') as number;
    token_appearance.app_appearance_token_counter_light_color_start = AppPreference.getPreference('app_appearance_token_counter_light_color_start') as number;
    token_appearance.app_appearance_token_counter_light_color_end = AppPreference.getPreference('app_appearance_token_counter_light_color_end') as number;
    token_appearance.app_appearance_token_counter_dark_color_start = AppPreference.getPreference('app_appearance_token_counter_dark_color_start') as number;
    token_appearance.app_appearance_token_counter_dark_color_end = AppPreference.getPreference('app_appearance_token_counter_dark_color_end') as number;
    token_appearance.app_appearance_token_counter_next_color_enable = AppPreference.getPreference('app_appearance_token_counter_next_color_enable') as boolean;
    token_appearance.app_appearance_token_counter_next_margin = AppPreference.getPreference('app_appearance_token_counter_next_margin') as number;
    token_appearance.app_appearance_token_counter_next_light_color_start = AppPreference.getPreference('app_appearance_token_counter_next_light_color_start') as number;
    token_appearance.app_appearance_token_counter_next_light_color_end = AppPreference.getPreference('app_appearance_token_counter_next_light_color_end') as number;
    token_appearance.app_appearance_token_counter_next_dark_color_start = AppPreference.getPreference('app_appearance_token_counter_next_dark_color_start') as number;
    token_appearance.app_appearance_token_counter_next_dark_color_end = AppPreference.getPreference('app_appearance_token_counter_next_dark_color_end') as number;
    token_appearance.app_appearance_token_font_weight = AppPreference.getPreference('app_appearance_token_font_weight') as FontWeight;
    token_appearance.app_appearance_token_font_size = AppPreference.getPreference('app_appearance_token_font_size') as number;
    token_appearance.app_appearance_issuer_font_size = AppPreference.getPreference('app_appearance_issuer_font_size') as number;
    token_appearance.app_appearance_issuer_font_weight = AppPreference.getPreference('app_appearance_issuer_font_weight') as FontWeight;
    token_appearance.app_appearance_user_name_font_size = AppPreference.getPreference('app_appearance_user_name_font_size') as number;
    token_appearance.app_appearance_user_name_font_weight = AppPreference.getPreference('app_appearance_user_name_font_weight') as FontWeight;
    token_appearance.app_appearance_item_max_width = AppPreference.getPreference('app_appearance_item_max_width') as number;
  }

  /**
   * 重置外观设置为默认值
   * 将所有外观相关设置恢复为默认配置
   */
  public static resetAppearanceToDefault(): void {
    for (const entry of AppPreference.appearance_default) {
      AppPreference.setPreference(entry[0], entry[1]);
    }
    AppPreference.loadTokenAppearance();
  }

  public static saveSettings(): void {
    AppPreference.prefMgr.saveUserData();
  }

  private constructor() {
  }
}