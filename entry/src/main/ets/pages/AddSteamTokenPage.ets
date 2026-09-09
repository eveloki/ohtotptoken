import { MaterialTheme } from '../components/MaterialTheme';
import { TokenGroupSelect } from '../components/TokenGroupSelect';
import { AppWindowInfo, EVENT_NAMES, maFile, otpType, readFileContent, ROUTE_NAMES, ScanBarCode,
  showSelectFilePicker, showSnackBar, SnackBarNotifyType, steamAuthCanRevoke,
  steamAuthHasConfirmationCredentials, SteamAuth, TokenConfig, TokenStore } from 'common';
import { AppStorageV2 } from '@kit.ArkUI';
import { JSON, url } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';

import { AddTokenActionButton, AddTokenHeader, AddTokenPageParams, ADD_TOKEN_BOTTOM_ACTION_INSET, ADD_TOKEN_PAGE_INSET,
  ADD_TOKEN_SECTION_PADDING, ADD_TOKEN_SECTION_RADIUS,
  AddTokenSectionTitle, AddTokenTextField } from '../components/AddTokenForm';
import { PageScaffold } from '../components/PageScaffold';
import { SteamLoginFlow } from '../components/SteamLoginFlow';
import { steamApproveQrLogin, steamConfirmRevoke } from '../utils/SteamActions';
import { WebPageParams } from './WebPage';
import { IconPickerPageParams } from './IconPickerPage';
import { ResponsiveTokenEditStore, TokenSwitchPerf, TokenSwitchTrace } from '../utils/TokenSwitchPerf';

let tkStore = TokenStore.getInstance();

@Entry
@Preview
@ComponentV2
export struct AddSteamTokenPage {
  @Require @Param saveToken: (conf: TokenConfig) => Promise<boolean> = async () => false;
  @Require @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Param pageParams: AddTokenPageParams = new AddTokenPageParams();
  @Event onExitFullScreen: () => void = () => {};
  @Event onBackToPlaceholder: () => void = () => {};

  @Local secret: string = '';
  @Local issuer: string = 'Steam';
  @Local accountName: string = '';
  @Local iconPath: string = '';
  @Local groupId: string = '';
  @Local isSaving: boolean = false;
  /** 是否处于「登录 Steam 迁移」内嵌步骤 */
  @Local showLoginFlow: boolean = false;
  /** 已绑定 Steam 账号时展示账户状态 + 功能入口（@Local 保证登录完成后能重绘） */
  @Local hasSteamAuth: boolean = false;
  @Local canConfirm: boolean = false;
  @Local canRevoke: boolean = false;
  @Local boundAccount: string = '';
  @Local boundSteamId: string = '';
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  private pageInfos: NavPathStack | null = null;
  private scroller: Scroller = new Scroller();
  private activeEditConfig?: TokenConfig = undefined;
  private appCtx: common.UIAbilityContext = AppStorage.get('appContext') as common.UIAbilityContext;
  private onResponsiveTokenSelectedHandler: (config: TokenConfig, trace: TokenSwitchTrace) => void = () => {};

  private steamMaFile: maFile | undefined = undefined;
  /** 登录/迁移得到的 Steam 授权数据（含 ASSET 侧凭证） */
  private steamAuth: SteamAuth | undefined = undefined;

  private applyEditConfig(editConfig: TokenConfig): void {
    this.activeEditConfig = editConfig;
    this.secret = editConfig.TokenSecret;
    this.issuer = editConfig.TokenIssuer;
    this.accountName = editConfig.TokenName;
    this.iconPath = editConfig.TokenIconPath ?? '';
    this.groupId = editConfig.TokenGroupId ?? '';
    this.steamMaFile = editConfig.SteamMaFile;
    this.steamAuth = editConfig.SteamAuth;
    this.refreshSteamStatus();
  }

