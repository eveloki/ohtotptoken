import { SubItemToggle } from '../../components/SubItemToggle'
import { AppStorageV2, router } from '@kit.ArkUI';
import { AppPreference, SettingValue } from '../../utils/AppPreference';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { bundleManager,common } from '@kit.AbilityKit';
import { PermissionManager } from '../../utils/PermissionManager';
import { throttle } from '../../utils/UiUtils';

@Preview
@ComponentV2
export struct DataSyncSheet {
  @Local RdbSyncEnable: SettingValue = false;
  @Local RdbCloudSyncEnable: SettingValue = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  aboutToAppear(): void {
    this.RdbSyncEnable = AppPreference.getPreference('app_db_rds_sync_enable');
    this.RdbCloudSyncEnable = AppPreference.getPreference('app_db_rds_cloud_sync_enable');
    //订阅权限变更
    this.appCtx.eventHub.on('DATASYNCPermissionsUpdate', this.updateDATASYNCPermissions);
  }

  //更新数据同步权限
  updateDATASYNCPermissions(isAccess: boolean) {
    if (!isAccess) {
      //如果数据同步权限被关闭 则需要将两个同步都关闭
      this.RdbSyncEnable = false;
      this.RdbCloudSyncEnable = false;
      AppPreference.setPreference('app_db_rds_sync_enable', false);
      AppPreference.setPreference('app_db_rds_cloud_sync_enable', false);
    }
  }

  aboutToDisappear() {
    this.appCtx.eventHub.off('DATASYNCPermissionsUpdate', this.updateDATASYNCPermissions);
  }

  build() {
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
              AppPreference.setPreference('app_db_rds_sync_enable', IsOn);
            }
          })

          SubItemDivider()

          SubItemToggle({
            icon: $r('sys.symbol.icloud'),
            title: $r('app.string.data_rdb_cloud_sync'),
            isOn: this.RdbCloudSyncEnable as boolean,
            description: $r('app.string.data_rdb_cloud_sync_des'),
            disable: true,
            onChange: (IsOn: boolean) => {
              if (IsOn) {
                PermissionManager.getInstance().reqPermissionsFromUser(this.appCtx);
              }
              this.RdbCloudSyncEnable = IsOn;
              AppPreference.setPreference('app_db_rds_cloud_sync_enable', IsOn);
            }
          })
            .visibility(Visibility.None)

          SubItemDivider()
            .visibility(Visibility.None)

          SubItemButton({
            symbol: $r('sys.symbol.arrow_counterclockwise_clock'),
            text: $r('app.string.data_rdb_sync_details')
          })
            .onClick(throttle((event) => {
              router.pushUrl({ url: 'pages/ShowDataSyncDetailsPage' });
            }, 1000))
        }
      }
      .padding({ left: 10, right: 10 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, {alwaysEnabled: true})
    .backgroundColor($r('app.color.window_background'))
  }
}
