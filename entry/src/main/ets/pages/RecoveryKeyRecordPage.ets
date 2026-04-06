import { AppStorageV2 } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { AppPreference, EVENT_NAMES } from '../utils/AppPreference';
import { common } from '@kit.AbilityKit';
import { TokenStore } from '../utils/TokenStore';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { showSaveFilePicker, showSelectFilePicker, writeFileContent,
  writeFileContentCheckHashEqual } from '../utils/FileUtils';
import lottie, { AnimationItem } from '@ohos/lottie';
import { throttle } from '../utils/UiUtils';
import { showSnackBar, SnackBarNotifyType } from '../utils/HdsSnackBarUtils';

@Entry
@ComponentV2
export struct RecoveryKeyRecordPage {
  pageInfos: NavPathStack | null = null;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local recoverySecretKey: string = "";
  @Local recoverySecretKeyShow: string = "";
  tkStore = TokenStore.getInstance();

  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;
  // 构建上下文
  private renderingSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private canvasRenderingContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderingSettings)
  private animateItem: AnimationItem | null = null;
  private animateName: string = "no-limit"; // 动画名称
  TOAST_BOTTOM: number = 135;

  // 页面销毁时释放动画资源
  aboutToDisappear(): void {
    console.info('aboutToDisappear');
    lottie.destroy();
  }

  aboutToAppear(): void {
  }
  onReceiveParams(context: NavDestinationContext) {
    const params = context.pathInfo.param as Record<string, string>;
    if (params) {
      this.recoverySecretKey = params['recoverySecretKey'] ?? '';
      this.recoverySecretKeyShow = params['recoverySecretKeyShow'] ?? '';
    }
  }
  confirmRecoveryKey(){
    //this.tkStore.CheckRecoverySecretKey(this.recoverySecretKey).then((b)=>{
    //  showSnackBar(b ? "恢复密钥OK" : "恢复密钥Err", SnackBarNotifyType.INFO)
    //})
    //this.appCtx?.eventHub.emit(EVENT_NAMES.MASTER_KEY_PAGE_BACK);
    this.pageInfos?.clear();
  }
  exportRecoveryKey(){
    showSaveFilePicker([`totp_recovery_key.text`], ['Text|.text']).then((uris) => {
      if (uris[0] !== undefined && uris[0] !== '') {
        writeFileContentCheckHashEqual(uris[0], this.recoverySecretKey).then(()=>{
          showSnackBar('OK', SnackBarNotifyType.SUCCESS);
        });
      }
    });
  }

  build() {
    NavDestination() {
    Column() {
      TopNavigationView({
        title: $r('app.string.restore_record_recovery_key'),
        onBackClick: () => {
          this.pageInfos?.pop('');
        }
      })
      Scroll() {
        Column() {
          Column() {
            // 关联画布
            Canvas(this.canvasRenderingContext)
              .width(200)
              .height(200)
              .backgroundColor(Color.Transparent)
              .onReady(() => {
                // 加载动画
                if (this.animateItem != null) {
                  // 可在此生命回调周期中加载动画，可以保证动画尺寸正确
                  this.animateItem?.resize();
                } else {
                  // 抗锯齿的设置
                  this.canvasRenderingContext.imageSmoothingEnabled = true;
                  this.canvasRenderingContext.imageSmoothingQuality = 'medium'
                  this.loadAnimation();
                }
              })
          }

          Column() {
            Text($r('app.string.restore_recovery_key'))
              .fontSize(28)
              .fontWeight(600)
            Text(this.recoverySecretKeyShow)
              .fontSize(24)
              .fontWeight(600)
            //Text(this.recoverySecretKey)
            //  .fontSize(20)
            //  .fontWeight(600)
            Blank(10)
            Text($r('app.string.restore_master_key_recovery_key_msg'))
              .fontSize(16)
              .fontWeight(600)

            Button() {
              Text($r('app.string.restore_recovery_key_confirm'))
                .fontSize(16)
                .fontWeight(500)
                .fontColor($r('app.color.white'))
            }
            .id('publish')
            .width('100%')
            .height(40)
            .margin({ bottom: 24 })
            .backgroundColor($r('app.color.button_blue'))
            .onClick(throttle((event) => {
              this.confirmRecoveryKey();
            }))

            Blank(10)
            Button() {
              Text($r('app.string.restore_recovery_key_export'))
                .fontSize(16)
                .fontWeight(500)
                .fontColor($r('app.color.white'))
            }
            .id('publish')
            .width('100%')
            .height(40)
            .margin({ bottom: 24 })
            .backgroundColor($r('app.color.button_blue'))
            .onClick(throttle((event) => {
              this.exportRecoveryKey();
            }))
          }
          .padding({ left: 24, right: 24 })
          .align(Alignment.End)
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 16 })
    .backgroundColor($r('app.color.window_background'))
    }
    .hideTitleBar(true, true)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
      this.onReceiveParams(context);
    })
    .onBackPressed(() => {
      return true;
    });
  }

  loadAnimation() {
    this.animateItem = lottie.loadAnimation({
      container: this.canvasRenderingContext,
      renderer: 'canvas', // canvas 渲染模式
      loop: false,
      autoplay: false,
      name: this.animateName,
      contentMode: 'Contain',
      path: "lottie/OTPVerification.json",
    })
    // 因为动画是异步加载，所以对animateItem的操作需要放在动画加载完成回调里操作
    this.animateItem.addEventListener('DOMLoaded', (args: Object): void => {
      //this.animateItem?.changeColor([225, 25, 100, 1]);
      this.animateItem?.play()
    });
  }

  destroy() {
    this.animateItem?.removeEventListener("DOMLoaded");
    lottie.destroy(this.animateName);
    this.animateItem = null;
  }
}