  /** 从 steamAuth 推导绑定状态与可用能力 */
  private refreshSteamStatus(): void {
    const auth: SteamAuth | undefined = this.steamAuth;
    this.hasSteamAuth = auth !== undefined;
    this.canConfirm = steamAuthHasConfirmationCredentials(auth);
    this.canRevoke = steamAuthCanRevoke(auth);
    this.boundAccount = auth === undefined ? '' : (auth.accountName ?? '');
    this.boundSteamId = auth === undefined ? '' : (auth.steamid ?? '');
  }

  /** 用当前表单内容构造令牌配置：右键菜单同款动作可直接复用 */
  private currentConfig(): TokenConfig {
    const conf = new TokenConfig(this.secret.trim(), otpType.Steam, this.issuer.trim(), this.accountName.trim(),
      'SHA1', 30, 10, 0, this.activeEditConfig?.RankScore ?? 0);
    if (this.activeEditConfig !== undefined) {
      conf.TokenUUID = this.activeEditConfig.TokenUUID;
    }
    conf.TokenIconPath = this.iconPath;
    conf.TokenGroupId = this.groupId;
    conf.SteamAuth = this.steamAuth;
    return conf;
  }

  aboutToAppear(): void {
    const responsiveStore = ResponsiveTokenEditStore.getInstance();
    const switchTrace = this.pageParams.responsiveEdit ? responsiveStore.currentTrace() : this.pageParams.switchTrace;
    TokenSwitchPerf.mark(switchTrace, 'aboutToAppear');
    this.onResponsiveTokenSelectedHandler = (config: TokenConfig, trace: TokenSwitchTrace): void => {
      this.applyEditConfig(config);
      TokenSwitchPerf.reusedReady(trace, this.getUIContext());
    };
    if (this.pageParams.responsiveEdit) {
      this.appCtx.eventHub?.on(EVENT_NAMES.RESPONSIVE_TOKEN_SELECTION_CHANGED,
        this.onResponsiveTokenSelectedHandler);
    }
    const editConfig = this.pageParams.responsiveEdit ?
      (responsiveStore.currentConfig() ?? this.pageParams.editConfig) : this.pageParams.editConfig;
    if (editConfig !== undefined) {
      this.applyEditConfig(editConfig);
    }
  }

  aboutToDisappear(): void {
    if (this.pageParams.responsiveEdit) {
      this.appCtx.eventHub?.off(EVENT_NAMES.RESPONSIVE_TOKEN_SELECTION_CHANGED,
        this.onResponsiveTokenSelectedHandler);
    }
  }

  private openIconPicker(): void {
    this.pageInfos?.pushPathByName(ROUTE_NAMES.IconPickerPage,
      new IconPickerPageParams(this.issuer, this.iconPath, (path: string) => this.iconPath = path));
  }

  private scanCode(): void {
    ScanBarCode().then((code: string) => this.applyOtpAuthUri(code)).catch((err: BusinessError) => {
      if (err.code !== 1000500002) {
        showSnackBar($r('app.string.toast_scan_failed'), SnackBarNotifyType.ERROR);
      }
    });
  }

  private importMaFile(): void {
    showSelectFilePicker(1, ['maFile|.mafile']).then((uris: string[]) => {
      if (uris.length === 0) return;
      return readFileContent(uris[0]).then((content: string) => {
        this.steamMaFile = JSON.parse(content) as maFile;
        this.applyOtpAuthUri(this.steamMaFile?.uri ?? '');
      });
    }).catch((error: BusinessError) => {
      hilog.error(error.code, 'AddSteamTokenPage', `maFile import failed: ${error.message}`);
      showSnackBar($r('app.string.add_steam_import_failed'), SnackBarNotifyType.ERROR);
    });
  }

