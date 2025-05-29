export class ColorItem {
  name: ResourceStr = '';
  color: string = '';
}

@Preview
@ComponentV2
export struct SubItemColor {
  @Require @Param onChange: (index: number, color: string) => void = () => {};
  @Require @Param title: string | Resource = '';
  @Require @Param colors: ColorItem[] = [{name: "a", color: '#ff00ff00'}];
  @Param disable: boolean = false;
  @Param icon: Resource | undefined = undefined;
  @Param description: string  | Resource = '';

  @Local color_values: string[] = this.colors.map((c) => c.color);

  private color_scheme: string[] = [
    '#ffececec',
    "#FFD6D6D6",
    "#FF012EE0",
    "#FF86c1ff",
    "#FF254ff7",
    "#FF86c1ff",
    "#FF254ff7",
    "#FFF18585",
    "#FFD71616",
    "#FFF18585",
    "#FFD71616",
  ];

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
      Blank()
      ForEach(this.colors, (color: ColorItem, index: number) => {
        Row() {
          Text(color.name)
            .width('30%')
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          Shape()
            .backgroundColor(color.color)
            .width(40)
            .height(40)
            .onClick(() => {
            })
        }
        .justifyContent(FlexAlign.SpaceAround)

      })
    }
    .padding(10)
  }
}