import { image } from '@kit.ImageKit';
import common2D from '@ohos.graphics.common2D';
import Matrix4 from '@ohos.matrix4';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ImageLoadedEvent {
  width: number;
  height: number;
  componentWidth: number;
  componentHeight: number;
  loadingStatus: number;
  contentWidth: number;
  contentHeight: number;
  contentOffsetX: number;
  contentOffsetY: number;
}

interface ImageLoadEventListener {
  onImageLoaded(msg: ImageLoadedEvent): void;
  onImageLoadError(error: ImageError): void;
}

/**
 * 图片裁剪模型，参考 PersonalInfoUpload 项目的 ImageCrop 实现
 * 管理裁剪参数（图片源、取景框尺寸/比例、手势偏移/缩放），提供 crop() 方法执行裁剪
 * 裁剪流程: 打开源文件 -> ImageSource -> PixelMap深拷贝(BGRA→RGBA) -> cropSync(裁剪区域) -> 返回PixelMap
 * 注: 裁剪输出为正方形/矩形图片，圆形效果需在UI层通过 .borderRadius() 实现
 */
export class CropModel {
  src: string = '';
  previewSource: string | Resource = '';
  panEnabled: boolean = true;
  zoomEnabled: boolean = true;
  frameWidth: number = 1000;
  frameRatio: number = 1;
  maskColor: string = '#AA000000';
  strokeColor: string = '#FFFFFF';
  imageLoadEventListener: ImageLoadEventListener | null = null;
  imageWidth: number = 0;
  imageHeight: number = 0;
  componentWidth: number = 0;
  componentHeight: number = 0;
  scale: number = 1;
  offsetX: number = 0;
  offsetY: number = 0;

  public setImage(src: string, previewSource?: string | Resource): CropModel {
    this.src = src;
    if (!!previewSource) {
      this.previewSource = previewSource;
    }
    return this;
  }

  public setFrameWidth(frameWidth: number): CropModel {
    this.frameWidth = frameWidth;
    return this;
  }

  public setFrameRatio(frameRatio: number): CropModel {
    this.frameRatio = frameRatio;
    return this;
  }

  public getFrameHeight(): number {
    return this.frameWidth / this.frameRatio;
  }

  public reset(): void {
    this.scale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
  }

  /**
   * 执行图片裁剪
   * 1. 计算图片适配控件缩放比(adaptScale)与手势缩放比(scale)的总缩放(totalScale)
   * 2. 根据取景框在组件中的位置，反算出原图中对应的裁剪区域(Region)
   * 3. 打开文件 -> ImageSource -> PixelMap(BGRA_8888) -> 深拷贝为RGBA_8888 -> cropSync裁剪
   * @returns 裁剪后的 PixelMap
   */
  public async crop(): Promise<image.PixelMap> {
    if (!this.src || this.src === '') {
      throw new Error('Please set src first');
    }
    if (this.imageWidth === 0 || this.imageHeight === 0) {
      throw new Error('The image is not loaded');
    }

    let widthScale = this.componentWidth / this.imageWidth;
    let heightScale = this.componentHeight / this.imageHeight;
    let adaptScale = Math.min(widthScale, heightScale);

    let totalScale = adaptScale * this.scale;
    let showWidth = this.imageWidth * totalScale;
    let showHeight = this.imageHeight * totalScale;
    let imageX = (this.componentWidth - showWidth) / 2;
    let imageY = (this.componentHeight - showHeight) / 2;

    let frameX = (this.componentWidth - this.frameWidth) / 2;
    let frameY = (this.componentHeight - this.getFrameHeight()) / 2;

    let showX = imageX + this.offsetX * this.scale;
    let showY = imageY + this.offsetY * this.scale;
    let x = (frameX - showX) / totalScale;
    let y = (frameY - showY) / totalScale;

    let file = fileIo.openSync(this.src, fileIo.OpenMode.READ_ONLY);
    let imageSource: image.ImageSource = image.createImageSource(file.fd);
    let decodingOptions: image.DecodingOptions = {
      editable: true,
      desiredPixelFormat: image.PixelMapFormat.BGRA_8888,
    };
    let pm = await imageSource.createPixelMap(decodingOptions);
    let cp = await this.copyPixelMap(pm);
    pm.release();

    let region: image.Region =
      { x: x, y: y, size: { width: this.frameWidth / totalScale, height: this.getFrameHeight() / totalScale } };
    cp.cropSync(region);

    fileIo.closeSync(file);
    await imageSource.release();
    return cp;
  }

  async copyPixelMap(pm: PixelMap): Promise<PixelMap> {
    const imageInfo: image.ImageInfo = await pm.getImageInfo();
    const buffer: ArrayBuffer = new ArrayBuffer(pm.getPixelBytesNumber());
    await pm.readPixelsToBuffer(buffer);
    const opts: image.InitializationOptions = {
      editable: true,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: { height: imageInfo.size.height, width: imageInfo.size.width }
    };
    return image.createPixelMap(buffer, opts);
  }
}

/**
 * 图片裁剪视图组件
 * 上层: Image组件显示源图片，通过Matrix4变换实现拖动/缩放
 * 下层: Canvas绘制半透明遮罩 + 圆形取景框（纯视觉引导，不影响裁剪结果）
 * 手势: 拖动(PanGesture)平移图片、双指缩放(PinchGesture)、双击切换1x/2x
 */
@Component
export struct CropView {
  @State model: CropModel = new CropModel();
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State private matrix: object = Matrix4.identity()
    .translate({ x: 0, y: 0 })
    .scale({ x: this.model.scale, y: this.model.scale });
  private tempScale: number = 1;
  private startOffsetX: number = 0;
  private startOffsetY: number = 0;

