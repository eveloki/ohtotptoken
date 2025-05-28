
@Preview
@ComponentV2
export struct SubItemColor {
  @Require @Param onChange: (color: string) => void = () => {};
  @Require @Param title: string | Resource = '';
  @Require @Param color: string = '#FF000000';
  @Param disable: boolean = false;
  @Param icon: Resource | undefined = undefined;
  @Param description: string  | Resource = '';

  build() {
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

        Blank()

        Shape() {

        }
        .backgroundColor(this.color)
        .width(20)
        .height(20)
        .borderRadius(5)
        .enabled(!this.disable)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
        .onClick(() => {

        })
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
    .padding(10)
  }
}