/**
 * Steam 交易确认列表页（批准 / 拒绝）。
 *
 * 数据来源：steamcommunity.com/mobileconf/getlist（HMAC-SHA1 identity_secret 签名 +
 * steamLoginSecure Cookie）。列表项来自 Steam 返回的 `conf[]`。
 *
 * 入口：Steam 令牌右键菜单「交易确认」。
 */

import { MaterialTheme } from '../components/MaterialTheme';
import { AppWindowInfo, resourceText, showSnackBar, SnackBarNotifyType,
  steamAuthHasConfirmationCredentials, SteamAuth, TokenConfig } from 'common';
import { AppStorageV2 } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, HdsNavDestination,
  ScrollEffectType } from '@kit.UIDesignKit';
import { PageScaffold } from '../components/PageScaffold';
import { SteamConfirmation } from '../steam/SteamClient';
import { currentUnixSeconds, getSteamClient } from '../steam/SteamService';
import { describeSteamError, ensureSteamAccessToken } from '../utils/SteamActions';
import { ADD_TOKEN_BOTTOM_ACTION_INSET, ADD_TOKEN_PAGE_INSET } from '../components/AddTokenForm';

const TAG = 'SteamConfirmationsPage';

export class SteamConfirmationsPageParams {
  token: TokenConfig = new TokenConfig();

  constructor(token: TokenConfig) {
    this.token = token;
  }
}

@Entry
@ComponentV2
export struct SteamConfirmationsPage {
  @Param pageParams: SteamConfirmationsPageParams = new SteamConfirmationsPageParams(new TokenConfig());
  @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;

  @Local loading: boolean = true;
  @Local busy: boolean = false;
  @Local errorText: string = '';
  @Local confirmations: SteamConfirmation[] = [];
  /** 网络较慢时的提示：连接超过 8 秒才出现，避免用户以为卡死 */
  @Local slowHint: boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  private pageInfos: NavPathStack | null = null;
  private slowTimer: number = -1;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.stopSlowTimer();
  }

  private auth(): SteamAuth | undefined {
    return this.pageParams.token.SteamAuth;
  }

  /** 资源 → 当前语言文案（统一走 common/UiUtils.resourceText） */
  private textOf(res: Resource): string {
    return resourceText(this.getUIContext(), res);
  }

  private startSlowTimer(): void {
    this.stopSlowTimer();
    this.slowTimer = setTimeout(() => {
      if (this.loading) {
        this.slowHint = true;
      }
    }, 8000);
  }

  private stopSlowTimer(): void {
    if (this.slowTimer >= 0) {
      clearTimeout(this.slowTimer);
      this.slowTimer = -1;
    }
  }

  private async load(): Promise<void> {
    const auth: SteamAuth | undefined = this.auth();
    if (auth === undefined || !steamAuthHasConfirmationCredentials(auth)) {
      this.loading = false;
      this.slowHint = false;
      this.errorText = this.textOf($r('app.string.steam_error_no_credentials'));
      return;
    }
    this.loading = true;
    this.errorText = '';
    this.slowHint = false;
    this.startSlowTimer();
    try {
      const accessToken: string = await ensureSteamAccessToken(auth);
      const list: SteamConfirmation[] = await getSteamClient().getConfirmations(BigInt(auth.steamid),
        accessToken, auth.identitySecret, auth.deviceId, currentUnixSeconds());
      this.confirmations = list;
    } catch (error) {
      hilog.error(0, TAG, `load failed: ${describeSteamError(error as Object)}`);
      this.errorText = describeSteamError(error as Object);
    }
    this.stopSlowTimer();
    this.slowHint = false;
    this.loading = false;
  }

  private async respond(items: SteamConfirmation[], op: string): Promise<void> {
    const auth: SteamAuth | undefined = this.auth();
    if (auth === undefined || items.length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    try {
      const accessToken: string = await ensureSteamAccessToken(auth);
      await getSteamClient().respondConfirmations(BigInt(auth.steamid), accessToken,
        auth.identitySecret, auth.deviceId, items, op, currentUnixSeconds());
      showSnackBar($r('app.string.steam_confirmations_done'), SnackBarNotifyType.SUCCESS);
      await this.load();
    } catch (error) {
      hilog.error(0, TAG, `respond failed: ${describeSteamError(error as Object)}`);
      showSnackBar(describeSteamError(error as Object), SnackBarNotifyType.ERROR);
    }
    this.busy = false;
  }

  @Builder
  ConfirmationRow(item: SteamConfirmation) {
    Column({ space: 8 }) {
      Text(item.headline.length > 0 ? item.headline : item.typeName)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      if (item.summary.length > 0) {
        Text(item.summary.join('\n'))
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
      Row({ space: 10 }) {
        Button($r('app.string.steam_confirmations_approve'))
          .fontSize(14)
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => this.respond([item], 'allow'))
        Button($r('app.string.steam_confirmations_deny'))
          .fontSize(14)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .enabled(!this.busy)
          .onClick(() => this.respond([item], 'cancel'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.item_bg'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    HdsNavDestination() {
      HdsNavigation() {
        PageScaffold() {
          Column({ space: 12 }) {
            if (this.loading) {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  LoadingProgress().width(20).height(20)
                  Text($r('app.string.steam_confirmations_loading'))
                    .fontSize(14).fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')
                if (this.slowHint) {
                  Text($r('app.string.steam_confirmations_slow'))
                    .fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%')
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET, top: 12 })
            } else if (this.errorText.length > 0) {
              Column({ space: 12 }) {
                Text(this.errorText)
                  .fontSize(13).lineHeight(20)
                  .fontColor($r('sys.color.warning'))
                  .width('100%')
                Button($r('app.string.steam_confirmations_retry'))
                  .fontSize(14)
                  .backgroundColor($r('sys.color.comp_background_tertiary'))
                  .fontColor($r('sys.color.font_primary'))
                  .onClick(() => this.load())
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET, top: 12 })
            } else if (this.confirmations.length === 0) {
              Text($r('app.string.steam_confirmations_empty'))
                .fontSize(13)
                .fontColor($r('sys.color.font_tertiary'))
                .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET, top: 12 })
            }

            List({ space: 12 }) {
              ForEach(this.confirmations, (item: SteamConfirmation) => {
                ListItem() {
                  this.ConfirmationRow(item)
                }
                .padding({ left: ADD_TOKEN_PAGE_INSET, right: ADD_TOKEN_PAGE_INSET })
              }, (item: SteamConfirmation) => item.id)
              ListItem().height(this.window.AvoidBottomHeight + ADD_TOKEN_BOTTOM_ACTION_INSET)
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          }
          .width('100%')
          .height('100%')
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
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary'),
                subTitleColor: $r('sys.color.font_secondary')
              },
              backIconStyle: MaterialTheme.navigationIconStyle(),
              menuStyle: MaterialTheme.navigationIconStyle()
            }
          },
          scrollEffectStyle: MaterialTheme.navigationScrollStyle(),
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
            action: () => this.pageInfos?.pop()
          },
          title: { mainTitle: $r('app.string.steam_confirmations_title') },
          menu: {
            value: [{
              content: {
                label: $r('app.string.steam_confirmations_refresh'),
                icon: $r('sys.symbol.arrow_clockwise'),
                isEnabled: !this.loading,
                action: () => this.load()
              }
            }]
          }
        }
      })
    }
    .clip(false)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.window_background'))
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
  }
}
