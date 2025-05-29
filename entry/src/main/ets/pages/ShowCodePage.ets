import { AppStorageV2, router } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { TokenConfig } from '../utils/TokenConfig';
import { AppWindowInfo } from '../entryability/EntryAbility';

@Entry
@ComponentV2
struct ShowCodePage {
  @Local TokenNumber: string = '000000';
  @Local TokenCounter: string = '0';
  @Local TokenLeftPeriod: number = 0;
  @Local btn_hotp_clicked: number = 0;
  @Local Config: TokenConfig = new TokenConfig();
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  build() {
    Column() {
      TopNavigationView({
        title: '',
        onBackClick: () => {
          router.back();
        }
      })
      RelativeContainer() {
        Text("Hallo World")
          .id('ShowCodePageHelloWorld')
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
          .alignRules({
            center: { anchor: '__container__', align: VerticalAlign.Center },
            middle: { anchor: '__container__', align: HorizontalAlign.Center }
          })
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ top: this.window.AvoidTopHeight, bottom: this.window.AvoidBottomHeight })
  }
}