import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { bundleManager,common } from '@kit.AbilityKit';
import { throttle,startBrowsableAbility } from '../../utils/UiUtils';
import { PrivacyPage } from '../PrivacyPage';
import { AgreementPage } from '../AgreementPage';
import { LengthMetrics } from '@kit.ArkUI';
import { ROUTE_NAMES } from '../../utils/AppPreference';

@Preview
@ComponentV2
export struct AgreementSheet {
  pageInfos: NavPathStack = new NavPathStack();
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === ROUTE_NAMES.PrivacyPage) {
      PrivacyPage()
    } else if (name === ROUTE_NAMES.AgreementPage) {
      AgreementPage()
    }
  }

  build() {
    Navigation(this.pageInfos) {
      Column() {
        Text($r('app.string.setting_agreement_statement'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .padding({ left: LengthMetrics.vp(24).value, right: LengthMetrics.vp(24).value, top: LengthMetrics.vp(16).value, bottom: LengthMetrics.vp(8).value })
          .width('100%')
        List({ space: 10 }) {
        ListItem() {
          SettingItem({ title: "" }) {
            SubItemButton({ symbol: $r("sys.symbol.person_shield"), text: $r('app.string.privacy_statement') })
              .onClick(throttle((event) => {
                  this.pageInfos.pushPathByName(ROUTE_NAMES.PrivacyPage, null);
              }, 1000))

            SubItemDivider()

            SubItemButton({
              symbol: $r("sys.symbol.doc_plaintext_and_pencil"),
              text: $r('app.string.user_agreement')
            })
              .onClick(throttle((event) => {
                this.pageInfos.pushPathByName(ROUTE_NAMES.AgreementPage, null);
              }, 1000))

            SubItemDivider()

            SubItemButton({ symbol: $r("sys.symbol.questionmark_circle"), text: $r('app.string.app_issue_feedback') })
              .onClick(throttle((event) => {
                startBrowsableAbility(this.appCtx,'https://github.com/SolidFaker/ohtotptoken/issues');
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
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.window_background'))
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.navDestinationBuilder)
  }
}
