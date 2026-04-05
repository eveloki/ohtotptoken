import { AppStorageV2 } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { CommonConstants } from '../utils/CommonConstants';
import { TopNavigationView } from '../components/TopNavigationView';
import { AppWindowInfo } from '../entryability/EntryAbility';

@Entry
@ComponentV2
export struct PrivacyPage {
  pageInfos: NavPathStack | null = null;
  @Local webViewController: webview.WebviewController = new webview.WebviewController();
  @Local AppPrivacyManageInfoUrl: string = '';
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  aboutToAppear(): void {
     this.AppPrivacyManageInfoUrl = AppStorage.get("AppPrivacyManageInfoUrl") as string;
  }

  build() {
    NavDestination() {
    Column() {
      TopNavigationView({
        title: $r('app.string.privacy_statement'),
        onBackClick: () => {
          this.pageInfos?.pop('');
        }
      })
      Stack() {
        Web({ controller: this.webViewController, src: this.AppPrivacyManageInfoUrl})
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
      return true;
    });
  }
}