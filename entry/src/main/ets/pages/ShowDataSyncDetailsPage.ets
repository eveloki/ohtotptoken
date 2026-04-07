import { AppStorageV2 } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { SettingItem } from '../components/SettingItem';
import { deviceInfo } from '@kit.BasicServicesKit';
import { AppPreference, SettingValue, PREF_KEYS } from '../utils/AppPreference';
import { SubItemButton } from '../components/SubItemButton';
import { TokenStore } from '../utils/TokenStore';
import { SubItemDivider } from '../components/SubItemDivider';
import { AppWindowInfo } from '../entryability/EntryAbility';

@Entry
@Preview
@ComponentV2
export struct ShowDataSyncDetailsPage {
  pageInfos: NavPathStack | null = null;
  @Local AppDbKVSyncTime: SettingValue = '';
  @Local AppDbKVArchiveTime: SettingValue = '';
  @Local Is_loaded: boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  aboutToAppear(): void {
    this.AppDbKVSyncTime = AppPreference.getPreference(PREF_KEYS.DB_KV_SYNC_TIME);
    this.AppDbKVArchiveTime = AppPreference.getPreference(PREF_KEYS.DB_KV_ARCHIVE_TIME);
    if (this.AppDbKVSyncTime == '' || this.AppDbKVSyncTime == null) {
      this.AppDbKVSyncTime = 'invalid';
    }
    if (this.AppDbKVArchiveTime == '' || this.AppDbKVArchiveTime == null) {
      this.AppDbKVArchiveTime = 'invalid';
    }
  }

  build() {
    NavDestination() {
    Column() {
      TopNavigationView({
        title: $r('app.string.data_rdb_sync_details'),
        onBackClick: () => {
          this.pageInfos?.pop('');
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
                SettingItem({ title: $r('app.string.data_kv_archive_time') }) {
                  Row() {
                    Text(this.AppDbKVArchiveTime as string)
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
                          AppPreference.setPreference(PREF_KEYS.DB_KV_SYNC_TIME, Date().toString());
                          this.AppDbKVSyncTime = AppPreference.getPreference(PREF_KEYS.DB_KV_SYNC_TIME);
                          this.AppDbKVArchiveTime = AppPreference.getPreference(PREF_KEYS.DB_KV_ARCHIVE_TIME);
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
    .padding({ top: 16 })
    .backgroundColor($r('app.color.window_background'))
    }
    .hideTitleBar(true, true)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
    .onBackPressed(() => {
      this.pageInfos?.pop('');
      return true;
    });
  }
}