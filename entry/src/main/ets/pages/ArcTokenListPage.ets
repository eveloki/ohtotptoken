import { FortiConfigDialog } from "../dialogs/FortiConfigDialog";
import { TOTPConfigDialog } from "../dialogs/OTPConfigDialog";
import { QRCodeDialog } from "../dialogs/QRCodeDialog";
import { SteamConfigDialog } from "../dialogs/SteamConfigDialog";
import { AppPreference, TokenPreference } from "../utils/AppPreference";
import { otpType, TokenConfig } from "../utils/TokenConfig";
import { TokenStore } from "../utils/TokenStore";
import { convertToken2URI } from "../utils/TokenUtils";
import { AppStorageV2, ArcList, ArcListItem, ArcListAttribute, ArcListItemAttribute, curves, window,
  ArcButton,
  ArcButtonOptions,
  ArcButtonStyleMode,
  LengthMetrics,
  LengthUnit,
  promptAction} from "@kit.ArkUI";
import { AppWindowInfo } from "../entryability/EntryAbility";
import { ArcTokenItem } from "../components/ArcTokenItem";

let tkStore = TokenStore.getInstance();

@Preview
@ComponentV2
export struct ArcTokenListPage {
  @Require @Param Tokens: TokenConfig[] = [];
  @Require @Param appBottomAvoidHeight: number = 0;
  @Require @Param appTopAvoidHeight: number = 0;
  @Require @Param appWindowSize: window.Size = { width: 0, height: 0 };
  @Require @Param TabBarVisible: boolean = true;
  @Event updateTokenConfig: (conf: TokenConfig, toast: boolean) => void = () => {};
  @Event updateTokenConfigs: (tokens: Array<TokenConfig>) => void = () => {};

  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  @Local token_copy_guide_popup: boolean = false;

  @Local bottomOptions: ArcButtonOptions = new ArcButtonOptions({});
  @Local loading: boolean = false;

  private dialog_qrcode?: CustomDialogController;

  aboutToAppear(): void {
    this.bottomOptions = new ArcButtonOptions({
      label: 'Sync',
      styleMode: ArcButtonStyleMode.EMPHASIZED_LIGHT,
      fontSize: new LengthMetrics(15, LengthUnit.FP),
      shadowEnabled: true,
      onClick: () => {
        this.loading = true;

        TokenStore.getInstance().DataSync().then(() => {
          this.loading = false;
        });
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.Tokens.length === 0) {
        Column() {
          Text($r('app.string.app_wearable_guide_msg'))
            .textAlign(TextAlign.Center)
            .fontSize(20)
            .width('100%')
          if (this.loading) {
            LoadingProgress()
              .color(Color.White)
              .width(80).height(80)
          }
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)

        ArcButton({ options: this.bottomOptions })
      }
      ArcList({ initialIndex: 0 }) {
        ForEach(this.Tokens,
          (token: TokenConfig, index: number) => {
            ArcListItem() {
              ArcTokenItem({
                Config: token,
                Update: async (conf_new) => {
                  this.updateTokenConfig(conf_new, false);
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
          }, (item: TokenConfig) => {
            return JSON.stringify(item)
          })
      }
      .layoutWeight(1)
      .width('100%')
      .height('100%')
      .space(LengthMetrics.vp(10))
      .scrollBar(BarState.Off)
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
            content: convertToken2URI(conf),
            winSize: this.appWindowSize
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
  }
}