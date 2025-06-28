import { systemDateTime } from '@kit.BasicServicesKit';
import { otpType, TokenConfig } from '../utils/TokenConfig';
import { convertToken2URI, copyText, generateOTP } from '../utils/TokenUtils';
import { TokenIcon } from './TokenIcon';
import { SteamUtils } from '../utils/SteamUtils';
import { AppPreference, TokenPreference } from '../utils/AppPreference';
import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
import { TOTPConfigDialog } from '../dialogs/OTPConfigDialog';
import { FortiConfigDialog } from '../dialogs/FortiConfigDialog';
import { SteamConfigDialog } from '../dialogs/SteamConfigDialog';
import { QRCodeDialog } from '../dialogs/QRCodeDialog';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { TokenStore } from '../utils/TokenStore';

let current_token_hide_map: Map<string, boolean> = new Map();
let tkStore = TokenStore.getInstance();

@Preview
@ComponentV2
export struct TokenItem {
  @Require @Param Config: TokenConfig = new TokenConfig();
  @Event Update: (conf: TokenConfig) => void = () => {};

  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  @Local TokenNumber: string = '000000';
  @Local TokenNumberNext: string = '000000';
  @Local TokenCounter: string = '0';
  @Local TokenLeftPeriod: number = 0;
  @Local btn_hotp_clicked: number = 0;
  @Local TokenHide: boolean = current_token_hide_map[this.Config.TokenUUID] ?? true;

  @Local menu_icon_trash: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.trash')).fontSize('22vp').fontColor([Color.Red]);
  @Local menu_icon_qrcode: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.qrcode')).fontSize('22vp');
  @Local menu_icon_edit: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')).fontSize('22vp');
  @Local menu_icon_copy: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.doc_text_on_doc_text')).fontSize('22vp');

  private dialog_totp_config?: CustomDialogController;
  private dialog_forti_config?: CustomDialogController;
  private dialog_steam_config?: CustomDialogController;
  private dialog_qrcode?: CustomDialogController;

  private token_steps: number = 0;
  private token_color_change_threshold = 5;
  private token_progress_color_normal: LinearGradient = new LinearGradient(
    [
      {color: $r('app.color.token_progress_normal_color_start'), offset: 0},
      {color: $r('app.color.token_progress_normal_color_end'), offset: 1},
    ])
  private token_progress_color_near_next: LinearGradient = new LinearGradient(
    [
      {color: $r('app.color.token_progress_next_color_start'), offset: 0},
      {color: $r('app.color.token_progress_next_color_end'), offset: 1},
    ])

  aboutToAppear(): void {
    getContext(this).eventHub.on('onTimestampChanged', (timestamp: number, force: boolean) => this.onTimestampChanged(timestamp, force));
    this.updateToken();
  }

  onTimestampChanged(timestamp: number, force: boolean): void {
    if (this.Config.TokenType !== otpType.HOTP) {
      this.token_steps = Math.floor(timestamp / this.Config.TokenPeriod);
      this.TokenLeftPeriod = this.Config.TokenPeriod - timestamp % this.Config.TokenPeriod;
      if (this.TokenLeftPeriod == this.Config.TokenPeriod || force) {
        this.updateTOTPToken();
      }
    }
  }

  updateToken() {
    if (this.Config === undefined) {
      return;
    }
    if (this.Config.TokenType == otpType.HOTP) {
      this.updateHOTPToken();
    } else {
      const timestamp = Math.floor(systemDateTime.getTime() / 1000);
      this.onTimestampChanged(timestamp, true);
    }
  }

  updateHOTPToken() {
    this.TokenCounter = this.Config.TokenCounter.toString();
    this.TokenNumber = generateOTP(this.Config, this.Config.TokenCounter).toString().padStart(this.Config.TokenDigits, '0');
    this.TokenNumberNext = generateOTP(this.Config, this.Config.TokenCounter + 1).toString().padStart(this.Config.TokenDigits, '0');
  }

  updateTOTPToken() {
    let int_code = generateOTP(this.Config, this.token_steps);
    let int_code_next = generateOTP(this.Config, this.token_steps + 1);
    if (this.Config.TokenType === otpType.Steam) {
      this.TokenNumber = SteamUtils.SteamTokenFromTOTP(int_code);
      this.TokenNumberNext = SteamUtils.SteamTokenFromTOTP(int_code_next);
    } else {
      this.TokenNumber = int_code.toString().padStart(this.Config.TokenDigits, '0');
      this.TokenNumberNext = int_code_next.toString().padStart(this.Config.TokenDigits, '0');
    }
  }

