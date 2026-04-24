import { AppStorageV2 } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { TokenConfig } from '../utils/TokenConfig';
import { AppWindowInfo } from '../entryability/EntryAbility';

@Entry
@ComponentV2
export struct ShowCodePage {
  pageInfos: NavPathStack | null = null;
  @Local TokenNumber: string = '000000';
  @Local TokenCounter: string = '0';
  @Local TokenLeftPeriod: number = 0;
  @Local btn_hotp_clicked: number = 0;
  @Local Config: TokenConfig = new TokenConfig();
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  build() {
    NavDestination() {
    Column() {
      TopNavigationView({
        title: '',
        onBackClick: () => {
          this.pageInfos?.pop('');
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
    .backgroundColor($r('app.color.window_background'))
    }
    .hideTitleBar(true, true)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
    .onBackPressed(() => {
      this.pageInfos?.pop('');
      return true;
    });
  }
}