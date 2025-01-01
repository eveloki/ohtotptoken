
@Preview
@ComponentV2
export struct SubItemButton {
  @Param symbol: Resource | undefined = $r('sys.symbol.tip_fit_test');
  @Require @Param text: ResourceStr | string = 'TEST';

  build() {
    Button({ type: ButtonType.Normal }) {
      Row() {
        SymbolGlyph(this.symbol)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor([$r('app.color.str_main')])
        Blank()
          .width(10)
        Text(this.text)
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontWeight(FontWeight.Regular)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Start)
    }
    .padding(10)
    .borderRadius(10)
    .width('100%')
    .backgroundColor($r('app.color.item_bg'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
  }
}