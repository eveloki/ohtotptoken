import { BusinessError } from '@kit.BasicServicesKit';
import { showSnackBar, SnackBarNotifyType } from '../../utils/HdsSnackBarUtils';
import { SubItemToggle } from '../../components/SubItemToggle'
import { AppStorageV2, curves, router } from '@kit.ArkUI';
import { AppPreference, SettingColorMode, TokenPreference } from '../../utils/AppPreference';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { SubItemSelect } from '../../components/SubItemSelect';
import { SubItemIconManager } from '../../components/SubItemIconManager';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { bundleManager, common, ConfigurationConstant } from '@kit.AbilityKit';
import { throttle } from '../../utils/UiUtils';

@Preview
@ComponentV2
export struct AppearanceSheet {
  @Local debug_mode_is_on: boolean = AppPreference.getPreference('app_debug_mode_on') as boolean;
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
            isOn: AppPreference.getPreference('app_appearance_show_next_token_enable') as boolean,
            description: $r('app.string.show_next_token_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference('app_appearance_show_next_token_enable', IsOn);
              this.token_preference.app_appearance_show_next_token_enable = IsOn;
            }
          })

          SubItemDivider()

          if (this.debug_mode_is_on) {
            SubItemToggle({
              icon: $r('sys.symbol.gearshape'),
              title: $r('app.string.debug_mode'),
              isOn: AppPreference.getPreference('app_debug_mode_on') as boolean,
              description: $r('app.string.debug_mode_des'),
              onChange: (IsOn: boolean) => {
                this.window.uiContext?.animateTo({ curve: curves.springMotion() }, () => {
                  this.debug_mode_is_on = IsOn;
                })
                AppPreference.setPreference('app_debug_mode_on', IsOn);
              }
            })

            SubItemDivider()
          }

          SubItemToggle({
            icon: $r('sys.symbol.face'),
            title: $r('app.string.auto_unlock'),
            isOn: AppPreference.getPreference('app_safety_auto_unlock_enable') as boolean,
            description: $r('app.string.auto_unlock_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference('app_safety_auto_unlock_enable', IsOn);
            }
          })

          SubItemDivider()

          SubItemSelect({
            icon: $r('sys.symbol.dark'),
            title: $r('app.string.setting_color_mode'),
            values: [$r('app.string.setting_color_mode_system'), $r('app.string.setting_color_mode_dark'),
              $r('app.string.setting_color_mode_light'),],
            description: $r('app.string.setting_color_mode_desc'),
            selected: AppPreference.getPreference('app_appearance_color_mode') as number ??
            SettingColorMode.System,
            onChange: (index: number) => {
              AppPreference.setPreference('app_appearance_color_mode', index);
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
