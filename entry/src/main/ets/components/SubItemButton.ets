
@Preview
@ComponentV2
export struct SubItemButton {
  @Param symbol: Resource | undefined = $r('sys.symbol.tip_fit_test');
  @Require @Param text: ResourceStr | string = 'TEST';
  @Param description: string  | Resource = '';
  @Param descriptionColor: ResourceColor = $r('sys.color.ohos_id_color_text_secondary');

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph(this.symbol)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor([$r('app.color.str_main')])
        Column({ space: 4 }) {
          Text(this.text)
            .fontSize($r('sys.float.ohos_id_text_size_body1'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Regular)
            .textAlign(TextAlign.Start)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.description != '') {
            Text(this.description)
              .fontSize($r('sys.float.ohos_id_text_size_body2'))
              .fontColor(this.descriptionColor)
              .fontWeight(FontWeight.Regular)
              .fontFamily('HarmonyHeiTi')
              .lineHeight(19)
              .textAlign(TextAlign.Start)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Start)
    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .padding(10)

  }
}
