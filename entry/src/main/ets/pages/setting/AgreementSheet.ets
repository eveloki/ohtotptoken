import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { bundleManager,common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { throttle,startBrowsableAbility } from '../../utils/UiUtils';

@Preview
@ComponentV2
export struct AgreementSheet {
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  build() {
    List({ space: 10 }) {
      ListItem() {
        SettingItem({ title: "" }) {
          SubItemButton({ symbol: $r("sys.symbol.person_shield"), text: $r('app.string.privacy_statement') })
            .onClick(throttle((event) => {
                router.pushUrl({ url: 'pages/PrivacyPage' });
            }, 1000))

          SubItemDivider()

          SubItemButton({
            symbol: $r("sys.symbol.doc_plaintext_and_pencil"),
            text: $r('app.string.user_agreement')
          })
            .onClick(throttle((event) => {
              router.pushUrl({ url: 'pages/AgreementPage' });
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
  }
}