  build() {
    Stack() {
      Image(this.model.src)
        .width('100%')
        .height('100%')
        .alt(this.model.previewSource)
        .objectFit(ImageFit.Contain)
        .transform(this.matrix)
        .onComplete((msg) => {
          if (msg) {
            this.model.imageWidth = msg.width;
            this.model.imageHeight = msg.height;
            this.model.componentWidth = msg.componentWidth;
            this.model.componentHeight = msg.componentHeight;
            this.checkImageAdapt();
          }
        })
        .onError((error) => {
          hilog.error(0, 'CropView', 'Image load error: ' + JSON.stringify(error));
        });
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onReady(() => {
          if (this.context == null) {
            return;
          }
          let height = this.context.height;
          let width = this.context.width;
          this.context.fillStyle = this.model.maskColor;
          this.context.fillRect(0, 0, width, height);

          let centerX = width / 2;
          let centerY = height / 2;

          this.context.globalCompositeOperation = 'destination-out';
          this.context.fillStyle = 'white';
          this.context.beginPath();
          this.context.arc(centerX, centerY, this.getUIContext().px2vp(this.model.frameWidth / 2), 0, 2 * Math.PI);
          this.context.fill();

          this.context.globalCompositeOperation = 'source-over';
          this.context.strokeStyle = this.model.strokeColor;
          let frameWidthInVp = this.getUIContext().px2vp(this.model.frameWidth);
          let frameHeightInVp = this.getUIContext().px2vp(this.model.getFrameHeight());
          let radius = Math.min(frameWidthInVp, frameHeightInVp) / 2;
          this.context.beginPath();
          this.context.arc(centerX, centerY, radius, 0, 2 * Math.PI);
          this.context.closePath();
          this.context.lineWidth = 1;
          this.context.stroke();
        })
        .enabled(false);
    }
    .clip(true)
    .width('100%')
    .height('100%')
    .backgroundColor('#00000080')
    .priorityGesture(
      TapGesture({ count: 2, fingers: 1 })
        .onAction((event: GestureEvent) => {
          if (!event) {
            return;
          }
          if (this.model.zoomEnabled) {
            if (this.model.scale !== 1) {
              this.model.scale = 1;
              this.model.reset();
              this.updateMatrix();
            } else {
              this.zoomTo(2);
            }
          }
          this.checkImageAdapt();
        })
    )
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture({})
          .onActionStart(() => {
            this.startOffsetX = this.model.offsetX;
            this.startOffsetY = this.model.offsetY;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event) {
              if (this.model.panEnabled) {
                let distanceX: number = this.startOffsetX + this.getUIContext().vp2px(event.offsetX) / this.model.scale;
                let distanceY: number = this.startOffsetY + this.getUIContext().vp2px(event.offsetY) / this.model.scale;
                this.model.offsetX = distanceX;
                this.model.offsetY = distanceY;
                this.updateMatrix();
              }
            }
          })
          .onActionEnd(() => {
            this.checkImageAdapt();
          }),
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.tempScale = this.model.scale;
          })
          .onActionUpdate((event) => {
            if (event) {
              if (!this.model.zoomEnabled) {
                return;
              }
              this.zoomTo(this.tempScale * event.scale);
            }
          })
          .onActionEnd(() => {
            this.checkImageAdapt();
          })
      )
    );
  }

  private checkImageAdapt() {
    let offsetX = this.model.offsetX;
    let offsetY = this.model.offsetY;
    let scale = this.model.scale;

    let widthScale = this.model.componentWidth / this.model.imageWidth;
    let heightScale = this.model.componentHeight / this.model.imageHeight;
    let adaptScale = Math.min(widthScale, heightScale);

    let showWidth = this.model.imageWidth * adaptScale * this.model.scale;
    let showHeight = this.model.imageHeight * adaptScale * this.model.scale;
    let imageX = (this.model.componentWidth - showWidth) / 2;
    let imageY = (this.model.componentHeight - showHeight) / 2;

    let frameX = (this.model.componentWidth - this.model.frameWidth) / 2;
    let frameY = (this.model.componentHeight - this.model.getFrameHeight()) / 2;

    let showX = imageX + offsetX * scale;
    let showY = imageY + offsetY * scale;

    if (this.model.frameWidth > showWidth || this.model.getFrameHeight() > showHeight) {
      let xScale = this.model.frameWidth / showWidth;
      let yScale = this.model.getFrameHeight() / showHeight;
      let newScale = Math.max(xScale, yScale);
      this.model.scale = this.model.scale * newScale;
      showX *= newScale;
      showY *= newScale;
    }

    if (showX > frameX) {
      showX = frameX;
    } else if (showX + showWidth < frameX + this.model.frameWidth) {
      showX = frameX + this.model.frameWidth - showWidth;
    }
    if (showY > frameY) {
      showY = frameY;
    } else if (showY + showHeight < frameY + this.model.getFrameHeight()) {
      showY = frameY + this.model.getFrameHeight() - showHeight;
    }
    this.model.offsetX = (showX - imageX) / scale;
    this.model.offsetY = (showY - imageY) / scale;
    this.updateMatrix();
  }

  public zoomTo(scale: number): void {
    this.model.scale = scale;
    this.updateMatrix();
  }

  public updateMatrix(): void {
    this.matrix = Matrix4.identity()
      .translate({ x: this.model.offsetX, y: this.model.offsetY })
      .scale({ x: this.model.scale, y: this.model.scale });
  }
}
