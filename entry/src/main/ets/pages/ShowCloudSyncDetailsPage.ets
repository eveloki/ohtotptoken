/*
 * Copyright (c) 2023-2024 ohtotptoken Project Contributors
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { bundleManager,common, Want  } from '@kit.AbilityKit';
import { AppStorageV2, PromptAction, promptAction,LengthMetrics } from '@kit.ArkUI';
import { SettingItem } from '../components/SettingItem';
import { deviceInfo } from '@kit.BasicServicesKit';
import { AppPreference, SettingValue, PREF_KEYS, ROUTE_NAMES } from '../utils/AppPreference';
import { SubItemButton } from '../components/SubItemButton';
import { TokenStore } from '../utils/TokenStore';
import { SubItemDivider } from '../components/SubItemDivider';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { showSnackBar, SnackBarNotifyType } from '../utils/HdsSnackBarUtils';
import { CloudBackupManager } from '../utils/CloudBackupManager';
import { HuaweiAccountManager, HuaweiUserInfo } from '../utils/HuaweiAccountManager';
import { hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { CommonConstants } from '../utils/CommonConstants';
import { cloudSync } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ShowCloudSyncDetailsPage';
const DOMAIN = 0xFF00;

@Entry
@Preview
@ComponentV2
export struct ShowCloudSyncDetailsPage {
  pageInfos: NavPathStack | null = null;
  @Require @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Local cloudSyncEnabled: SettingValue = false;
  @Local lastSyncTime: string = '';
  @Local tokenCount: number = 0;
  @Local Is_loaded: boolean = false;
  @Local isHuaweiLoggedIn: boolean = false;
  @Local huaweiNickname: string = '';
  @Local syncState: number = -1;
  @Local syncError: number = 0;
  @Local loadingText: ResourceStr = '';
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local appCtx: common.UIAbilityContext = AppStorage.get('appContext') as common.UIAbilityContext;
  private scroller: Scroller = new Scroller();
  private fileSync: cloudSync.FileSync = new cloudSync.FileSync();
  private lastSyncTriggerTime: number = 0;
  private readonly SYNC_COOLDOWN_MS: number = 60000;
  private syncProgressCallback = (pg: cloudSync.SyncProgress) => {
    this.syncState = pg.state as number;
    this.syncError = pg.error as number;
  }

  aboutToAppear(): void {
    this.cloudSyncEnabled = AppPreference.getPreference(PREF_KEYS.APPEARANCE_HUAWEI_CLOUD_SYNC_ENABLE);
    this.lastSyncTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string ?? '';
    this.syncHuaweiAccountState();
    TokenStore.getInstance().getTokens().then(tokens => {
      this.tokenCount = tokens.length;
    });
    try {
      this.fileSync.on('progress', this.syncProgressCallback);
    } catch (err) {
      let e = err as BusinessError;
      console.error(`FileSync on progress failed: ${e.code} ${e.message}`);
    }
  }

  aboutToDisappear(): void {
    try {
      this.fileSync.off('progress', this.syncProgressCallback);
    } catch (err) {
      let e = err as BusinessError;
      console.error(`FileSync off progress failed: ${e.code} ${e.message}`);
    }
  }

  private syncHuaweiAccountState(): void {
    const accountMgr = HuaweiAccountManager.getInstance();
    this.isHuaweiLoggedIn = accountMgr.userLogin;
    if (accountMgr.userAccount) {
      this.huaweiNickname = accountMgr.userAccount.nickname;
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        RelativeContainer() {
          Stack() {
            if (this.Is_loaded) {
               Column() {
                 LoadingProgress()
                   .color(Color.White)
                    .width(LengthMetrics.vp(80).value).height(LengthMetrics.vp(80).value)
                  Text(this.loadingText)
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
                   .fontColor(Color.White)
               }
              .width('100%')
              .height('100%')
              .backgroundColor('#40000000')
              .justifyContent(FlexAlign.Center)
            } else {
              List({ space: LengthMetrics.vp(10).value, scroller: this.scroller }) {
                ListItem()
                  .height(CommonConstants.AVOID_TOP_BASE_HEIGHT)

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
                    .padding($r('sys.float.padding_level2'))
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  Text($r('app.string.cloud_sync_status_hint'))
                    .fontSize($r('sys.float.ohos_id_text_size_caption'))
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .width('100%')
                    .padding({ left: LengthMetrics.vp(2).value, right: LengthMetrics.vp(2).value })
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: '' }) {
                    SubItemButton({
                      symbol: $r('sys.symbol.gearshape'),
                      text: $r('app.string.cloud_sync_open_cloud_space')
                    })
                      .onClick(() => {
                        this.startCloudSpaceSettings();
                      })
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })


                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_account') }) {
                    Row() {
                      Row({ space: LengthMetrics.vp(10).value }) {
                        SymbolGlyph($r('sys.symbol.person'))
                          .fontSize(LengthMetrics.vp(20).value)
                          .fontColor([$r('app.color.str_main')])
                        Text(this.isHuaweiLoggedIn ?
                          this.huaweiNickname : $r('app.string.cloud_sync_not_logged_in'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          .fontColor(this.isHuaweiLoggedIn ?
                            $r('sys.color.ohos_id_color_text_primary') :
                            $r('sys.color.ohos_id_color_text_secondary'))
                          .fontWeight(FontWeight.Medium)
                          .textAlign(TextAlign.Start)
                      }
                      .padding($r('sys.float.padding_level2'))
                    }
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_last_time') }) {
                    Row() {
                      Text((this.lastSyncTime != null && this.lastSyncTime != "") ? this.lastSyncTime : $r('app.string.cloud_sync_never'))
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding($r('sys.float.padding_level2'))
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_token_count') }) {
                    Row() {
                      Text(`${this.tokenCount}`)
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding($r('sys.float.padding_level2'))
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_encryption') }) {
                    Row() {
                      Text(this.isHuaweiLoggedIn ?
                        $r('app.string.cloud_sync_encryption_huawei_account') :
                        $r('app.string.cloud_sync_encryption_none'))
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor(this.isHuaweiLoggedIn ?
                          $r('sys.color.ohos_id_color_text_primary') :
                          $r('sys.color.ohos_id_color_text_secondary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding($r('sys.float.padding_level2'))
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_network') }) {
                    Row() {
                      Row({ space: LengthMetrics.vp(6).value }) {
                        SymbolGlyph($r('sys.symbol.wifi'))
                          .fontSize(LengthMetrics.vp(16).value)
                          .fontColor([$r('app.color.str_main')])
                        Text($r('app.string.cloud_sync_wifi_only'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          .fontColor($r('sys.color.ohos_id_color_text_primary'))
                          .fontWeight(FontWeight.Medium)
                          .textAlign(TextAlign.Start)
                      }
                      .padding($r('sys.float.padding_level2'))
                    }
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: $r('app.string.cloud_sync_sync_state') }) {
                    Row() {
                      Row({ space: LengthMetrics.vp(6).value }) {
                        if (this.syncState === 0 || this.syncState === 2) {
                          LoadingProgress()
                            .width(LengthMetrics.vp(16).value)
                            .height(LengthMetrics.vp(16).value)
                            .color($r('app.color.str_main'))
                        }
                        Text(this.getSyncStateText())
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          .fontColor(this.getSyncStateColor())
                          .fontWeight(FontWeight.Medium)
                          .textAlign(TextAlign.Start)
                      }
                      .padding($r('sys.float.padding_level2'))
                    }
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                if (this.syncError !== 0) {
                  ListItem() {
                    SettingItem({ title: $r('app.string.cloud_sync_sync_error') }) {
                      Row() {
                        Text(this.getSyncErrorText())
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          .fontColor($r('sys.color.ohos_id_color_warning'))
                          .fontWeight(FontWeight.Medium)
                          .textAlign(TextAlign.Start)
                      }
                      .padding($r('sys.float.padding_level2'))
                    }
                  }
                  .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
                }

                ListItem() {
                  SettingItem({ title: '' }) {
                    SubItemButton({
                      symbol: $r('sys.symbol.mobiledata'),
                      text: $r('app.string.cloud_sync_trigger_sync')
                    })
                      .onClick(() => {
                        this.triggerFileSync();
                      })
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: '' }) {
                    SubItemButton({
                      symbol: $r('sys.symbol.arrow_clockwise'),
                      text: $r('app.string.data_sync_manual')
                    })
                      .onClick(() => {
                        this.loadingText = $r('app.string.cloud_sync_backing_up');
                        this.Is_loaded = true;
                        this.triggerCloudSync();
                      })
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: '' }) {
                    SubItemButton({
                      symbol: $r('sys.symbol.arrow_counterclockwise_clock'),
                      text: $r('app.string.cloud_backup_history_title'),
                      description: $r('app.string.cloud_backup_history_subtitle')
                    })
                      .onClick(() => {
                        this.pageInfos?.pushPathByName(ROUTE_NAMES.ShowCloudBackupHistoryPage, null);
                      })
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

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
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

                ListItem() {
                  SettingItem({ title: $r('app.string.data_dev_info') }) {
                    Row() {
                      Text(deviceInfo.marketName)
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding($r('sys.float.padding_level2'))

                    SubItemDivider()

                    Row() {
                      Text(deviceInfo.ODID)
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        .fontWeight(FontWeight.Medium)
                        .textAlign(TextAlign.Start)
                    }
                    .padding($r('sys.float.padding_level2'))
                  }
                }
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

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
      .backgroundColor($r('app.color.window_background'))
    }
    .bindToScrollable([this.scroller])
    .titleMode(HdsNavDestinationTitleMode.MODAL)
    .titleBar({
      style: {
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.icon_primary')
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
          mainTitle: $r('app.string.data_huawei_cloud_sync_details'),
        },
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
  }

  private getSyncStateText(): ResourceStr {
    if (this.syncState === 0) {
      return $r('app.string.cloud_sync_state_uploading');
    }
    if (this.syncState === 1) {
      return $r('app.string.cloud_sync_state_upload_failed');
    }
    if (this.syncState === 2) {
      return $r('app.string.cloud_sync_state_downloading');
    }
    if (this.syncState === 3) {
      return $r('app.string.cloud_sync_state_download_failed');
    }
    if (this.syncState === 4) {
      return $r('app.string.cloud_sync_state_completed');
    }
    if (this.syncState === 5) {
      return $r('app.string.cloud_sync_state_stopped');
    }
    return $r('app.string.cloud_sync_state_idle');
  }

  private getSyncStateColor(): ResourceColor {
    if (this.syncState === 1 || this.syncState === 3) {
      return $r('sys.color.ohos_id_color_warning');
    }
    if (this.syncState === 4) {
      return $r('sys.color.ohos_id_color_text_primary');
    }
    if (this.syncState === 0 || this.syncState === 2) {
      return $r('app.color.str_main');
    }
    return $r('sys.color.ohos_id_color_text_secondary');
  }

  private getSyncErrorText(): ResourceStr {
    if (this.syncError === 1) {
      return $r('app.string.cloud_sync_error_network_unavailable');
    }
    if (this.syncError === 2) {
      return $r('app.string.cloud_sync_error_wifi_unavailable');
    }
    if (this.syncError === 3) {
      return $r('app.string.cloud_sync_error_battery_low');
    }
    if (this.syncError === 4) {
      return $r('app.string.cloud_sync_error_battery_warning');
    }
    if (this.syncError === 5) {
      return $r('app.string.cloud_sync_error_cloud_full');
    }
    if (this.syncError === 6) {
      return $r('app.string.cloud_sync_error_local_full');
    }
    if (this.syncError === 7) {
      return $r('app.string.cloud_sync_error_temperature_high');
    }
    if (this.syncError === 8) {
      return $r('app.string.cloud_sync_error_server_error');
    }
    return $r('app.string.cloud_sync_error_no_error');
  }

  private triggerFileSync(): void {
    const now = Date.now();
    if (now - this.lastSyncTriggerTime < this.SYNC_COOLDOWN_MS) {
      showSnackBar($r('app.string.cloud_sync_cooldown'), SnackBarNotifyType.WARNING);
      return;
    }
    this.lastSyncTriggerTime = now;
    this.loadingText = $r('app.string.cloud_sync_syncing');
    this.Is_loaded = true;
    try {
      this.fileSync.start().then(() => {
        this.Is_loaded = false;
        showSnackBar($r('app.string.cloud_sync_started'), SnackBarNotifyType.SUCCESS);
      }).catch((err: BusinessError) => {
        this.Is_loaded = false;
        hilog.error(DOMAIN, TAG, `FileSync start failed: ${err.code} ${err.message}`);
        showSnackBar($r('app.string.cloud_sync_start_failed'), SnackBarNotifyType.WARNING);
      });
    } catch (err) {
      this.Is_loaded = false;
      let e = err as BusinessError;
      hilog.error(DOMAIN, TAG,`FileSync start exception: ${e.code} ${e.message}`);
      showSnackBar($r('app.string.cloud_sync_start_failed'), SnackBarNotifyType.WARNING);
    }
  }

  private showClearCloudStorageDialog(): void {
    if (this.cloudSyncEnabled) {
      showSnackBar($r('app.string.cloud_sync_clear_storage_disabled_msg'), SnackBarNotifyType.WARNING);
      return;
    }
    try {
      this.getUIContext().getPromptAction().showActionMenu({
        title: $r('app.string.cloud_sync_clear_storage_confirm'),
        buttons: [
          {
            text: $r('app.string.cloud_sync_clear_device'),
            color: $r('sys.color.ohos_id_color_warning'),
          },
          {
            text: $r('app.string.cloud_sync_clear_all'),
            color: $r('sys.color.ohos_id_color_warning'),
          },
        ],
      }, (err: BusinessError, data: promptAction.ActionMenuSuccessResponse) => {
        if (err) {
          return;
        }
        if (data.index === 0) {
          this.showClearConfirmDialog(false);
        } else if (data.index === 1) {
          this.showClearConfirmDialog(true);
        }
      });
    } catch (error) {
      let e = error as BusinessError;
      hilog.error(DOMAIN, TAG, `showActionMenu error: ${e.code} ${e.message}`);
    }
  }

  private showClearConfirmDialog(clearAll: boolean): void {
    const msg = clearAll
      ? $r('app.string.cloud_sync_clear_all_confirm_msg')
      : $r('app.string.cloud_sync_clear_device_confirm_msg');
    this.getUIContext().showAlertDialog({
      title: $r('app.string.cloud_sync_clear_storage_confirm'),
      message: msg,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      buttonDirection: DialogButtonDirection.HORIZONTAL,
      buttons: [
        {
          value: $r('app.string.dialog_btn_confirm'),
          action: () => {
            this.triggerClearCloudStorage(clearAll);
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

  private triggerCloudSync(): void {
    CloudBackupManager.getInstance().backupToCloud().then(success => {
      this.Is_loaded = false;
      if (success) {
        this.lastSyncTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string;
      }
    });
  }

  private triggerClearCloudStorage(clearAll: boolean): void {
    this.loadingText = $r('app.string.cloud_sync_clearing');
    this.Is_loaded = true;
    const clearPromise = clearAll
      ? CloudBackupManager.getInstance().clearCloudStorage()
      : CloudBackupManager.getInstance().clearDeviceCloudStorage();
    clearPromise.then(() => {
      this.Is_loaded = false;
      const yesterday = new Date(Date.now() - 86400000);
      const yesterdayStr = `${yesterday.getFullYear()}-${this.padZero(yesterday.getMonth() + 1)}-${this.padZero(yesterday.getDate())} 23:59`;
      AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, yesterdayStr);
      this.lastSyncTime = yesterdayStr;
      showSnackBar($r('app.string.cloud_sync_clear_storage_success'), SnackBarNotifyType.SUCCESS);
    });
  }

  private padZero(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  private startCloudSpaceSettings(): void {
  let want: Want = {
    bundleName: 'com.huawei.hmos.settings',
    abilityName: 'com.huawei.hmos.settings.MainAbility',
    //uri: 'cloudDrive'//hicloud://cloudDrive/getInfo?path=MainActivity
  };
    this.appCtx.startAbility(want).then(() => {
      hilog.info(DOMAIN, TAG, 'Start cloud space settings ability successfully.');
  }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, `Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
  });
}
}