  build() {
    Row({ space: 10 }) {
      TokenIcon({ issuer: this.Config.TokenIssuer, icon_path: this.Config.TokenIconPath })
      Column() {
        Text(this.token_preference.app_appearance_swap_host_user_enable ? this.Config.TokenName : this.Config.TokenIssuer)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .maxLines(1)
          .fontSize(this.token_preference.app_appearance_issuer_font_size)
          .fontWeight(this.token_preference.app_appearance_issuer_font_weight)
          .fontColor($r('app.color.str_main'))
        Text(this.token_preference.app_appearance_swap_host_user_enable ? this.Config.TokenIssuer : this.Config.TokenName)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .maxLines(1)
          .fontSize(this.token_preference.app_appearance_user_name_font_size)
          .fontWeight(this.token_preference.app_appearance_user_name_font_weight)
          .fontColor($r('app.color.str_gray'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Blank()

      if (AppPreference.getPreference('app_debug_mode_on')) {
        Text(this.Config.RankScore.toString())
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .maxLines(1)
          .fontSize(30)
      }

      if (this.TokenHide && this.token_preference.app_safety_hide_token_enable) {
        Stack() {
          Text() {
            Span("●●●●")
          }
          .fontColor(Color.Gray)
          .fontSize(this.token_preference.app_appearance_token_font_size)
        }
        .onClick(() => {
          this.TokenHide = !this.TokenHide;
          current_token_hide_map[this.Config.TokenUUID] = false;
        })

      } else {
        Column() {
          Text(this.TokenNumber)
            .textAlign(TextAlign.End)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .maxLines(1)
            .fontColor(this.TokenLeftPeriod <= this.token_color_change_threshold && this.Config.TokenType !== otpType.HOTP ?
              this.token_preference.app_appearance_token_next_color :
              this.token_preference.app_appearance_token_color)
            .fontSize(this.token_preference.app_appearance_token_font_size)
            .fontWeight(this.token_preference.app_appearance_token_font_weight)
            .gesture(
              LongPressGesture()
                .onAction(() => {
                  copyText(this.TokenNumber, `token ${this.TokenNumber} `+ getContext(this).resourceManager.getStringSync($r('app.string.token_copied')).toString());
                })
            )
          if (this.Config.TokenType == otpType.HOTP) {
            Text(this.TokenCounter + (this.token_preference.app_appearance_show_next_token_enable ? ":" + this.TokenNumberNext : ""))
              .textAlign(TextAlign.End)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .maxLines(1)
              .fontColor($r('app.color.str_gray'))
              .fontSize(10)
          } else if (this.token_preference.app_appearance_show_next_token_enable) {
            Text(this.TokenNumberNext)
              .textAlign(TextAlign.End)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .maxLines(1)
              .fontColor($r('app.color.str_gray'))
              .fontSize(10)
          }
        }
        .onClick(() => {
          if (this.token_preference.app_safety_hide_token_enable) {
            this.TokenHide = !this.TokenHide;
            current_token_hide_map[this.Config.TokenUUID] = true;
          }
        })

        if (this.Config.TokenType == otpType.HOTP) {
          SymbolGlyph($r('sys.symbol.lock_filled_arrow_counterclockwise'))
            .fontColor([$r('app.color.token_number')])
            .fontSize(40)
            .fontWeight(FontWeight.Medium)
            .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP),
              this.btn_hotp_clicked)
            .onClick(() => {
              this.btn_hotp_clicked++;
              this.Config.TokenCounter++;
              this.Update(this.Config)
              this.updateHOTPToken();
            })
        } else {
          Stack() {
            Text(this.TokenLeftPeriod.toString())
            Progress({ value: this.TokenLeftPeriod, total: this.Config.TokenPeriod, type: ProgressType.Ring })
              .style({ strokeWidth: 8 })
              .width(40)
              .height(40)
              .color(this.TokenLeftPeriod <= this.token_color_change_threshold ?
                this.token_progress_color_near_next :
                this.token_progress_color_normal)
          }
        }
      }
    }
    .borderRadius(10)
    .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 10, offsetY: 10 })
    .padding(10)
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
    .height(this.token_preference.app_appearance_item_height)
    .backgroundColor($r("app.color.item_bg"))
    .bindContextMenu(this.TokenRightCtxMenu, ResponseType.RightClick, { enableArrow: true })
  }

  @Builder
  TokenRightCtxMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: this.menu_icon_copy, content: $r('app.string.token_right_menu_copy') })
        .onClick(() => {
          copyText(this.TokenNumber, `${this.TokenNumber} copied`);
        })
        .accessibilityText($r('app.string.token_right_menu_copy'))
      MenuItem({ symbolStartIcon: this.menu_icon_qrcode, content: $r('app.string.token_right_menu_show_qrcode') })
        .onClick(() => {
          this.dialog_qrcode = new CustomDialogController({
            builder: QRCodeDialog({
              content: convertToken2URI(this.Config),
              winSize: this.window.Size
            })
          });
          this.dialog_qrcode.open();
        })
        .accessibilityText($r('app.string.token_right_menu_show_qrcode'))
      MenuItem({ symbolStartIcon: this.menu_icon_edit, content: $r('app.string.token_right_menu_edit') })
        .onClick(() => {
          if (this.Config.TokenType === otpType.TOTP || this.Config.TokenType === otpType.HOTP ||
            this.Config.TokenType === undefined) { // default
            this.dialog_totp_config = new CustomDialogController({
              builder: TOTPConfigDialog({
                conf_json: JSON.stringify(this.Config),
                confirm: (new_conf) => {
                  this.Update(JSON.parse(new_conf))
                }
              })
            })
            this.dialog_totp_config.open()
          } else if (this.Config.TokenType === otpType.Forti) { // forti
            this.dialog_forti_config = new CustomDialogController({
              builder: FortiConfigDialog({
                conf_json: JSON.stringify(this.Config),
                confirm: (new_conf) => {
                  this.Update(JSON.parse(new_conf))
                }
              })
            })
            this.dialog_forti_config.open()
          } else if (this.Config.TokenType === otpType.Steam) { // steam
            this.dialog_steam_config = new CustomDialogController({
              builder: SteamConfigDialog({
                conf_json: JSON.stringify(this.Config),
                confirm: (new_conf) => {
                  this.Update(JSON.parse(new_conf))
                }
              })
            })
            this.dialog_steam_config.open()
          }
        })
        .accessibilityText($r('app.string.token_right_menu_edit'))
      MenuItem({ symbolStartIcon: this.menu_icon_trash, content: $r('app.string.token_right_menu_delete') })
        .onClick(() => {
          AlertDialog.show({
            message: $r('app.string.alert_remove_confirm_msg', this.Config.TokenName),
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
                tkStore.deleteToken(this.Config.TokenUUID);
              }
            }
          })

        })
        .contentFontColor(Color.Red)
        .accessibilityText($r('app.string.token_right_menu_delete'))
    }
  }
}
