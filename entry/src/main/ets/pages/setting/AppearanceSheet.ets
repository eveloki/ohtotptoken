import { BusinessError } from '@kit.BasicServicesKit';
import { showSnackBar, SnackBarNotifyType } from '../../utils/HdsSnackBarUtils';
import { SubItemToggle } from '../../components/SubItemToggle'
import { AppStorageV2, curves, router } from '@kit.ArkUI';
import { AppPreference, SettingColorMode, SettingTopEffectType, SettingBottomTabsType, TokenPreference, AVAILABLE_TOP_EFFECT_TYPES, AVAILABLE_BOTTOM_TABS_TYPES, EVENT_NAMES, PREF_KEYS } from '../../utils/AppPreference';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { SubItemSelect } from '../../components/SubItemSelect';
import { SubItemEnumSelect } from '../../components/SubItemEnumSelect';
import { SubItemIconManager } from '../../components/SubItemIconManager';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { bundleManager, common, ConfigurationConstant } from '@kit.AbilityKit';
import { throttle } from '../../utils/UiUtils';

@Preview
@ComponentV2
export struct AppearanceSheet {
  @Local debug_mode_is_on: boolean = AppPreference.getPreference(PREF_KEYS.DEBUG_MODE_ON) as boolean;
  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  build() {
    List({ space: 10 }) {
      ListItem() {
        SettingItem({ title: "" }) {
          SubItemToggle({
            icon: $r('sys.symbol.chevron_up_2_circle'),
            title: $r('app.string.show_next_token'),
            isOn: AppPreference.getPreference(PREF_KEYS.APPEARANCE_SHOW_NEXT_TOKEN_ENABLE) as boolean,
            description: $r('app.string.show_next_token_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference(PREF_KEYS.APPEARANCE_SHOW_NEXT_TOKEN_ENABLE, IsOn);
              this.token_preference.app_appearance_show_next_token_enable = IsOn;
            }
          })

          SubItemDivider()

          SubItemToggle({
            icon: $r('sys.symbol.phone_and_hand'),
            title: $r('app.string.setting_holding_hand_awareness'),
            isOn: AppPreference.getPreference(PREF_KEYS.APPEARANCE_HOLDING_HAND_ENABLE) as boolean,
            description: $r('app.string.setting_holding_hand_awareness_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference(PREF_KEYS.APPEARANCE_HOLDING_HAND_ENABLE, IsOn);
              this.token_preference.app_appearance_holding_hand_enable = IsOn;
              this.appCtx.eventHub.emit(EVENT_NAMES.HOLDING_HAND_PREFERENCE_CHANGED, IsOn);
            }
          })

          SubItemDivider()

          if (this.debug_mode_is_on) {
            SubItemToggle({
              icon: $r('sys.symbol.gearshape'),
              title: $r('app.string.debug_mode'),
              isOn: AppPreference.getPreference(PREF_KEYS.DEBUG_MODE_ON) as boolean,
              description: $r('app.string.debug_mode_des'),
              onChange: (IsOn: boolean) => {
                this.window.uiContext?.animateTo({ curve: curves.springMotion() }, () => {
                  this.debug_mode_is_on = IsOn;
                })
                AppPreference.setPreference(PREF_KEYS.DEBUG_MODE_ON, IsOn);
              }
            })

            SubItemDivider()
          }

          SubItemToggle({
            icon: $r('sys.symbol.face'),
            title: $r('app.string.auto_unlock'),
            isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_AUTO_UNLOCK_ENABLE) as boolean,
            description: $r('app.string.auto_unlock_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference(PREF_KEYS.SAFETY_AUTO_UNLOCK_ENABLE, IsOn);
            }
          })

          SubItemDivider()

          SubItemSelect({
            icon: $r('sys.symbol.dark'),
            title: $r('app.string.setting_color_mode'),
            values: [$r('app.string.setting_color_mode_system'), $r('app.string.setting_color_mode_dark'),
              $r('app.string.setting_color_mode_light'),],
            description: $r('app.string.setting_color_mode_desc'),
            selected: AppPreference.getPreference(PREF_KEYS.APPEARANCE_COLOR_MODE) as number ??
            SettingColorMode.System,
            onChange: (index: number) => {
              AppPreference.setPreference(PREF_KEYS.APPEARANCE_COLOR_MODE, index);
              const color_map: Map<SettingColorMode, ConfigurationConstant.ColorMode> = new Map([
                [SettingColorMode.System, ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET],
                [SettingColorMode.Dark, ConfigurationConstant.ColorMode.COLOR_MODE_DARK],
                [SettingColorMode.Light, ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT],
              ]);
              this.appCtx.getApplicationContext().setColorMode(color_map.get(index));
            }
          })

          SubItemDivider()

          SubItemIconManager()

          SubItemDivider()

          SubItemButton({
            symbol: $r("sys.symbol.paintpalette"),
            text: $r('app.string.customize_appearance')
          })
            .onClick(throttle((event) => {
              router.pushUrl({ url: 'pages/AppearancePage' });
            }, 1000))
          SubItemDivider()

          // 顶部模糊效果类型选择
          SubItemEnumSelect({
            icon: $r('sys.symbol.slider_horizontal_2'),
            title: $r('app.string.setting_top_effect_type'),
            options: AVAILABLE_TOP_EFFECT_TYPES,
            description: $r('app.string.setting_top_effect_type_desc'),
            selected: AppPreference.getPreference(PREF_KEYS.APPEARANCE_TOP_EFFECT_TYPE) as number ??
            SettingTopEffectType.GRADUAL_BLUR,
            onChange: (value: number) => {
              AppPreference.setPreference(PREF_KEYS.APPEARANCE_TOP_EFFECT_TYPE, value);
              // 发送事件通知Index页面更新滚动效果类型
              if (this.appCtx.eventHub != undefined) {
                this.appCtx.eventHub.emit(EVENT_NAMES.TOP_EFFECT_TYPE_CHANGED);
              }
            }
          })

          //底部tabs暂时不知道怎么实现 先屏蔽
          SubItemDivider()

          // 底部Tabs类型选择
          SubItemEnumSelect({
            icon: $r('sys.symbol.slider_horizontal_2'),
            title: $r('app.string.setting_bottom_tabs_type'),
            options: AVAILABLE_BOTTOM_TABS_TYPES,
            description: $r('app.string.setting_bottom_tabs_type_desc'),
            selected: AppPreference.getPreference(PREF_KEYS.APPEARANCE_BOTTOM_TABS_TYPE) as number ??
            SettingBottomTabsType.FLATTEN,
            onChange: (value: number) => {
              AppPreference.setPreference(PREF_KEYS.APPEARANCE_BOTTOM_TABS_TYPE, value);
            }
          })
        }
      }
      .padding({ left: 10, right: 10 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, {alwaysEnabled: true})
    .backgroundColor($r('app.color.window_background'))
  }
}
