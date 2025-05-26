import { AppStorageV2, router } from '@kit.ArkUI';
import { SettingItem } from '../components/SettingItem';
import { SubItemDivider } from '../components/SubItemDivider';
import { SubItemToggle } from '../components/SubItemToggle';
import { TokenItem } from '../components/TokenItem';
import { TopNavigationView } from '../components/TopNavigationView';
import { AppPreference, TokenPreference } from '../utils/AppPreference';
import { otpType, TokenConfig } from '../utils/TokenConfig';
import { systemDateTime } from '@kit.BasicServicesKit';
import { SubItemColor } from '../components/SubItemColor';

@Preview
@Entry
@ComponentV2
struct AppearancePage {

  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;

  aboutToAppear(): void {
    setInterval(() => {
      const timestamp = Math.floor(systemDateTime.getTime() / 1000);
      if (getContext(this).eventHub != undefined) {
        getContext(this).eventHub.emit('onTimestampChanged', timestamp, false);
      }
    }, 1000);
  }

  build() {
    Column() {
      TopNavigationView({
        title: $r('app.string.customize_appearance'),
        onBackClick: () => {
          router.back();
        }
      })
      RelativeContainer() {
        Column() {
          Column({ space: 10 }) {
            TokenItem({
              Config: new TokenConfig('ABC', otpType.TOTP, 'Github', 'SolidFaker'),
              Update: () => {}
            })
            TokenItem({
              Config: new TokenConfig('ABC', otpType.HOTP, 'Microsoft', 'Bill Gates'),
              Update: () => {}
            })
          }
          .margin({ left: 10, right: 10, top: 10 })
          List({ space: 10 }) {
            ListItem()
            ListItem() {
              SettingItem({ title: $r('app.string.custom_layout') }) {
                SubItemToggle({
                  icon: $r('sys.symbol.transfer_station'),
                  title: $r('app.string.swap_host_user'),
                  isOn: AppPreference.getPreference('app_appearance_swap_host_user_enable') as boolean,
                  description: $r('app.string.swap_host_user_des'),
                  onChange: (IsOn: boolean) => {
                    AppPreference.setPreference('app_appearance_swap_host_user_enable', IsOn);
                    this.token_preference.app_appearance_swap_host_user_enable = IsOn;
                  }
                })

                SubItemDivider()

                SubItemToggle({
                  icon: $r('sys.symbol.star_square_stack_fill'),
                  title: $r('app.string.enable_icon_background'),
                  isOn: AppPreference.getPreference('app_appearance_logo_background') as boolean,
                  description: $r('app.string.enable_icon_background_des'),
                  onChange: (IsOn: boolean) => {
                    AppPreference.setPreference('app_appearance_logo_background', IsOn);
                    this.token_preference.app_appearance_logo_background = IsOn;
                  }
                })

                SubItemDivider()

                SubItemToggle({
                  icon: $r('sys.symbol.circle_lefthalf_inset_filled'),
                  title: $r('app.string.enable_dark_icon_filter'),
                  isOn: AppPreference.getPreference('app_appearance_logo_dark_filter') as boolean,
                  description: $r('app.string.enable_dark_icon_filter_des'),
                  onChange: (IsOn: boolean) => {
                    AppPreference.setPreference('app_appearance_logo_dark_filter', IsOn);
                    this.token_preference.app_appearance_logo_dark_filter = IsOn;
                  }
                })
              }
            }
            .padding({ left: 10, right: 10 })

            ListItem() {
              SettingItem({ title: $r('app.string.custom_color') }) {
                SubItemColor({
                  icon: $r('sys.symbol.transfer_station'),
                  title: $r('app.string.custom_color_logo_background'),
                  color: AppPreference.getPreference('app_appearance_logo_background_color') as string,
                  description: $r('app.string.custom_color_logo_background_des'),
                  onChange: (color: string) => {
                    AppPreference.setPreference('app_appearance_logo_background_color', color);
                    this.token_preference.app_appearance_logo_background_color = color;
                  }
                })
              }
            }
            .padding({ left: 10, right: 10 })

            ListItem()
          }
          .chainAnimation(true)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .backgroundColor($r('app.color.window_background'))
      .width('100%')
      .height('100%')
    }
    .padding({ top: AppStorage.get<number>('statusBarHeight'), bottom: 24 })
  }
}