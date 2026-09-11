import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { MaterialTheme } from '../components/MaterialTheme';
import { PageScaffold } from '../components/PageScaffold';

@Builder
function EmptyMultiSelectContent() {
}

/** 与排序页使用相同的全屏导航、标题栏材质和滚动联动。 */
@ComponentV2
export struct TokenMultiSelectPage {
  @Require @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Require @Param listScroller: Scroller = new Scroller();
  @Param busy: boolean = false;
  @Event onExitFullScreen: () => void = () => {};
  @BuilderParam content: CustomBuilder = EmptyMultiSelectContent;

  build() {
    HdsNavDestination() {
      PageScaffold() {
        if (this.content) {
          this.content()
        }
      }
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        originalStyle: {
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
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
        title: { mainTitle: $r('app.string.menu_token_multi_select') }
      }
    })
    .bindToScrollable([this.listScroller])
    .onBackPressed(() => this.busy)
    .onWillDisappear(() => this.onExitFullScreen())
  }
}
