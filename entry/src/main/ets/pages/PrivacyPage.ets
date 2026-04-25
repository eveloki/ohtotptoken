import { AppStorageV2 } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { CommonConstants } from '../utils/CommonConstants';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';

@Entry
@ComponentV2
export struct PrivacyPage {
  pageInfos: NavPathStack | null = null;
  @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Local webViewController: webview.WebviewController = new webview.WebviewController();
  @Local AppPrivacyManageInfoUrl: string = '';
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  aboutToAppear(): void {
     this.AppPrivacyManageInfoUrl = AppStorage.get("AppPrivacyManageInfoUrl") as string;
  }

  build() {
    HdsNavDestination() {
      Column() {
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
      .width(CommonConstants.FULL_PERCENT)
      .height(CommonConstants.FULL_PERCENT)
      .backgroundColor($r('app.color.window_background'))
    }
    .titleMode(HdsNavDestinationTitleMode.MODAL)
    .titleBar({
      enableComponentSafeArea: true, // Web内容会溢出到titlebar，临时启用组件安全区
      style: {
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.icon_primary')
            }
          },
          backgroundStyle: {
            maskExtraHeight: 0
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            maskExtraHeight: 0
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: {
          mainTitle: $r('app.string.privacy_statement'),
        },
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
  }
}
