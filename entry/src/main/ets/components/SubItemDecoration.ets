import { AppWindowInfo } from "../entryability/EntryAbility";
import { AppStorageV2 } from "@kit.ArkUI";

@Preview
@ComponentV2
export struct SubItemDecoration {
  @Require @Param onChange: (index: number, color: number) => void = () => {};
  @Require @Param title: string | Resource = '';
  @Param disable: boolean = false;
  @Param icon: Resource | undefined = undefined;
  @Param description: string  | Resource = '';
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local collapsed: boolean = true;

  build() {
    Column() {
      Row() {
        Column() {
          Row({ space: 10 }) {
            if (this.icon != undefined) {
              SymbolGlyph(this.icon)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor([$r('app.color.str_main')])
            }
            Text(this.title)
              .fontSize($r('sys.float.ohos_id_text_size_body1'))
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .fontWeight(FontWeight.Regular)
              .textAlign(TextAlign.Start)
              .layoutWeight(2)
          }
          .width('100%')
          if (this.description != '') {
            Text(this.description)
              .fontSize($r('sys.float.ohos_id_text_size_body2'))
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .fontWeight(FontWeight.Regular)
              .fontFamily('HarmonyHeiTi')
              .lineHeight(19)
              .width('100%')
          }
        }
        .width('80%')
        Blank()
        Row({ space: 10 }) {
          Blank()
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontColor([$r('sys.color.font_tertiary')])
            .fontSize(24)
            .align(Alignment.Center)
            .rotate(this.collapsed ? { angle: 0 } : { angle: 90 })
            .translate(this.collapsed ? {} : { x: -3 })
        }
        .layoutWeight(1)
        .onClick(() => {
          this.window.uiContext?.animateTo({ duration: 200, curve: Curve.Sharp }, () => {
            this.collapsed = !this.collapsed;
          })
        })

      }
      .justifyContent(FlexAlign.SpaceAround)
      if (!this.collapsed) {
        Blank()
          .height(10)

      }
    }
    .padding(10)
  }
}