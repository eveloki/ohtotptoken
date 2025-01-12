import { ConfigurationConstant } from "@kit.AbilityKit";
import { getIconPathByIssuer } from "../utils/TokenUtils";

@Preview
@ComponentV2
export struct TokenIcon {
  @Require @Param issuer: string = '';
  @Local icon: string = getIconPathByIssuer(this.issuer.trim());

  @Monitor("issuer")
  onStrChange(monitor: IMonitor) {
    monitor.dirty.forEach((path: string) => {
      this.icon = getIconPathByIssuer((monitor.value(path)?.now as string).trim())
    })
  }

  stringToColor(str: string): string {
    let hash: number = 0;
    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }

    let color: string = "#";
    for (let i = 0; i < 3; i++) {
      const value: number = (hash >> (i * 8)) & 0xff;
      const hex: string = "00" + value.toString(16);
      color += hex.substring(hex.length - 2);
    }

    return color;
  }

  build() {
    if (this.icon == '') {
      Shape() {
        Text(this.issuer.charAt(0).toUpperCase() )
          .fontWeight(FontWeight.Bold)
          .fontSize(26)
          .fontColor(0xFFFFFF)
          .height(40).width(40)
          .textAlign(TextAlign.Center)
      }
      .backgroundColor(this.stringToColor(this.issuer))
      .height(40).width(40)
      .borderRadius(20)
    } else {
      if (AppStorage.get<number>('currentColorMode') === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        Image($rawfile(this.icon))
          .width(40)
          .height(40)
          .fillColor($r('app.color.item_fg'))
          .objectFit(ImageFit.Contain)
      } else {
        Image($rawfile(this.icon))
          .width(40)
          .height(40)
          .objectFit(ImageFit.Contain)
      }
    }
  }
}