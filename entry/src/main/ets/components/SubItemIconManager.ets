
@Preview
@ComponentV2
export struct SubItemIconManager {
  @Require @Param onChange: (selected: number) => void = () => {};
  @Local collapsed: boolean = true;

  build() {
    Column() {
      Row() {
        Column() {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.plus_square_on_square'))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor([$r('app.color.str_main')])

            Text($r('app.string.setting_icon_pack'))
              .fontSize($r('sys.float.ohos_id_text_size_body1'))
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .fontWeight(FontWeight.Regular)
              .textAlign(TextAlign.Start)
          }

          Text($r('app.string.setting_icon_pack_desc'))
            .fontSize($r('sys.float.ohos_id_text_size_body2'))
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .fontWeight(FontWeight.Regular)
            .fontFamily('HarmonyHeiTi')
            .lineHeight(19)
        }
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          Blank()
          Text($r('app.string.setting_icon_pack_preview', 0))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontColor([$r('sys.color.font_tertiary')])
            .fontSize(24)
            .height(48)
            .align(Alignment.Center)
            .rotate(this.collapsed ? { angle: 0 } : { angle: 90 })
            .translate(this.collapsed ? {} : { x: -3 })
        }
        .layoutWeight(1)
        .onClick(() => {
          animateTo({ duration: 200, curve: Curve.Sharp }, () => {
            this.collapsed = !this.collapsed;
          })
        })

      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')

      if (!this.collapsed) {
        Row()
          .width('100%')
          .height(90)
      }
    }
    .width('100%')
    .padding(10)
  }
}