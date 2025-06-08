import { AppStorageV2, router } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { SettingItem } from '../components/SettingItem';
import { deviceInfo } from '@kit.BasicServicesKit';
import { AppPreference, SettingValue } from '../utils/AppPreference';
import { SubItemButton } from '../components/SubItemButton';
import { TokenStore } from '../utils/TokenStore';
import { SubItemDivider } from '../components/SubItemDivider';
import { AppWindowInfo } from '../entryability/EntryAbility';

@Preview
@Entry
@ComponentV2
struct ShowDataSyncDetailsPage {
  @Local AppDbKVSyncTime: SettingValue = '';
  @Local Is_loaded: boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  aboutToAppear(): void {
    this.AppDbKVSyncTime = AppPreference.getPreference('app_db_kv_sync_time');
    if (this.AppDbKVSyncTime == '' || this.AppDbKVSyncTime == null) {
      this.AppDbKVSyncTime = 'invalid';
    }
  }

  build() {
    Column() {
      TopNavigationView({
        title: $r('app.string.data_rdb_sync_details'),
        onBackClick: () => {
          router.back();
        }
      })
      RelativeContainer() {
        Stack() {
          if (this.Is_loaded) {
            Column() {
              LoadingProgress()
                .color(Color.White)
                .width(80).height(80)
              Text('Loading..')
                .fontSize(16)
                .fontColor(Color.White)
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#40000000')
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 10 }) {
              ListItem()
              ListItem() {
                SettingItem({ title: $r('app.string.data_dev_info') }) {
                  Row() {
                    Text(deviceInfo.marketName)
                      .fontSize($r('sys.float.ohos_id_text_size_body2'))
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .textAlign(TextAlign.Start)
                  }
                  .padding(10)

                  SubItemDivider()

                  Row() {
                    Text(deviceInfo.ODID)
                      .fontSize($r('sys.float.ohos_id_text_size_body2'))
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .textAlign(TextAlign.Start)
                  }
                  .padding(10)
                }

              }
              .padding({ left: 10, right: 10 })

              ListItem() {
                SettingItem({ title: $r('app.string.data_kv_sync_time') }) {
                  Row() {
                    Text(this.AppDbKVSyncTime as string)
                      .fontSize($r('sys.float.ohos_id_text_size_body2'))
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .textAlign(TextAlign.Start)
                  }
                  .padding(10)

                  SubItemDivider()

                  SubItemButton({
                    symbol: $r('sys.symbol.arrow_clockwise'),
                    text: $r('app.string.data_sync_manual')
                  })
                    .onClick(() => {
                      this.Is_loaded=true;
                      TokenStore.getInstance().DataSync().then(()=>{
                        setTimeout(() => {
                          this.Is_loaded = false;
                          AppPreference.setPreference('app_db_kv_sync_time', Date().toString());
                          this.AppDbKVSyncTime = AppPreference.getPreference('app_db_kv_sync_time');
                          }, 1500);
                      });
                    })
                }
              }
              .padding({ left: 10, right: 10 })

            }
            .chainAnimation(true)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .scrollBar(BarState.Off)
            .backgroundColor($r('app.color.window_background'))
            .width('100%')
            .height('100%')
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.window.AvoidTopHeight, bottom: this.window.AvoidBottomHeight })
  }
}