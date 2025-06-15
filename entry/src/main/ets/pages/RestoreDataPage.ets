import { AppStorageV2, router } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { AppPreference } from '../utils/AppPreference';
import { common } from '@kit.AbilityKit';
import { TokenStore } from '../utils/TokenStore';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';


@Entry
@ComponentV2
struct RestoreDataPage {
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local isEnabledKDF: boolean = false;//是否启用主密钥 todo 这里还需要补充输入朱密码的UI场景
  @Local isBegin: boolean = false;//是否开始恢复
  @Local isRestoreSuccess: boolean = false;//是否恢复成功
  @Local progress: number = 0;
  TOAST_BOTTOM: number = 135;
  tkStore = TokenStore.getInstance();

  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;
  aboutToAppear(): void {
    this.isBegin = false;
    this.isEnabledKDF=AppPreference.getPreference("app_use_kdf") as boolean;
  }
  restoreData() {
    this.isBegin = true;
    this.progress = 0;
    let interval = setInterval(() => {
      if (this.progress < 99) {
        this.progress++;
      } else {
        this.isBegin = false;
        this.progress = 0;
        this.isRestoreSuccess=true;
        clearInterval(interval);
      }
    }, 250);

    this.tkStore.RestoreByKVAsync().then((n)=>{
      //更新存档时间
      if (n>0) {
        AppPreference.setPreference('app_db_kv_archive_time', Date().toString());
      }
    }).catch((err:BusinessError)=>{
      hilog.error(err.code,"RestoreByKVAsync",`${err.message}`)
    }).finally(()=>{
      this.progress=100;
      clearInterval(interval);
      setTimeout(() => {
        this.isBegin = false;
        this.progress = 0;
        this.isRestoreSuccess=true;
        //this.getUIContext().getPromptAction().showToast({ message: $r('app.string.restore_data_ok_msg'), bottom: this.TOAST_BOTTOM })
        this.getUIContext().showAlertDialog(
          {
            title: $r('app.string.restore_data'),
            message:$r('app.string.restore_data_ok_msg'),
            autoCancel: true,
            alignment: DialogAlignment.Center,
            offset: { dx: 0, dy: -20 },
            gridCount: 3,
            buttons: [{
              value: 'cancel',
              action: () => {
              }
            },
              {
                enabled: true,
                defaultFocus: true,
                style: DialogButtonStyle.HIGHLIGHT,
                value: 'ok',
                action: () => {
                  this.appCtx.terminateSelf();
                }
              }],
          }
        );
      }, 200)

    });
  }

  build() {
    Column() {
      TopNavigationView({
        title: $r('app.string.restore_data'),
        onBackClick: () => {
          router.back();
        }
      })
      Column() {
        Column() {
          LoadingProgress()
            .width(100)
            .layoutWeight(1)
        }
        .height('60%')
        Column() {
          if (this.isEnabledKDF)
          {
            Text($r('app.string.restore_data_kdf_msg'))
              .fontSize(16)
              .fontWeight(500)
          }
          else
          {
            Text($r('app.string.restore_data_msg'))
              .fontSize(16)
              .fontWeight(500)
          }
          Button() {
            if (this.isBegin) {
              Row() {
                Progress({ value: this.progress, type: ProgressType.Ring })
                  .width(20)
                  .height(20)
                  .backgroundColor('#FFFFFF')
                  .color('#558DFF')
                  .style({ strokeWidth: 2, scaleCount: 100, scaleWidth: 2 })
                Text()
                {
                  Span($r('app.string.restore_data_restoring'))
                  Span(` ${this.progress}%`)
                }
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(500)
                .margin({ left: 12 })
              }.alignItems(VerticalAlign.Center)
            } else {
              Text($r('app.string.restore_data'))
                .fontSize(16)
                .fontWeight(500)
                .fontColor($r('app.color.white'))
            }
          }
          .id('publish')
          .width('100%')
          .height(40)
          .margin({ bottom: this.isBegin ? 16 : 24 })
          .enabled(!this.isRestoreSuccess)
          .backgroundColor($r('app.color.button_blue'))
          .onClick(() => {
            if (!this.isBegin) {
              this.restoreData();
            }
          })

          if (this.isBegin) {
            Button() {
              Text($r('app.string.restore_data_cancel'))
                .fontSize(16)
                .fontWeight(500)
                .fontColor($r('app.color.btn_text_blue'))
            }
            .id('cancel')
            .width('100%')
            .height(40)
            .margin({ bottom: 24 })
            .backgroundColor($r('app.color.button_light_gray'))
            .enabled(true)
            .onClick(() => {
              // cancel task
              //this.progress = 0;
              //this.isBegin = false;
            })
          }
        }
        .padding({ left: 24, right: 24 })
        .align(Alignment.End)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ top: this.window.AvoidTopHeight, bottom: this.window.AvoidBottomHeight })
  }
}