import { scanCore, generateBarcode } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { copyText } from '../utils/TokenUtils';
import { window } from '@kit.ArkUI';

@Preview
@CustomDialog
export struct QRCodeDialog {
  controller?: CustomDialogController;
  @Prop content: string = '';
  @Prop winSize: window.Size;
  @State pixelMap: image.PixelMap | undefined = undefined
  @State qrSize: number = px2vp(Math.min(this.winSize.width, this.winSize.height)) * 0.8;

  aboutToAppear(): void {
    this.pixelMap = undefined;
    let options: generateBarcode.CreateOptions = {
      scanType: scanCore.ScanType.QR_CODE,
      height: this.qrSize,
      width: this.qrSize
    }
    try {
      // 码图生成接口，成功返回PixelMap格式图片
      generateBarcode.createBarcode(this.content, options).then((pixelMap: image.PixelMap) => {
        this.pixelMap = pixelMap;
      }).catch((error: BusinessError) => {
        hilog.error(0x0001, '[generateBarcode]',
          `Failed to get PixelMap by promise with options. Code: ${error.code}, message: ${error.message}`);
      })
    } catch (error) {
      hilog.error(0x0001, '[generateBarcode]',
        `Failed to createBarcode by promise with options. Code: ${error.code}, message: ${error.message}`);
    }
  }

  build() {
    Column({ space: 10 }) {
      if (this.pixelMap) {
        Image(this.pixelMap)
          .objectFit(ImageFit.Contain)
          .constraintSize({ maxHeight: this.qrSize })
          .layoutWeight(1)
      }
      Text() {
        Span(this.content)
      }
      .fontSize(10)
      .fontColor($r('app.color.str_gray'))
      .onClick(() => {
        copyText(this.content, "uri copied");
      })

    }
    .padding(20)
    .width('100%')
  }
}
