import { ColorSelectDialog } from "../dialogs/ColorSelectDialog";
import { AppWindowInfo } from "../entryability/EntryAbility";
import { colorHex } from "../utils/ColorUtils";
import { AppStorageV2 } from "@kit.ArkUI";

export class ColorItem {
  name: ResourceStr = '';
  color: number = 0;
}

@Preview
@ComponentV2
export struct SubItemColor {
  @Require @Param onChange: (index: number, color: number) => void = () => {};
  @Require @Param title: string | Resource = '';
  @Require @Param colors: ColorItem[] = [{name: "a", color: 0}];
  @Param disable: boolean = false;
  @Param icon: Resource | undefined = undefined;
  @Param description: string  | Resource = '';
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local collapsed: boolean = true;

  private dialog_color_picker?: CustomDialogController;

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
        Column({ space: 10 }) {
          ForEach(this.colors, (color: ColorItem, index: number) => {
            Row({ space: 10 }) {
              Text(color.name)
                .width('50%')
                .textOverflow({ overflow: TextOverflow.MARQUEE })
              Text(colorHex(color.color))
                .fontWeight(FontWeight.Medium)
                .backgroundColor(color.color)
                .textAlign(TextAlign.Center)
                .textShadow({ color: Color.White, radius: 10 })
                .borderRadius(5)
                .height(30)
                .fontSize($r('sys.float.Subtitle_M'))
                .fontColor(Color.Black)
                .layoutWeight(1)
                .onClick(() => {
                  this.dialog_color_picker = new CustomDialogController({
                    builder: ColorSelectDialog({
                      old_color: color.color,
                      confirm: (new_color) => {
                        this.onChange(index, new_color);
                      }
                    })
                  })
                  this.dialog_color_picker.open()
                })
            }
          })
        }

      }
    }
    .padding(10)
  }
}