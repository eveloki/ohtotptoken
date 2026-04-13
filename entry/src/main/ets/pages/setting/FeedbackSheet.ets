import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { common } from '@kit.AbilityKit';
import { throttle, startBrowsableAbility } from '../../utils/UiUtils';
import { ROUTE_NAMES, EXTERNAL_URLS } from '../../utils/AppPreference';
import { FeedbackPage } from '../FeedbackPage';
import { LengthMetrics } from '@kit.ArkUI';

@Preview
@ComponentV2
export struct FeedbackSheet {
  pageInfos: NavPathStack = new NavPathStack();
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === ROUTE_NAMES.FeedbackPage) {
      FeedbackPage()
    }
  }

  build() {
    Navigation(this.pageInfos) {
      Column() {
        Text($r('app.string.app_issue_feedback'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .padding({
            left: LengthMetrics.vp(24).value,
            right: LengthMetrics.vp(24).value,
            top: LengthMetrics.vp(16).value,
            bottom: LengthMetrics.vp(8).value
          })
          .width('100%')
        List({ space: 10 }) {
          ListItem() {
            SettingItem({ title: "" }) {
              SubItemButton({
                symbol: $r("sys.symbol.doc_plaintext"),
                text: $r('app.string.feedback_survey')
              })
                .onClick(throttle((event) => {
                  this.pageInfos.pushPathByName(ROUTE_NAMES.FeedbackPage, null);
                }, 1000))

              SubItemDivider()

              SubItemButton({
                symbol: $r("sys.symbol.person_2"),
                text: $r('app.string.feedback_qq_group')
              })
                .onClick(throttle((event) => {
                  startBrowsableAbility(this.appCtx, EXTERNAL_URLS.FEEDBACK_QQ_GROUP);
                }, 1000))

              SubItemDivider()

              SubItemButton({
                symbol: $r("sys.symbol.chevron_left_circle"),
                text: $r('app.string.feedback_github')
              })
                .onClick(throttle((event) => {
                  startBrowsableAbility(this.appCtx, EXTERNAL_URLS.FEEDBACK_GITHUB);
                }, 1000))
            }
          }
          .padding({ left: 10, right: 10 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
