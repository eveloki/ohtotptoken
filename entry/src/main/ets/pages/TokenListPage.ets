import { TokenItem } from "../components/TokenItem";
import { FortiConfigDialog } from "../dialogs/FortiConfigDialog";
import { TOTPConfigDialog } from "../dialogs/OTPConfigDialog";
import { QRCodeDialog } from "../dialogs/QRCodeDialog";
import { SteamConfigDialog } from "../dialogs/SteamConfigDialog";
import { AppPreference, SettingValue, TokenPreference, EVENT_NAMES, PREF_KEYS } from "../utils/AppPreference";
import { otpType, TokenConfig } from "../utils/TokenConfig";
import { TokenStore } from "../utils/TokenStore";
import { convertToken2URI } from "../utils/TokenUtils";
import { AppStorageV2, curves, window } from "@kit.ArkUI";
import { AppWindowInfo } from "../entryability/EntryAbility";
import { CommonConstants } from "../utils/CommonConstants";
import { GenericDataSource } from "../utils/GenericDataSource";

let tkStore = TokenStore.getInstance();

@Preview
@ComponentV2
export struct TokenListPage {
  @Require @Param Tokens: TokenConfig[] = [];
  @Require @Param appBottomAvoidHeight: number = 0;
  @Require @Param appTopAvoidHeight: number = 0;
  @Require @Param appWindowSize: window.Size = { width: 0, height: 0 };
  @Require @Param TabBarVisible: boolean = true;
  @Param listScroller: Scroller = new Scroller();
  @Event updateTokenConfig: (conf: TokenConfig, toast: boolean) => void = () => {};
  @Event updateTokenConfigs: (tokens: Array<TokenConfig>) => void = () => {};

  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  @Local token_copy_guide_popup: boolean = false;

  @Local dataSource: GenericDataSource<TokenConfig> = new GenericDataSource([]);

  @Monitor("Tokens")
  onTokensChange(monitor: IMonitor): void {
    this.dataSource.updateData(monitor.value()?.now as TokenConfig[]);
  }

  @Local token_list_search_result: TokenConfig[] = [];
  @Local token_list_search_visible: boolean = false;
  @Local token_list_search_enable: boolean = false;
  @Local token_list_search_str: string = '';
  @Local id_list: string[] = ['search_bar', 'search_blur_anchor'];

  private dialog_totp_config?: CustomDialogController;
  private dialog_forti_config?: CustomDialogController;
  private dialog_steam_config?: CustomDialogController;
  private dialog_qrcode?: CustomDialogController;

  async filterCurrentTokens(filter_word: string): Promise<void> {
    if (filter_word.length === 0) {
      this.token_list_search_enable = false;
      this.dataSource.updateData(this.Tokens);
      return;
    }
    this.token_list_search_enable = true;
    const lower_filter_word = filter_word.toLowerCase();
    const filtered = this.Tokens.filter((token) => {
      return token.TokenIssuer.toLowerCase().indexOf(lower_filter_word) >= 0 || token.TokenName.toLowerCase().indexOf(lower_filter_word) >= 0
    });
    this.token_list_search_result = filtered;
    this.dataSource.updateData(filtered);
  }

  aboutToAppear(): void {
    this.dataSource = new GenericDataSource(this.Tokens);
    // 如果已经点击了我知道了则永远不提示了
    if (AppPreference.getPreference(PREF_KEYS.SHOW_GUIDE_TIPS) as boolean) {
      this.token_copy_guide_popup = true;
    }
    this.getUIContext().getHostContext()?.eventHub.on(EVENT_NAMES.TOGGLE_TOKEN_SEARCH, () => { this.toggleTokenSearchByTitleBar() });
  }

