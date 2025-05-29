import { AppStorageV2, router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { CommonConstants } from '../utils/CommonConstants';
import { TopNavigationView } from '../components/TopNavigationView';
import { AppWindowInfo } from '../entryability/EntryAbility';

@Entry
@ComponentV2
struct AgreementPage {
  @Local webViewController: webview.WebviewController = new webview.WebviewController();
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  build() {
    Column() {
      TopNavigationView({
        title: $r('app.string.user_agreement'),
        onBackClick: () => {
          router.back();
        }
      })
      Stack() {
        Web({ controller: this.webViewController, src: 'https://yylx.duan.red/user-agreement-zh-cn.html'})
          .darkMode(WebDarkMode.Auto)
          .domStorageAccess(true)
          .zoomAccess(true)
          .fileAccess(true)
          .mixedMode(MixedMode.All)
          .cacheMode(CacheMode.Default)
          .javaScriptAccess(true)
          .width(CommonConstants.FULL_PERCENT)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ top: this.window.AvoidTopHeight, bottom: this.window.AvoidBottomHeight })

  }
}