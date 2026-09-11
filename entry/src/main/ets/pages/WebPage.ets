import { MaterialTheme } from '../components/MaterialTheme';
import { webview } from '@kit.ArkWeb';

import { CommonConstants } from 'common';
import { PageScaffold } from '../components/PageScaffold';
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, HdsNavDestination,
  HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';

@ObservedV2
export class WebPageParams {
  url: string = '';
  title: ResourceStr = '';

  constructor(url: string, title: ResourceStr) {
    this.url = url;
    this.title = title;
  }
}

/**
 * 应用内网页。
 *
 * 同一组件被两种方式使用，安全区处理不能一概而论：
 * - **全屏路由**（`fullScreen = true`，由 AppShell 的路由栈打开，如「去 Steam 绑定手机号」）：
 *   页面占满整屏，需要自己避让状态栏与底部导航条，结构与其它全屏页保持一致
 *   （`HdsNavigation` + MINI 标题栏 + `avoidLayoutSafeArea`）；
 * - **半模态内嵌**（`fullScreen = false`，设置里的协议/反馈页）：安全区由半模态容器负责，
 *   这里再加内边距会造成双重留白，保持原有 MODAL 标题栏样式。
 */
@Entry
@ComponentV2
export struct WebPage {
  pageInfos: NavPathStack | null = null;
  @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Param pageParams: WebPageParams = new WebPageParams('', '');
  /** 是否以全屏路由方式打开（见组件注释） */
  @Param fullScreen: boolean = false;
  @Local webViewController: webview.WebviewController = new webview.WebviewController();

  @Builder
  WebContent() {
    Web({ controller: this.webViewController, src: this.pageParams.url })
      .darkMode(WebDarkMode.Auto)
      .domStorageAccess(true)
      .zoomAccess(true)
      .mixedMode(MixedMode.All)
      .cacheMode(CacheMode.Default)
      .javaScriptAccess(true)
      .width(CommonConstants.FULL_PERCENT)
      .height(CommonConstants.FULL_PERCENT)
  }

  /** 全屏路由：标题栏参与布局（内容从标题栏下方开始），底部避让导航条 */
  @Builder
  FullScreenLayout() {
    HdsNavDestination() {
      HdsNavigation() {
        PageScaffold({ avoidBottom: true }) {
          this.WebContent()
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
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: this.scrollEffectType
          },
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
          title: { mainTitle: this.pageParams.title }
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

  /** 半模态内嵌：沿用原有 MODAL 标题栏，安全区交给半模态容器 */
  @Builder
  EmbeddedLayout() {
    HdsNavDestination() {
      PageScaffold() {
        this.WebContent()
      }
    }
    .titleMode(HdsNavDestinationTitleMode.MODAL)
    .titleBar({
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
          },
        },
        scrollEffectStyle: MaterialTheme.navigationScrollStyle(),
        systemMaterialEffect: {
          materialType: MaterialTheme.hdsMaterialType(),
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: {
          mainTitle: this.pageParams.title,
        },
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
  }

  build() {
    if (this.fullScreen) {
      this.FullScreenLayout()
    } else {
      this.EmbeddedLayout()
    }
  }
}
