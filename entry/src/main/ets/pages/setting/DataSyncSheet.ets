import { SubItemToggle } from '../../components/SubItemToggle'
import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import { AppPreference, SettingValue, EVENT_NAMES, PREF_KEYS, ROUTE_NAMES } from '../../utils/AppPreference';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { bundleManager, common } from '@kit.AbilityKit';
import { PermissionManager } from '../../utils/PermissionManager';
import { throttle } from '../../utils/UiUtils';
import { ShowDataSyncDetailsPage } from '../ShowDataSyncDetailsPage';
import { ShowCloudSyncDetailsPage } from '../ShowCloudSyncDetailsPage';
import { ShowCloudBackupHistoryPage } from '../ShowCloudBackupHistoryPage';
import { MasterKeyPage } from '../MasterKeyPage';

@Preview
@ComponentV2
export struct DataSyncSheet {
  pageInfos: NavPathStack = new NavPathStack();
  @Local RdbSyncEnable: SettingValue = false;
  @Local RdbCloudSyncEnable: SettingValue = false;
  @Local isMasterKeySet: boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  aboutToAppear(): void {
    this.RdbSyncEnable = AppPreference.getPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE);
    this.RdbCloudSyncEnable = AppPreference.getPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE);
    this.isMasterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    this.appCtx.eventHub.on(EVENT_NAMES.DATASYNC_PERMISSIONS_UPDATE, this.updateDATASYNCPermissions);
    this.appCtx.eventHub.on(EVENT_NAMES.MASTER_KEY_PAGE_BACK, () => {
      this.isMasterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
      if (this.isMasterKeySet && !this.RdbCloudSyncEnable) {
        this.RdbCloudSyncEnable = true;
        AppPreference.setPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE, true);
      }
    });
  }

  updateDATASYNCPermissions(isAccess: boolean) {
    if (!isAccess) {
      this.RdbSyncEnable = false;
      this.RdbCloudSyncEnable = false;
      AppPreference.setPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE, false);
      AppPreference.setPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE, false);
    }
  }

  aboutToDisappear() {
    this.appCtx.eventHub.off(EVENT_NAMES.DATASYNC_PERMISSIONS_UPDATE, this.updateDATASYNCPermissions);
    this.appCtx.eventHub.off(EVENT_NAMES.MASTER_KEY_PAGE_BACK);
  }

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === ROUTE_NAMES.ShowDataSyncDetailsPage) {
      ShowDataSyncDetailsPage()
    } else if (name === ROUTE_NAMES.ShowCloudSyncDetailsPage) {
      ShowCloudSyncDetailsPage()
    } else if (name === ROUTE_NAMES.ShowCloudBackupHistoryPage) {
      ShowCloudBackupHistoryPage()
    } else if (name === ROUTE_NAMES.MasterKeyPage) {
      MasterKeyPage()
    }
  }

  build() {
    Navigation(this.pageInfos) {
      Column() {
        Text($r('app.string.data_sync'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .padding({ left: LengthMetrics.vp(24).value, right: LengthMetrics.vp(24).value, top: LengthMetrics.vp(16).value, bottom: LengthMetrics.vp(8).value })
          .width('100%')
        List({ space: 10 }) {
          ListItem() {
            SettingItem({ title: "" }) {
              SubItemToggle({
                icon: $r('sys.symbol.link'),
                title: $r('app.string.data_rdb_sync'),
                isOn: this.RdbSyncEnable as boolean,
                description: $r('app.string.data_rdb_sync_des'),
                onChange: (IsOn: boolean) => {
                  if (IsOn) {
                    PermissionManager.getInstance().reqPermissionsFromUser(this.appCtx);
                  }
                  this.RdbSyncEnable = IsOn;
                  AppPreference.setPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE, IsOn);
                }
              })

              SubItemDivider()

              SubItemButton({
                symbol: $r('sys.symbol.arrow_counterclockwise_clock'),
                text: $r('app.string.data_rdb_sync_details')
              })
                .onClick(throttle((event) => {
                  this.pageInfos.pushPathByName(ROUTE_NAMES.ShowDataSyncDetailsPage, null);
                }, 1000))
            }
          }
          .padding({ left: 10, right: 10 })

          ListItem() {
            SettingItem({ title: "" }) {
              SubItemToggle({
                icon: $r('sys.symbol.icloud'),
                title: $r('app.string.data_rdb_cloud_sync'),
                isOn: this.RdbCloudSyncEnable as boolean,
                description: $r('app.string.data_rdb_cloud_sync_des'),
                onChange: (IsOn: boolean) => {
                  if (IsOn) {
                    if (!this.isMasterKeySet) {
                      this.RdbCloudSyncEnable = false;
                      this.showMasterKeyRequiredDialog();
                      return;
                    }
                  }
                  this.RdbCloudSyncEnable = IsOn;
                  AppPreference.setPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE, IsOn);
                }
              })

              SubItemDivider()

              SubItemButton({
                symbol: $r('sys.symbol.icloud'),
                text: $r('app.string.data_huawei_cloud_sync_details')
              })
                .onClick(throttle((event) => {
                  this.pageInfos.pushPathByName(ROUTE_NAMES.ShowCloudSyncDetailsPage, null);
                }, 1000))
            }
          }
          .padding({ left: 10, right: 10 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .backgroundColor($r('app.color.window_background'))
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.window_background'))
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.navDestinationBuilder)
  }

  private showMasterKeyRequiredDialog(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.cloud_sync_require_master_key_title'),
      message: $r('app.string.cloud_sync_require_master_key_msg'),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      buttonDirection: DialogButtonDirection.HORIZONTAL,
      buttons: [
        {
          value: $r('app.string.cloud_sync_require_master_key_set'),
          action: () => {
            this.pageInfos.pushPathByName(ROUTE_NAMES.MasterKeyPage, null);
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
}
