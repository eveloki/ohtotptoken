import { AppStorageV2 } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { SettingItem } from '../components/SettingItem';
import { deviceInfo } from '@kit.BasicServicesKit';
import { AppPreference, SettingValue, PREF_KEYS, ROUTE_NAMES } from '../utils/AppPreference';
import { SubItemButton } from '../components/SubItemButton';
import { TokenStore } from '../utils/TokenStore';
import { SubItemDivider } from '../components/SubItemDivider';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { showSnackBar, SnackBarNotifyType } from '../utils/HdsSnackBarUtils';
import { CloudBackupManager } from '../utils/CloudBackupManager';

@Entry
@Preview
@ComponentV2
export struct ShowCloudSyncDetailsPage {
  pageInfos: NavPathStack | null = null;
  @Local cloudSyncEnabled: SettingValue = false;
  @Local masterKeySet: boolean = false;
  @Local lastSyncTime: string = '';
  @Local tokenCount: number = 0;
  @Local Is_loaded: boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  aboutToAppear(): void {
    this.cloudSyncEnabled = AppPreference.getPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE);
    this.masterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    this.lastSyncTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string ?? '';
    TokenStore.getInstance().getTokens().then(tokens => {
      this.tokenCount = tokens.length;
    });
  }

  build() {
    NavDestination() {
      Column() {
        TopNavigationView({
          title: $r('app.string.data_huawei_cloud_sync_details'),
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
                Text('Syncing...')
                  .fontSize(16)
                  .fontColor(Color.White)
              }
              .width('100%')
              .height('100%')
              .backgroundColor('#40000000')
              .justifyContent(FlexAlign.Center)
            } else {
              List({ space: 10 }) {
                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_status') }) {
                    Row() {
                      Text(this.cloudSyncEnabled ?
                        $r('app.string.cloud_sync_enabled') : $r('app.string.cloud_sync_disabled'))
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor(this.cloudSyncEnabled ?
                          $r('sys.color.ohos_id_color_text_primary') :
                          $r('sys.color.ohos_id_color_text_secondary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding(10)
                  }
                }
                .padding({ left: 10, right: 10 })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_account') }) {
                    Row() {
                      Row({ space: 10 }) {
                        SymbolGlyph($r('sys.symbol.person'))
                          .fontSize(20)
                          .fontColor([$r('app.color.str_main')])
                        Text($r('app.string.cloud_sync_not_logged_in'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                          .fontWeight(FontWeight.Medium)
                          .textAlign(TextAlign.Start)
                      }
                      .padding(10)
                    }
                  }
                }
                .padding({ left: 10, right: 10 })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_last_time') }) {
                    Row() {
                      Text((this.lastSyncTime != null && this.lastSyncTime != "")  ? this.lastSyncTime : $r('app.string.cloud_sync_never'))
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
                  SettingItem({ title: $r('app.string.cloud_sync_token_count') }) {
                    Row() {
                      Text(`${this.tokenCount}`)
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
                  SettingItem({ title: $r('app.string.cloud_sync_data_size') }) {
                    Row() {
                      Text($r('app.string.cloud_sync_calculating'))
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding(10)
                  }
                }
                .padding({ left: 10, right: 10 })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_encryption') }) {
                    Row() {
                      Text(this.masterKeySet ?
                        $r('app.string.cloud_sync_encryption_master_key') :
                        $r('app.string.cloud_sync_encryption_none'))
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor(this.masterKeySet ?
                          $r('sys.color.ohos_id_color_text_primary') :
                          $r('sys.color.ohos_id_color_text_secondary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding(10)
                  }
                }
                .padding({ left: 10, right: 10 })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_network') }) {
                    Row() {
                      Row({ space: 6 }) {
                        SymbolGlyph($r('sys.symbol.wifi'))
                          .fontSize(16)
                          .fontColor([$r('app.color.str_main')])
                        Text($r('app.string.cloud_sync_wifi_only'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          .fontColor($r('sys.color.ohos_id_color_text_primary'))
                          .fontWeight(FontWeight.Medium)
                          .textAlign(TextAlign.Start)
                      }
                      .padding(10)
                    }
                  }
                }
                .padding({ left: 10, right: 10 })

                ListItem() {
                  SettingItem({ title: '' }) {
                    SubItemButton({
                      symbol: $r('sys.symbol.arrow_clockwise'),
                      text: $r('app.string.data_sync_manual')
                    })
                      .onClick(() => {
                        this.Is_loaded = true;
                        this.triggerMockCloudSync();
                      })
                  }
                }
                .padding({ left: 10, right: 10 })

                ListItem() {
                  SettingItem({ title: '' }) {
                    SubItemButton({
                      symbol: $r('sys.symbol.clock_arrow_circlepath'),
                      text: $r('app.string.cloud_backup_history_title'),
                      description: $r('app.string.cloud_backup_history_subtitle')
                    })
                      .onClick(() => {
                        this.pageInfos?.pushPathByName(ROUTE_NAMES.ShowCloudBackupHistoryPage, null);
                      })
                  }
                }
                .padding({ left: 10, right: 10 })

                ListItem() {
                  SettingItem({ title: '' }) {
                    SubItemButton({
                      symbol: $r('sys.symbol.trash'),
                      text: $r('app.string.cloud_sync_clear_storage')
                    })
                      .onClick(() => {
                        this.showClearCloudStorageDialog();
                      })
                  }
                }
                .padding({ left: 10, right: 10 })

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

  private showClearCloudStorageDialog(): void {
    if (this.cloudSyncEnabled) {
      showSnackBar($r('app.string.cloud_sync_clear_storage_disabled_msg'), SnackBarNotifyType.WARNING);
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.cloud_sync_clear_storage_confirm'),
      message: $r('app.string.cloud_sync_clear_storage_msg'),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      buttonDirection: DialogButtonDirection.HORIZONTAL,
      buttons: [
        {
          value: $r('app.string.dialog_btn_confirm'),
          action: () => {
            this.triggerMockClearCloudStorage();
          }
        },
        {
          value: $r('app.string.dialog_btn_cancel'),
          action: () => {}
        },
      ],
      cancel: () => {},
    });
  }

  private triggerMockCloudSync(): void {
    CloudBackupManager.getInstance().backupToCloud().then(success => {
      this.Is_loaded = false;
      if (success) {
        this.lastSyncTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string;
      }
    });
  }

  private triggerMockClearCloudStorage(): void {
    this.Is_loaded = true;
    CloudBackupManager.getInstance().clearCloudStorage().then(() => {
      this.Is_loaded = false;
      this.lastSyncTime = '';
      showSnackBar($r('app.string.cloud_sync_clear_storage_success'), SnackBarNotifyType.SUCCESS);
    });
  }
}
