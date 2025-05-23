import { TokenItem } from "../components/TokenItem";
import { FortiConfigDialog } from "../dialogs/FortiConfigDialog";
import { TOTPConfigDialog } from "../dialogs/OTPConfigDialog";
import { QRCodeDialog } from "../dialogs/QRCodeDialog";
import { SteamConfigDialog } from "../dialogs/SteamConfigDialog";
import { AppPreference, SettingValue } from "../utils/AppPreference";
import { otpType, TokenConfig } from "../utils/TokenConfig";
import { TokenStore } from "../utils/TokenStore";
import { convertToken2URI, ScanBarCode } from "../utils/TokenUtils";
import { curves } from "@kit.ArkUI";
import { url } from "@kit.ArkTS";
import { decodeProtobuf } from "../utils/GoogleAuthUtils";
import { URIConfigDialog } from "../dialogs/URIConfigDialog";

let tkStore = TokenStore.getInstance();

@Preview
@ComponentV2
export struct TokenListPage {
  @Require @Param Tokens: TokenConfig[] = [];
  @Require @Param appBottomAvoidHeight: number = 0;
  @Require @Param appTopAvoidHeight: number = 0;
  @Event updateTokenConfig: (conf: TokenConfig, toast: boolean) => void = () => {};
  @Event updateTokenConfigs: (tokens: Array<TokenConfig>) => void = () => {};

  @Require @Param token_hide_enable: SettingValue = AppPreference.getAppearance('app_safety_hide_token_enable');
  @Require @Param show_next_token_enable: SettingValue = AppPreference.getAppearance('app_appearance_show_next_token_enable');
  @Require @Param swap_host_user_enable: SettingValue = AppPreference.getAppearance('app_appearance_swap_host_user_enable');

  @Local token_copy_guide_popup: boolean = false;
  @Local token_list_lanes: number = 1;

  @Local token_list_search_result: TokenConfig[] = [];
  @Local token_list_search_start: boolean = false;
  @Local token_list_search_visible: boolean = false;
  @Local token_list_search_enable: boolean = false;
  @Local token_list_touch_down_pos: number = 0;
  @Local token_list_touch_move_pos: number = 0;
  @Local token_list_search_str: string = '';
  @Local id_list: string[] = ['search_bar'];

  @Local btn_token_add_clicked: number = 0;

  private dialog_uri_config?: CustomDialogController;
  private dialog_totp_config?: CustomDialogController;
  private dialog_forti_config?: CustomDialogController;
  private dialog_steam_config?: CustomDialogController;
  private dialog_qrcode?: CustomDialogController;

  async filterCurrentTokens(filter_word: string): Promise<void> {
    if (filter_word.length === 0) {
      this.token_list_search_enable = false;
      return;
    }
    this.token_list_search_enable = true;
    const lower_filter_word = filter_word.toLowerCase();
    this.token_list_search_result = this.Tokens.filter((token) => {
      return token.TokenIssuer.toLowerCase().indexOf(lower_filter_word) >= 0 || token.TokenName.toLowerCase().indexOf(lower_filter_word) >= 0
    })
  }

