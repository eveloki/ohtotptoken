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

/**
 * 华为云备份详情页面
 *
 * 显示云备份相关状态信息和提供操作入口：
 * - 备份状态：显示是否启用云备份
 * - 华为账号：显示登录状态
 * - 最后备份时间：显示上次备份时间
 * - 已备份令牌数量：显示已备份的令牌数量
 * - 加密方式：显示是否使用主密码加密
 * - 网络要求：显示仅在 WiFi 下备份
 * - 手动备份：触发立即备份到云端
 * - 备份历史：查看、恢复、删除历史备份
 * - 清空云端备份：删除所有云端备份
 * - 设备信息：显示设备名称和设备ID
 *
 * @module ShowCloudSyncDetailsPage
 */

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

/**
 * 华为云备份详情页面组件
 */
@Entry
@Preview
@ComponentV2
export struct ShowCloudSyncDetailsPage {
  /** 导航栈 */
  pageInfos: NavPathStack | null = null;
  /** 云同步是否启用 */
  @Local cloudSyncEnabled: SettingValue = false;
  /** 是否已设置主密码 */
  @Local masterKeySet: boolean = false;
  /** 最后同步时间 */
  @Local lastSyncTime: string = '';
  /** 令牌数量 */
  @Local tokenCount: number = 0;
  /** 是否正在加载/同步 */
  @Local Is_loaded: boolean = false;
  /** 窗口信息 */
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  /**
   * 页面即将显示时调用
   * 初始化页面状态数据
   */
  aboutToAppear(): void {
    this.cloudSyncEnabled = AppPreference.getPreference(PREF_KEYS.APPEARANCE_HUAWEI_CLOUD_SYNC_ENABLE);
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
                Text('Backing up...')
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

  /**
   * 显示清空云存储确认对话框
   * 
   * 如果云同步已启用，则提示用户先禁用云同步
   * 否则显示确认对话框，用户确认后执行清空操作
   */
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

  /**
   * 触发云端备份
   * 调用 CloudBackupManager.backupToCloud() 备份令牌数据到云端
   * 备份完成后更新最后同步时间
   */
  private triggerCloudSync(): void {
    CloudBackupManager.getInstance().backupToCloud().then(success => {
      this.Is_loaded = false;
      if (success) {
        this.lastSyncTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string;
      }
    });
  }

  /**
   * 触发清空云存储
   * 调用 CloudBackupManager.clearCloudStorage() 删除所有云端备份
   * 清空完成后重置最后同步时间并显示成功提示
   */
  private triggerClearCloudStorage(): void {
    this.Is_loaded = true;
    CloudBackupManager.getInstance().clearCloudStorage().then(() => {
      this.Is_loaded = false;
      this.lastSyncTime = '';
      showSnackBar($r('app.string.cloud_sync_clear_storage_success'), SnackBarNotifyType.SUCCESS);
    });
  }
}
