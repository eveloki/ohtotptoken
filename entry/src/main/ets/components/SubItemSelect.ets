
@Preview
@ComponentV2
export struct SubItemSelect {
  @Require @Param onChange: (selected: number) => void = () => {};
  @Require @Param title: string | Resource = '';
  @Require @Param values: string[] | Resource[] = [];
  @Require @Param selected: number = 0;
  @Param disable: boolean = false;
  @Param icon: Resource | undefined = undefined;
  @Param description: string  | Resource = '';

  build() {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
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
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          if (this.description != '') {
            Text(this.description)
              .fontSize($r('sys.float.ohos_id_text_size_body2'))
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
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

        Select(this.values.map((val: string | Resource) => {return { value: val as string } as SelectOption }))
          .enabled(!this.disable)
          .value(this.values[this.selected])
          .selected(this.selected)
          .onSelect((index) => {
            this.onChange(index);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding(10)
  }
}
