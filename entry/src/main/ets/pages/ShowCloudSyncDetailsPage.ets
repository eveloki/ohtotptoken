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

import { AppStorageV2 } from '@kit.ArkUI';
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
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.cloudSyncEnabled = AppPreference.getPreference(PREF_KEYS.APPEARANCE_HUAWEI_CLOUD_SYNC_ENABLE);
    this.lastSyncTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string ?? '';
    this.syncHuaweiAccountState();
    TokenStore.getInstance().getTokens().then(tokens => {
      this.tokenCount = tokens.length;
    });
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
                  .width(80).height(80)
                Text('Backing up...')
                  .fontSize(16)
                  .fontColor(Color.White)
              }
              .width('100%')
              .height('100%')
              .backgroundColor('#40000000')
              .justifyContent(FlexAlign.Center)
            } else {
              List({ space: 10, scroller: this.scroller }) {
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
                        Text(this.isHuaweiLoggedIn ?
                          this.huaweiNickname : $r('app.string.cloud_sync_not_logged_in'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          .fontColor(this.isHuaweiLoggedIn ?
                            $r('sys.color.ohos_id_color_text_primary') :
                            $r('sys.color.ohos_id_color_text_secondary'))
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
                      Text((this.lastSyncTime != null && this.lastSyncTime != "") ? this.lastSyncTime : $r('app.string.cloud_sync_never'))
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
                        this.triggerCloudSync();
                      })
                  }
                }
                .padding({ left: 10, right: 10 })

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
            this.triggerClearCloudStorage();
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

  private triggerClearCloudStorage(): void {
    this.Is_loaded = true;
    CloudBackupManager.getInstance().clearCloudStorage().then(() => {
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
}
