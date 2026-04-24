import { SubItemToggle } from '../../components/SubItemToggle'
import { AppStorageV2 } from '@kit.ArkUI';
import { AppPreference, SettingValue, EVENT_NAMES, PREF_KEYS, ROUTE_NAMES } from '../../utils/AppPreference';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { SubItemDivider } from '../../components/SubItemDivider';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { common } from '@kit.AbilityKit';
import { PermissionManager } from '../../utils/PermissionManager';
import { throttle } from '../../utils/UiUtils';
import { ShowDataSyncDetailsPage } from '../ShowDataSyncDetailsPage';
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { CommonConstants } from '../../utils/CommonConstants';

@Preview
@ComponentV2
export struct DataSyncSheet {
  pageInfos: NavPathStack = new NavPathStack();
  @Require @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Local RdbSyncEnable: SettingValue = false;
  @Local RdbCloudSyncEnable: SettingValue = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private sheetScroller: Scroller = new Scroller();
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  aboutToAppear(): void {
    this.RdbSyncEnable = AppPreference.getPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE);
    this.RdbCloudSyncEnable = AppPreference.getPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE);
    this.appCtx.eventHub.on(EVENT_NAMES.DATASYNC_PERMISSIONS_UPDATE, this.updateDATASYNCPermissions);
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
  }

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === ROUTE_NAMES.ShowDataSyncDetailsPage) {
      ShowDataSyncDetailsPage({ scrollEffectType: this.scrollEffectType })
    }
  }

  build() {
    Column() {
      HdsNavigation(this.pageInfos) {
        Column() {
          List({ scroller: this.sheetScroller, space: 10 }) {
            ListItem()
              .height(CommonConstants.AVOID_TOP_BASE_HEIGHT)

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
                    AppPreference.setPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE, IsOn);
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
                    this.pageInfos.pushPathByName(ROUTE_NAMES.ShowDataSyncDetailsPage, null);
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
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.window_background'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.window_background'))
      .mode(NavigationMode.Stack)
      .navDestination(this.navDestinationBuilder)
      .bindToScrollable([this.sheetScroller])
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        style: {
          originalStyle: {
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary'),
                subTitleColor: $r('sys.color.font_secondary')
              }
            },
            backgroundStyle: {
              maskExtraHeight: 0
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              maskExtraHeight: 0
            }
          },
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: this.scrollEffectType
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        content: {
          title: {
            mainTitle: $r('app.string.data_sync'),
          },
        }
      })
    }
  }
}