  aboutToAppear(): void {
    // 如果已经点击了我知道了则永远不提示了
    if (AppPreference.getAppearance('app_show_guide_tips') as boolean) {
      this.token_copy_guide_popup = true;
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.Tokens.length === 0) {
        Row() {
          Text(this.token_list_search_enable ? $r('app.string.app_token_list_search_msg') :
          $r('app.string.app_guide_msg'))
            .textAlign(TextAlign.Center)
            .fontSize(20)
            .width('100%')
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')
        .height('100%')

      }
      Column() {
        List({ space: 10, initialIndex: 0 }) {
          ListItemGroup() {
            ListItem() {
              Column() {
                Row()
                  .height(50 + this.appTopAvoidHeight)
                  .width('100%')
                Stack({ alignContent: Alignment.End }) {
                  TextInput({
                    placeholder: $r('app.string.token_search_placeholder'),
                    text: this.token_list_search_str
                  })
                    .id(this.id_list[0])
                    .onChange((value) => {
                      this.token_list_search_str = value;
                    })
                    .onSubmit(() => {
                      this.filterCurrentTokens(this.token_list_search_str);
                    })
                  SymbolGlyph(this.token_list_search_enable ? $r('sys.symbol.xmark') :
                  $r('sys.symbol.magnifyingglass'))
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor([$r('app.color.item_fg')])
                    .padding({ right: 10 })
                    .onClick(() => {
                      if (this.token_list_search_enable) {
                        this.token_list_search_str = '';
                      }
                      this.filterCurrentTokens(this.token_list_search_str);
                    })
                }
                .padding({ left: 10, right: 10, top: 10 })
                .width('100%')
                .visibility(this.token_list_search_visible || this.token_list_search_enable ?
                Visibility.Visible : Visibility.None)
              }
            }
          }

          ForEach(this.token_list_search_enable ? this.token_list_search_result : this.Tokens, (token: TokenConfig, index: number) => {
            ListItem() {
              TokenItem({
                Config: token,
                TokenHideEnable: this.token_hide_enable as boolean,
                ShowNextTokenEnable: this.show_next_token_enable as boolean,
                SwapHostUserEnable: this.swap_host_user_enable as boolean,
                Update: async (conf_new) => {
                  this.updateTokenConfig(conf_new, false);
                }
              })
                .bindPopup(this.token_copy_guide_popup && index === 0, {
                  placement: Placement.Left,
                  message: getContext(this)
                    .resourceManager
                    .getStringSync($r('app.string.token_copy_guide_popup'))
                    .toString(),
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.token_copy_guide_popup = false
                    }
                  },
                  primaryButton: {
                    value: getContext(this)
                      .resourceManager
                      .getStringSync($r('app.string.token_copy_guide_popup_Confirm'))
                      .toString(),
                    action: () => {
                      if (AppPreference.getAppearance('app_show_guide_tips') as boolean) {
                        AppPreference.setAppearance('app_show_guide_tips', false)
                      }
                      this.token_copy_guide_popup = false;
                    }
                  }
                })

            }
            .padding({ left: 10, right: 10 })
            .swipeAction({
              start: {
                builder: () => {
                  this.TokenItemStart(token, index)
                }
              },
              end: {
                builder: () => {
                  this.TokenItemEnd(token)
                },
              }
            })
            .onTouch((event?: TouchEvent) => {
              let isMoving = false;
              if (event?.type === TouchType.Down) {
                setTimeout(() => {
                  if (!isMoving) this.token_list_search_start = false;
                }, 200)
              }
              if (event?.type === TouchType.Move) {
                isMoving = true;
              } else {
                this.token_list_search_start = true;
              }
            })
          }, (item: TokenConfig) => {
            return JSON.stringify(item)
          })
            .onMove((from, to) => {
              if (!this.token_list_search_enable) {
                // wait 500ms for animation done
                setTimeout(() => tkStore.updateTokenRank(from, to), 500);
              }
            })
          ListItemGroup() {
            ListItem() {
              Row()
                .width('100%')
                .height(this.appBottomAvoidHeight + 40)
            }
          }
        }
        .lanes(this.token_list_lanes)
        .layoutWeight(1)
        .width('100%')
        .height('100%')
        .chainAnimation(true)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onSizeChange((_, newValue: SizeOptions) => {
          this.token_list_lanes = (newValue.width as number ?? 400) / 400;
        })
        .onTouch((event?: TouchEvent) => {
          animateTo({ curve: curves.springMotion() }, () => {
            if (event?.type === TouchType.Down) {
              this.token_list_touch_down_pos = event.touches[0].y;
            }
            if (event?.type === TouchType.Move) {
              this.token_list_touch_move_pos = event.touches[0].y - this.token_list_touch_down_pos;
              if (this.token_list_search_start) {
                if (this.token_list_touch_move_pos > 200) {
                  this.token_list_search_visible = true;
                  focusControl.requestFocus(this.id_list[0])
                } else if (this.token_list_touch_move_pos < -50) {
                  this.token_list_search_visible = false;
                }
              } else {
                this.token_list_search_visible = false;
              }
            }
          })

        })
      }
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor([Color.White])
          .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP),
            this.btn_token_add_clicked)
      }
      .backgroundColor($r('app.color.token_number'))
      .shadow({ radius: 10, color: $r('app.color.shadow') })
      .margin({ bottom: 10, right: 10 })
      .padding(10)
      .bindMenu(this.TokenAddMenu())
      .onClick(() => {
        this.btn_token_add_clicked += 1
      })
      .accessibilityText($r('app.string.app_ua_add_token'))
    }
  }

  @Builder
  TokenItemStart(conf: TokenConfig, index: number) {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Circle }) {
        Text() {
          SymbolSpan($r('sys.symbol.qrcode'))
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor([Color.White])
        }
      }
      .backgroundColor(Color.Orange)
      .padding(10)
      .onClick(() => {
        this.dialog_qrcode = new CustomDialogController({
          builder: QRCodeDialog({
            content: convertToken2URI(conf)
          })
        });
        this.dialog_qrcode.open();
      })
    }
    .margin({ right: 10 })
    .width(50)
  }

  @Builder
  TokenItemEnd(conf: TokenConfig) {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Circle }) {
        Text() {
          SymbolSpan($r('sys.symbol.trash'))
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor([Color.White])
        }
      }
      .backgroundColor(Color.Red)
      .padding(10)
      .onClick(async () => {
        AlertDialog.show({
          message: $r('app.string.alert_remove_confirm_msg', conf.TokenName),
          autoCancel: true,
          alignment: DialogAlignment.Center,
          primaryButton: {
            defaultFocus: false,
            value: $r('app.string.dialog_btn_cancel'),
            action: () => {
              return
            }
          },
          secondaryButton: {
            value: $r('app.string.dialog_btn_confirm'),
            fontColor: Color.Red,
            action: async () => {
              tkStore.deleteToken(conf.TokenUUID);
            }
          }
        })
      })
      Button({ type: ButtonType.Circle }) {
        Text() {
          SymbolSpan($r('sys.symbol.square_and_pencil'))
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor([Color.White])
        }
      }
      .backgroundColor(Color.Gray)
      .padding(10)
      .onClick(() => {
        if (conf.TokenType === otpType.TOTP || conf.TokenType === otpType.HOTP || conf.TokenType === undefined) { // default
          this.dialog_totp_config = new CustomDialogController({
            builder: TOTPConfigDialog({
              conf_json: JSON.stringify(conf),
              confirm: (new_conf) => {
                this.updateTokenConfig(JSON.parse(new_conf), true)
              }
            })
          })
          this.dialog_totp_config.open()
        } else if (conf.TokenType === otpType.Forti) { // forti
          this.dialog_forti_config = new CustomDialogController({
            builder: FortiConfigDialog({
              conf_json: JSON.stringify(conf),
              confirm: (new_conf) => {
                this.updateTokenConfig(JSON.parse(new_conf), true)
              }
            })
          })
          this.dialog_forti_config.open()
        } else if (conf.TokenType === otpType.Steam) { // steam
          this.dialog_steam_config = new CustomDialogController({
            builder: SteamConfigDialog({
              conf_json: JSON.stringify(conf),
              confirm: (new_conf) => {
                this.updateTokenConfig(JSON.parse(new_conf), true)
              }
            })
          })
          this.dialog_steam_config.open()
        }
      })
    }
    .margin({ left: 10 })
  }

  @Builder
  TokenAddMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.app_scan_code') })
        .onClick(async () => {
          ScanBarCode().then((code) => {
            // google authenticator migration
            if (code.startsWith('otpauth-migration://offline?data=')) {
              const data = new url.URLParams(url.URL.parseURL(code).search).get("data");
              decodeProtobuf(decodeURIComponent(data ?? '')).then((confs) => {
                this.updateTokenConfigs(confs);
              });
            } else if (code.startsWith('otpauth://')) {
              this.dialog_totp_config = new CustomDialogController({
                builder: TOTPConfigDialog({
                  scan_code_original_Value: code, // 弹窗立刻扫码赋值
                  confirm: (new_conf) => {this.updateTokenConfig(JSON.parse(new_conf), true)}
                })
              })
              this.dialog_totp_config.open()
            }
          });
        })
        .accessibilityText($r('app.string.app_scan_code'))
      MenuItem({ content: $r('app.string.tab_token_add_key') })
        .onClick(() => {
          this.dialog_totp_config = new CustomDialogController({
            builder: TOTPConfigDialog({
              confirm: (new_conf) => {this.updateTokenConfig(JSON.parse(new_conf), true)}
            })
          })
          this.dialog_totp_config.open()
        })
        .accessibilityText($r('app.string.tab_token_add_key'))
      MenuItem({ content: $r('app.string.tab_token_add_uri') })
        .onClick(() => {
          this.dialog_uri_config = new CustomDialogController({
            builder: URIConfigDialog({
              confirm: (tokens) => {
                this.updateTokenConfigs(tokens);
              }
            })
          })
          this.dialog_uri_config.open()
        })
        .accessibilityText($r('app.string.tab_token_add_uri'))
      MenuItem({ content: $r('app.string.tab_token_add_forti_key') })
        .onClick(() => {
          this.dialog_forti_config = new CustomDialogController({
            builder: FortiConfigDialog({
              confirm: (new_conf) => {this.updateTokenConfig(JSON.parse(new_conf), true)}
            })
          })
          this.dialog_forti_config.open()
        })
        .accessibilityText($r('app.string.tab_token_add_forti_key'))
      MenuItem({ content: $r('app.string.tab_token_add_stream_key') })
        .onClick(() => {
          this.dialog_steam_config = new CustomDialogController({
            builder: SteamConfigDialog({
              confirm: (new_conf) => {this.updateTokenConfig(JSON.parse(new_conf), true)}
            })
          })
          this.dialog_steam_config.open()
        })
        .accessibilityText($r('app.string.tab_token_add_stream_key'))
    }
  }

}