  private toggleTokenSearchByTitleBar(): void {
    const nextVisible = !this.token_list_search_visible;
    this.window.uiContext?.animateTo({ duration: 250, curve: curves.springMotion() }, () => {
      this.token_list_search_visible = nextVisible;
      if (!this.token_list_search_visible) {
        this.token_list_search_str = '';
        this.token_list_search_enable = false;
      }
    })
    if (nextVisible) {
      setTimeout(() => {
        focusControl.requestFocus(this.id_list[0])
      }, 180)
    } else {
      setTimeout(() => {
        focusControl.requestFocus(this.id_list[1])
      }, 100)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Button('')
        .id(this.id_list[1])
        .focusable(true)
        .width(1)
        .height(1)
        .opacity(0)
        .position({ x: 0, y: 0 })
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
        List({ space: this.token_preference.app_appearance_item_space, initialIndex: 0, scroller: this.listScroller }) {
          ListItemGroup() {
            ListItem() {
              Column() {
                Row()
                  .height(this.TabBarVisible ? CommonConstants.AVOID_TOP_BASE_HEIGHT + this.appTopAvoidHeight : this.appTopAvoidHeight)
                  .width('100%')
                
                Stack({ alignContent: Alignment.End }) {
                  TextInput({
                    placeholder: $r('app.string.token_search_placeholder'),
                    text: this.token_list_search_str
                  })
                    .id(this.id_list[0])
                    .onChange((value) => {
                      this.token_list_search_str = value;
                      this.filterCurrentTokens(this.token_list_search_str);
                    })
                    .onSubmit(() => {
                      this.filterCurrentTokens(this.token_list_search_str);
                    })
                  SymbolGlyph($r('sys.symbol.xmark'))
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor([$r('app.color.item_fg')])
                    .padding({ right: 10 })
                    .onClick(() => {
                      this.toggleTokenSearchByTitleBar();
                    })
                }
                .padding({ left: 10, right: 10, top: this.token_list_search_visible || this.token_list_search_enable ? 10 : 0 })
                .width('100%')
                .height(this.token_list_search_visible || this.token_list_search_enable ? 56 : 0)
                .opacity(this.token_list_search_visible || this.token_list_search_enable ? 1 : 0)
                .translate({
                  x: 0,
                  y: this.token_list_search_visible || this.token_list_search_enable ? 0 : -12
                })
                .clip(true)
              }
            }
          }

          LazyForEach(this.dataSource, (token: TokenConfig) => {
            ListItem() {
              TokenItem({
                Config: token,
                Update: async (conf_new) => {
                  this.updateTokenConfig(conf_new, false);
                }
              })
                .bindPopup(this.token_copy_guide_popup && token.TokenUUID === this.dataSource.getData(0)?.TokenUUID, {
                  placement: Placement.Left,
                  message: this.getUIContext().getHostContext()?.resourceManager
                    .getStringSync($r('app.string.token_copy_guide_popup').id),
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.token_copy_guide_popup = false
                    }
                  },
                  primaryButton: {
                    value: this.getUIContext().getHostContext()?.resourceManager
                      .getStringSync($r('app.string.token_copy_guide_popup_Confirm').id),
                    action: () => {
                      if (AppPreference.getPreference(PREF_KEYS.SHOW_GUIDE_TIPS) as boolean) {
                        AppPreference.setPreference(PREF_KEYS.SHOW_GUIDE_TIPS, false)
                      }
                      this.token_copy_guide_popup = false;
                    }
                  }
                })

            }
            .padding({ left: 10, right: 10 })
            .swipeAction({
              end: {
                builder: () => {
                  this.TokenItemSwipeEnd(token)
                },
              }
            })
          }, (item: TokenConfig) => {
            return item.TokenUUID
          })
            .onMove((from, to) => {
              if (!this.token_list_search_enable) {
                // wait 500ms for animation done
                setTimeout(() => tkStore.updateTokenRank(from, to), 500);
              }
            })

          ListItem() {
            Row()
              .height(this.TabBarVisible ? (80 + this.appBottomAvoidHeight) : (20 + this.appBottomAvoidHeight))
              .width('100%')
          }
          .selectable(false)
        }
        .alignListItem(ListItemAlign.Center)
        .lanes(1)
        .constraintSize({ maxWidth: this.token_preference.app_appearance_item_max_width })
        .layoutWeight(1)
        .width('100%')
        .height('100%')
        .chainAnimation(true)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .alignItems(HorizontalAlign.Center)
    }
  }

  showQRCodeDialog(conf: TokenConfig): void {
    this.dialog_qrcode = new CustomDialogController({
      builder: QRCodeDialog({
        content: convertToken2URI(conf),
        winSize: this.appWindowSize
      })
    });
    this.dialog_qrcode.open();
  }

  @Builder
  TokenItemSwipeEnd(conf: TokenConfig) {
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
        this.showQRCodeDialog(conf);
      })

      if (this.TabBarVisible) {
        Button({ type: ButtonType.Circle }) {
          Text() {
            SymbolSpan($r('sys.symbol.square_and_pencil_fill'))
              .fontSize(30)
              .fontWeight(FontWeight.Medium)
              .fontColor([Color.White])
          }
        }
        .backgroundColor(Color.Gray)
        .padding(10)
        .onClick(() => {
          if (conf.TokenType === otpType.TOTP || conf.TokenType === otpType.HOTP ||
            conf.TokenType === undefined) { // default
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

      Button({ type: ButtonType.Circle }) {
        Text() {
          SymbolSpan($r('sys.symbol.trash_fill'))
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
    }
    .margin({ left: 10 })
  }
}
