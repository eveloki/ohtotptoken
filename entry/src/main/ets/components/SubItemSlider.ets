
export class SliderItem {
  name: ResourceStr = '';
  default: number = 0;
  min: number = 0;
  max: number = 0;
  step?: number = 1;

  constructor() {
  }
}

@Preview
@ComponentV2
export struct SubItemSlider {
  @Require @Param onChange: (index: number, value: number) => void = () => {};
  @Require @Param title: string | Resource = 'aaaa';
  @Require @Param items: SliderItem[] = [{name: "a", default: 2, min: 0, max: 10}];
  @Param disable: boolean = false;
  @Param icon: Resource | undefined = undefined;
  @Param description: string  | Resource = 'aaa';

  @Local collapsed: boolean = true;

  @Local slider_values: number[] = this.items.map((item) => item.default);
  @Local tips_value: number[] = this.slider_values;

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
          animateToImmediately({ duration: 200, curve: Curve.Sharp }, () => {
            this.collapsed = !this.collapsed;
          })
        })
      }
      .justifyContent(FlexAlign.SpaceAround)

      if (!this.collapsed) {
        Blank()
        ForEach(this.items, (item: SliderItem, index: number) => {
          Row() {
            Text(item.name)
              .width('30%')
              .textOverflow({ overflow: TextOverflow.MARQUEE })
            Slider({
              value: item.default,
              min: item.min,
              max: item.max,
              step: item.step
            })
              .width('60%')
              //.enableHapticFeedback(true)
              .showTips(true, this.tips_value[index].toFixed())
              .sliderInteractionMode(SliderInteraction.SLIDE_AND_CLICK_UP)
              .onChange((value, mode) => {
                this.tips_value[index] = value;
                if (mode === SliderChangeMode.End) {
                  this.slider_values[index] = value;
                  this.onChange(index, value);
                }
              })
            Text(this.slider_values[index].toString())
              .width('10%')
              .textAlign(TextAlign.End)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
          }
          .justifyContent(FlexAlign.SpaceAround)

        })
      }
    }
    .padding(10)
  }
}