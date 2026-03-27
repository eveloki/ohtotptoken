import { BusinessError } from '@kit.BasicServicesKit';
import { showSnackBar, SnackBarNotifyType } from '../../utils/HdsSnackBarUtils';
import { SubItemToggle } from '../../components/SubItemToggle'
import { AppStorageV2, curves, router } from '@kit.ArkUI';
import { AppPreference, TokenPreference, EVENT_NAMES, PREF_KEYS } from '../../utils/AppPreference';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { userAuth } from '@kit.UserAuthenticationKit';
import { SubItemDivider } from '../../components/SubItemDivider';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { bundleManager,common } from '@kit.AbilityKit';

@Preview
@ComponentV2
export struct SecuritySheet {
  @Local is_master_key_enable: boolean = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY) as boolean;
  @Local is_master_key_set: boolean = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;
  aboutToAppear(): void {
    this.appCtx.eventHub.on(EVENT_NAMES.MASTER_KEY_PAGE_BACK,()=>{
      this.is_master_key_set = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    })
  }

  aboutToDisappear() {
    this.appCtx.eventHub.off(EVENT_NAMES.MASTER_KEY_PAGE_BACK);
  }

  build() {
    List({ space: 10 }) {
      ListItem() {
        SettingItem({ title: "" }) {
          SubItemToggle({
            icon: $r('sys.symbol.staroflife_rectangle'),
            title: $r('app.string.restore_master_key'),
            isOn: AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY) as boolean,
            description: $r('app.string.restore_master_key_msg'),
            onChange: (IsOn: boolean) => {
              this.window.uiContext?.animateTo({ curve: curves.springMotion() }, () => {
                this.is_master_key_enable = IsOn;
              })
              AppPreference.setPreference(PREF_KEYS.USE_MASTER_KEY, IsOn);
            }
          })
          if (this.is_master_key_enable) {
            SubItemDivider()
            SubItemButton({
              symbol: $r('sys.symbol.key_shield'),
              text: $r('app.string.restore_master_key_set'),
              description:this.is_master_key_set?$r('app.string.restore_master_key_reset_desc'):$r('app.string.restore_master_key_no_set_desc'),
              descriptionColor:this.is_master_key_set?$r('sys.color.ohos_id_color_text_secondary'):$r('app.color.token_progress_next_color_end')
            })
              .onClick(() => {
                router.pushUrl({ url: 'pages/MasterKeyPage' });
              })
          }

          SubItemDivider()

          SubItemToggle({
            icon: $r('sys.symbol.hand_raised_hexagon'),
            title: $r('app.string.setting_safety_privacy'),
            isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_PRIVACY_ENABLE) as boolean,
            description: $r('app.string.setting_safety_privacy_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference(PREF_KEYS.SAFETY_PRIVACY_ENABLE, IsOn);
              try {
                this.window.WindowClass?.setWindowPrivacyMode(IsOn).catch((err: BusinessError) => {
                  console.error(`Failed to set the window to privacy mode. Cause code: ${err.code}, message: ${err.message}`);
                });
              } catch (exception) {
                console.error(`Failed to set the window to privacy mode. Cause code: ${exception.code}, message: ${exception.message}`);
              }
            }
          })

          SubItemDivider()

          SubItemToggle({
            icon: $r('sys.symbol.key_shield'),
            title: $r('app.string.setting_safety_lock'),
            isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_LOCK_ENABLE) as boolean,
            description: $r('app.string.setting_safety_lock_des'),
            onChange: (IsOn: boolean) => {
              if (IsOn) {
                try {
                  userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
                } catch (err) {
                  const error = err as BusinessError;
                  showSnackBar(error.message, SnackBarNotifyType.ERROR);
                  return;
                }
              }
              AppPreference.setPreference(PREF_KEYS.SAFETY_LOCK_ENABLE, IsOn);
            }
          })

          SubItemDivider()

          SubItemToggle({
            icon: $r('sys.symbol.eye_slash'),
            title: $r('app.string.setting_hide_token'),
            isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_HIDE_TOKEN_ENABLE) as boolean,
            description: $r('app.string.setting_safety_hide_token_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference(PREF_KEYS.SAFETY_HIDE_TOKEN_ENABLE, IsOn);
              this.token_preference.app_safety_hide_token_enable = IsOn;
            }
          })

          SubItemDivider()

          SubItemToggle({
            icon: $r('sys.symbol.blur_bar'),
            title: $r('app.string.setting_background_blur'),
            isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_BACKGROUND_BLUR_ENABLE) as boolean,
            description: $r('app.string.setting_background_blur_des'),
            onChange: (IsOn: boolean) => {
              AppPreference.setPreference(PREF_KEYS.SAFETY_BACKGROUND_BLUR_ENABLE, IsOn);
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