  private applyOtpAuthUri(uriValue: string): void {
    let otpUrl: url.URL;
    try {
      otpUrl = url.URL.parseURL(uriValue);
    } catch (error) {
      hilog.error(0, 'AddSteamTokenPage', `Invalid OTPAuth URL: ${JSON.stringify(error)}`);
      showSnackBar($r('app.string.toast_scan_failed'), SnackBarNotifyType.ERROR);
      return;
    }
    if (otpUrl.protocol !== 'otpauth:' || otpUrl.host.toLowerCase() !== 'totp') {
      showSnackBar($r('app.string.toast_scan_failed'), SnackBarNotifyType.ERROR);
      return;
    }

    const label = decodeURIComponent(otpUrl.pathname.replace(/^\//, ''));
    const separator = label.indexOf(':');
    if (separator >= 0) {
      this.issuer = label.slice(0, separator).trim() || 'Steam';
      this.accountName = label.slice(separator + 1).trim();
    } else if (label !== '') {
      this.accountName = label;
    }
    const params = new url.URLParams(otpUrl.search);
    this.secret = params.get('secret') ?? this.secret;
    this.issuer = params.get('issuer') ?? this.issuer;
  }

  private canSave(): boolean {
    return this.secret.trim() !== '' && this.issuer.trim() !== '' && this.accountName.trim() !== '' && !this.isSaving;
  }

  private async submit(): Promise<void> {
    if (!this.canSave()) return;
    this.isSaving = true;
    const conf: TokenConfig = this.currentConfig();
    conf.SteamMaFile = this.steamMaFile;
    const ok = await this.saveToken(conf);
    this.isSaving = false;
    if (ok && !(this.window.AllowSplit && this.pageParams.editConfig !== undefined)) {
      this.pageInfos?.pop();
    }
  }

  /** 登录/迁移流程完成：用返回的配置填充表单并直接保存 */
  private async onLoginCompleted(conf: TokenConfig): Promise<void> {
    this.secret = conf.TokenSecret;
    this.issuer = conf.TokenIssuer;
    this.accountName = conf.TokenName;
    this.steamAuth = conf.SteamAuth;
    this.steamMaFile = undefined;
    this.refreshSteamStatus();
    await this.submit();
  }

  /** 交易确认列表（与令牌右键菜单走同一个事件，由 Index 打开全屏页） */
  private openConfirmations(): void {
    this.appCtx.eventHub?.emit(EVENT_NAMES.OPEN_STEAM_CONFIRMATIONS, this.currentConfig());
  }

  /** 扫码登录：扫描网页登录二维码后向 Steam 确认 */
  private approveQrLogin(): void {
    steamApproveQrLogin(this.currentConfig());
  }

  /** 撤销验证器：成功后本地令牌已失效，直接删除并退出编辑页 */
  private revokeAuthenticator(): void {
    const conf: TokenConfig = this.currentConfig();
    steamConfirmRevoke(this.getUIContext(), conf, () => {
      tkStore.deleteToken(conf.TokenUUID);
      this.navigateBack();
    });
  }

  @Builder
  InfoRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .fontSize(13).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
      Text(value)
        .fontSize(13).fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End).layoutWeight(2)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  CapabilityRow(label: ResourceStr, available: boolean) {
    Row() {
      Text(label)
        .fontSize(13).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
      Text(available ? $r('app.string.steam_status_available') : $r('app.string.steam_status_unavailable'))
        .fontSize(13)
        .fontColor(available ? $r('sys.color.font_primary') : $r('sys.color.warning'))
        .textAlign(TextAlign.End).layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SteamAccountPanel() {
    Column({ space: 12 }) {
      AddTokenSectionTitle({ text: $r('app.string.steam_account_section') })
      Column({ space: 10 }) {
        this.InfoRow($r('app.string.steam_login_account'),
          this.boundAccount.length > 0 ? this.boundAccount : this.accountName)
        this.InfoRow($r('app.string.steam_account_steamid'),
          this.boundSteamId.length > 0 ? this.boundSteamId : '—')
        Divider().color($r('sys.color.comp_divider')).strokeWidth(0.5)
        this.CapabilityRow($r('app.string.steam_account_confirm_cap'), this.canConfirm)
        this.CapabilityRow($r('app.string.steam_account_revoke_cap'), this.canRevoke)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(ADD_TOKEN_SECTION_PADDING)
      .borderRadius(ADD_TOKEN_SECTION_RADIUS)
      .backgroundColor($r('app.color.item_bg'))

      if (!this.canConfirm) {
        Text($r('app.string.steam_account_incomplete_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
      }

      Row({ space: 10 }) {
        if (this.canConfirm) {
          Button($r('app.string.steam_menu_confirmations'))
            .fontSize(14).height(44).layoutWeight(1)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .onClick(() => this.openConfirmations())
          Button($r('app.string.steam_menu_qr_login'))
            .fontSize(14).height(44).layoutWeight(1)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .onClick(() => this.approveQrLogin())
        }
      }
      .width('100%')

      if (this.canRevoke) {
        Button($r('app.string.steam_menu_revoke'))
          .fontSize(14).height(44).width('100%')
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .fontColor(Color.Red)
          .onClick(() => this.revokeAuthenticator())
      }

      Text($r('app.string.steam_action_relogin'))
        .fontSize(14)
        .fontColor($r('sys.color.font_emphasize'))
        .decoration({ type: TextDecorationType.Underline, color: $r('sys.color.font_emphasize') })
        .width('100%').textAlign(TextAlign.Center)
        .onClick(() => this.showLoginFlow = true)
      Text($r('app.string.steam_relogin_warning'))
        .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 应用内打开 Steam 网页（用于引导绑定手机号） */
  private openSteamWebPage(url: string): void {
    this.pageInfos?.pushPathByName(ROUTE_NAMES.WebPage,
      new WebPageParams(url, $r('app.string.steam_bind_phone_page_title')));
  }

  private navigateBack(): void {
    if (this.window.AllowSplit && this.pageParams.editConfig !== undefined) {
      this.onBackToPlaceholder();
      return;
    }
    this.pageInfos?.pop();
  }

  build() {
    HdsNavDestination() {
      HdsNavigation() {
        PageScaffold() {
        Column() {
          List({ space: 12, scroller: this.scroller }) {
            ListItem() {
              AddTokenHeader({
                issuer: this.issuer,
                iconPath: this.iconPath,
                onIconClick: () => this.openIconPicker()
              })
            }
            .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET, top: 12 })

            ListItem() {
              if (this.showLoginFlow) {
                SteamLoginFlow({
                  rank: this.activeEditConfig?.RankScore ?? 0,
                  initialAccountName: this.boundAccount.length > 0 ? this.boundAccount : this.accountName,
                  onCancel: () => this.showLoginFlow = false,
                  onCompleted: (conf: TokenConfig) => this.onLoginCompleted(conf),
                  onOpenUrl: (url: string) => this.openSteamWebPage(url)
                })
              } else if (this.hasSteamAuth) {
                // 已绑定：展示账户状态 + 交易确认/扫码登录/撤销等全部功能
                this.SteamAccountPanel()
              } else {
                AddTokenActionButton({
                  text: $r('app.string.steam_login_entry'),
                  action: () => this.showLoginFlow = true
                })
              }
            }
            .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET })

            if (!this.showLoginFlow) {
              if (!this.hasSteamAuth) {
                ListItem() {
                  Row() {
                    AddTokenActionButton({
                      text: $r('app.string.dialog_cfg_steam_from_mafile'),
                      action: () => this.importMaFile()
                    })
                    .layoutWeight(1)
                  }
                  .width('100%')
                }
                .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET })
              }

              ListItem() { AddTokenSectionTitle({ text: $r('app.string.add_token_account_section') }) }
                .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET, top: 8 })

              ListItem() {
                Column({ space: 14 }) {
                  AddTokenTextField({
                    label: $r('app.string.dialog_cfg_tk_secret'),
                    value: this.secret,
                    inputType: InputType.Password,
                    onChange: (value: string) => this.secret = value
                  })
                  Divider().color($r('sys.color.comp_divider')).strokeWidth(0.5)
                  AddTokenTextField({
                    label: $r('app.string.dialog_cfg_tk_issuer'),
                    value: this.issuer,
                    onChange: (value: string) => this.issuer = value
                  })
                  Divider().color($r('sys.color.comp_divider')).strokeWidth(0.5)
                  AddTokenTextField({
                    label: $r('app.string.dialog_cfg_tk_name'),
                    value: this.accountName,
                    onChange: (value: string) => this.accountName = value
                  })
                  Divider().color($r('sys.color.comp_divider')).strokeWidth(0.5)
                  TokenGroupSelect({ groupId: this.groupId, onChange: (id: string) => this.groupId = id })
                }
                .padding(ADD_TOKEN_SECTION_PADDING).width('100%')
                .borderRadius(ADD_TOKEN_SECTION_RADIUS)
                .backgroundColor($r('app.color.item_bg'))
              }
              .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET })
            }
            ListItem().height(this.window.AvoidBottomHeight + 16)
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .clip(false)

          if (!this.showLoginFlow) {
            AddTokenActionButton({
              text: this.isSaving ? $r('app.string.add_token_saving') : $r('app.string.add_token_save'),
              loading: this.isSaving,
              buttonEnabled: this.canSave(),
              action: () => this.submit()
            })
            .width('100%')
            .padding({
              left: ADD_TOKEN_PAGE_INSET,
              right: ADD_TOKEN_PAGE_INSET,
              top: 10,
              bottom: ADD_TOKEN_BOTTOM_ACTION_INSET
            })
          }
        }
        .width('100%').height('100%')
      }
    }
    .backgroundColor($r('app.color.window_background'))
    .mode(NavigationMode.Stack)
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        originalStyle: {
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary'), subTitleColor: $r('sys.color.font_secondary') },
            backIconStyle: { iconColor: $r('sys.color.icon_primary') },
            menuStyle: { iconColor: $r('sys.color.icon_primary') }
          }
        },
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: this.scrollEffectType },
        systemMaterialEffect: {
          materialType: MaterialTheme.hdsMaterialType(),
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        backIcon: {
          label: $r('app.string.dialog_btn_cancel'),
          icon: $r('sys.symbol.chevron_left'),
          action: () => this.navigateBack()
        },
        title: { mainTitle: this.pageParams.editConfig === undefined ?
          $r('app.string.tab_token_add_stream_key') : $r('app.string.edit_token_title') },
        menu: {
          // 已绑定的令牌不允许再扫码替换密钥：会与 Steam 侧的验证器密钥不一致
          value: (this.window.IsPc || this.hasSteamAuth) ? [] : [{
            content: {
              label: $r('app.string.add_token_scan'),
              icon: $r('sys.symbol.qrcode'),
              isEnabled: true,
              action: () => this.scanCode()
            }
          }]
        }
      }
    })
    .bindToScrollable([this.scroller])
    }
    .clip(false)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.window_background'))
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
      const switchTrace = this.pageParams.responsiveEdit ?
        ResponsiveTokenEditStore.getInstance().currentTrace() : this.pageParams.switchTrace;
      TokenSwitchPerf.routeReady(switchTrace, this.getUIContext());
    })
    .onShown(() => TokenSwitchPerf.mark(this.pageParams.responsiveEdit ?
      ResponsiveTokenEditStore.getInstance().currentTrace() : this.pageParams.switchTrace, 'shown'))
    .onWillDisappear(() => {
      TokenSwitchPerf.mark(this.pageParams.switchTrace, 'willDisappear');
      this.onExitFullScreen();
    })
    .onBackPressed(() => {
      if (this.window.AllowSplit && this.pageParams.editConfig !== undefined) {
        this.onBackToPlaceholder();
        return true;
      }
      return false;
    })
  }
}
