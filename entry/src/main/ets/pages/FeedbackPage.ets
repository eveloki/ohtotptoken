import { webview } from '@kit.ArkWeb';
import { CommonConstants } from '../utils/CommonConstants';
import { TopNavigationView } from '../components/TopNavigationView';
import { EXTERNAL_URLS } from '../utils/AppPreference';

@Entry
@ComponentV2
export struct FeedbackPage {
  pageInfos: NavPathStack | null = null;
  @Local webViewController: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
    Column() {
      TopNavigationView({
        title: $r('app.string.feedback_survey'),
        onBackClick: () => {
          this.pageInfos?.pop('');
        }
      })
      Stack() {
        Web({ controller: this.webViewController, src: EXTERNAL_URLS.FEEDBACK_SURVEY })
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
    .padding({ top: 16 })
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
