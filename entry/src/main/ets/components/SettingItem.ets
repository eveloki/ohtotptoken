
@Builder
function DefaultBuilder() {
  Text('Empty');
}

@Preview
@ComponentV2
export struct SettingItem {
  @BuilderParam subItemBuilder?: CustomBuilder = DefaultBuilder;
  @Require @Param title: ResourceStr | string = '';

  build() {
    Column({ space: 5 }) {
      Text(this.title)
        .margin({ left: 10 })
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
      Row() {
        Column({ space: 0 }) {
          if (this.subItemBuilder) {
            this.subItemBuilder();
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .backgroundColor($r('app.color.item_bg'))
      .borderRadius(10)
      .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 10, offsetY: 10 })

    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}