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
import { SubItemSlider } from '../components/SubItemSlider';
import { SubItemButton } from '../components/SubItemButton';
import { AppWindowInfo } from '../entryability/EntryAbility';

@Preview
@Entry
@ComponentV2
struct AppearancePage {

  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

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
        .zIndex(1)
      Column() {
        List({ space: this.token_preference.app_appearance_item_space }) {
          ListItemGroup({ space: this.token_preference.app_appearance_item_space }) {
            ListItem() {
              TokenItem({
                Config: new TokenConfig('ABC', otpType.TOTP, 'Github', 'Foo Bar'),
                Update: () => {
                }
              })
            }
            .padding({ left: 10, right: 10 })

            ListItem() {
              TokenItem({
                Config: new TokenConfig('ABC', otpType.HOTP, 'Microsoft', 'Some Body'),
                Update: () => {
                }
              })
            }
            .padding({ left: 10, right: 10 })
          }

          ListItemGroup() {
            ListItem()
          }

        }
        .alignListItem(ListItemAlign.Center)
        .width('100%')
        .lanes({ minLength: 400, maxLength: this.token_preference.app_appearance_item_max_width })
        .backdropBlur(100)
        .padding({
          top: 10,
        })
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

              SubItemDivider()

              SubItemSlider({
                icon: $r('sys.symbol.slider_horizontal_2'),
                title: $r('app.string.token_item_slider'),
                items: [
                  {
                    name: $r('app.string.token_item_max_width'),
                    default: this.token_preference.app_appearance_item_max_width,
                    min: 500,
                    max: 1000,
                    step: 50
                  },
                  {
                    name: $r('app.string.token_item_hight'),
                    default: this.token_preference.app_appearance_item_height,
                    min: 50,
                    max: 100,
                    step: 5
                  },
                  {
                    name: $r('app.string.token_item_space'),
                    default: this.token_preference.app_appearance_item_space,
                    min: 5,
                    max: 30,
                    step: 1
                  },
                  {
                    name: $r('app.string.token_logo_size'),
                    default: this.token_preference.app_appearance_logo_size,
                    min: 20,
                    max: 60,
                    step: 5
                  },
                  {
                    name: $r('app.string.token_logo_bg_size'),
                    default: this.token_preference.app_appearance_logo_background_size,
                    min: 25,
                    max: 65,
                    step: 5
                  },
                  {
                    name: $r('app.string.token_logo_bg_r'),
                    default: this.token_preference.app_appearance_logo_background_radius,
                    min: 0,
                    max: Math.round(this.token_preference.app_appearance_logo_background_size / 2),
                    step: 1
                  },
                ],
                description: $r('app.string.token_item_slider_desc'),
                onChange: (index, value) => {
                  switch (index) {
                    case 0: {
                      AppPreference.setPreference('app_appearance_item_max_width', value);
                      this.token_preference.app_appearance_item_max_width = value;
                      break;
                    }
                    case 1: {
                      AppPreference.setPreference('app_appearance_item_height', value);
                      this.token_preference.app_appearance_item_height = value;
                      break;
                    }
                    case 2: {
                      AppPreference.setPreference('app_appearance_item_space', value);
                      this.token_preference.app_appearance_item_space = value;
                      break;
                    }
                    case 3: {
                      AppPreference.setPreference('app_appearance_logo_size', value);
                      this.token_preference.app_appearance_logo_size = value;
                      break;
                    }
                    case 4: {
                      AppPreference.setPreference('app_appearance_logo_background_size', value);
                      this.token_preference.app_appearance_logo_background_size = value;
                      break;
                    }
                    case 5: {
                      AppPreference.setPreference('app_appearance_logo_background_radius', value);
                      this.token_preference.app_appearance_logo_background_radius = value;
                      break;
                    }
                  }
                }
              })

              SubItemDivider()

              SubItemSlider({
                icon: $r('sys.symbol.slider_horizontal_2'),
                title: $r('app.string.token_font_slider'),
                items: [
                  {
                    name: $r('app.string.token_font_size'),
                    default: this.token_preference.app_appearance_token_font_size,
                    min: 10,
                    max: 50,
                    step: 5
                  },
                  {
                    name: $r("app.string.token_font_weight"),
                    default: this.token_preference.app_appearance_token_font_weight,
                    min: 100,
                    max: 900,
                    step: 100
                  },
                  {
                    name: $r('app.string.token_issuer_font_size'),
                    default: this.token_preference.app_appearance_issuer_font_size,
                    min: 10,
                    max: 30,
                    step: 5
                  },
                  {
                    name: $r('app.string.token_issuer_font_weight'),
                    default: this.token_preference.app_appearance_issuer_font_weight,
                    min: 100,
                    max: 900,
                    step: 100
                  },
                  {
                    name: $r('app.string.token_user_name_font_size'),
                    default: this.token_preference.app_appearance_user_name_font_size,
                    min: 5,
                    max: 30,
                    step: 5
                  },
                  {
                    name: $r('app.string.token_user_name_font_weight'),
                    default: this.token_preference.app_appearance_user_name_font_weight,
                    min: 100,
                    max: 900,
                    step: 100
                  },
                ],
                description: $r('app.string.token_item_font_desc'),
                onChange: (index, value) => {
                  switch (index) {
                    case 0: {
                      AppPreference.setPreference('app_appearance_token_font_size', value);
                      this.token_preference.app_appearance_token_font_size = value;
                      break;
                    }
                    case 1: {
                      AppPreference.setPreference('app_appearance_token_font_weight', value);
                      this.token_preference.app_appearance_token_font_weight = value;
                      break;
                    }
                    case 2: {
                      AppPreference.setPreference('app_appearance_issuer_font_size', value);
                      this.token_preference.app_appearance_issuer_font_size = value;
                      break;
                    }
                    case 3: {
                      AppPreference.setPreference('app_appearance_issuer_font_weight', value);
                      this.token_preference.app_appearance_issuer_font_weight = value;
                      break;
                    }
                    case 4: {
                      AppPreference.setPreference('app_appearance_user_name_font_size', value);
                      this.token_preference.app_appearance_user_name_font_size = value;
                      break;
                    }
                    case 5: {
                      AppPreference.setPreference('app_appearance_user_name_font_weight', value);
                      this.token_preference.app_appearance_user_name_font_weight = value;
                      break;
                    }
                  }
                }
              })

            }
          }
          .padding({ left: 10, right: 10 })

          ListItem() {
            SettingItem({ title: $r('app.string.custom_color') }) {
              SubItemColor({
                icon: $r('sys.symbol.paintpalette'),
                title: $r('app.string.custom_color_palette'),
                description: $r('app.string.custom_color_palette_des'),
                colors: [
                  {
                    name: $r('app.string.custom_color_logo_background'),
                    color: this.token_preference.app_appearance_logo_background_color,
                  },
                  {
                    name: $r('app.string.custom_color_logo_dark_filter_color'),
                    color: this.token_preference.app_appearance_logo_dark_filter_color,
                  },
                  {
                    name: $r('app.string.custom_color_token_color'),
                    color: this.token_preference.app_appearance_token_color,
                  },
                  {
                    name: $r('app.string.custom_color_token_next_color'),
                    color: this.token_preference.app_appearance_token_next_color,
                  },
                ],
                onChange: (index, value) => {
                  switch (index) {
                    case 0: {
                      AppPreference.setPreference('app_appearance_logo_background_color', value);
                      this.token_preference.app_appearance_logo_background_color = value;
                      break;
                    }
                    case 1: {
                      AppPreference.setPreference('app_appearance_logo_dark_filter_color', value);
                      this.token_preference.app_appearance_logo_dark_filter_color = value;
                      break;
                    }
                    case 2: {
                      AppPreference.setPreference('app_appearance_token_color', value);
                      this.token_preference.app_appearance_token_color = value;
                      break;
                    }
                    case 3: {
                      AppPreference.setPreference('app_appearance_token_next_color', value);
                      this.token_preference.app_appearance_token_next_color = value;
                      break;
                    }
                  }
                }
              })
            }
          }
          .padding({ left: 10, right: 10 })

          ListItem() {
            SettingItem({ title: $r('app.string.custom_appearance_cmd') }) {
              SubItemButton({
                symbol: $r('sys.symbol.arrow_counterclockwise'),
                text: $r('app.string.appearance_reset_to_default'),
              })
                .onClick(() => {
                  AppPreference.resetAppearanceToDefault();
                })

              SubItemDivider()
            }
          }
          .padding({ left: 10, right: 10 })

          ListItem()
            .height(this.window.AvoidBottomHeight + 56) // 56: navigation_height
        }
        .layoutWeight(1)
        .chainAnimation(true)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)

      }
      .backgroundColor($r('app.color.window_background'))
      .width('100%')
      .height('100%')
    }
    .padding({ top: this.window.AvoidTopHeight })
    .backdropBlur(10)
  }
}