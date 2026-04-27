import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import { CloudBackupManager } from '../utils/CloudBackupManager';
import { CloudBackupRecord } from '../utils/CloudBackupCrypto';
import { AppPreference, PREF_KEYS } from '../utils/AppPreference';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { showSnackBar, SnackBarNotifyType } from '../utils/HdsSnackBarUtils';
import { hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { CommonConstants } from '../utils/CommonConstants';
import { DeviceInfoHelper } from '../utils/DeviceInfoHelper';

@Entry
@Preview
@ComponentV2
export struct ShowCloudBackupHistoryPage {
  pageInfos: NavPathStack | null = null;
  @Require @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Local backupRecords: CloudBackupRecord[] = [];
  @Local isLoading: boolean = true;
  @Local currentDeviceId: string = '';
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private backupManager: CloudBackupManager = CloudBackupManager.getInstance();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.currentDeviceId = DeviceInfoHelper.getInstance().getDeviceId();
    this.loadBackupHistory();
  }

  private loadBackupHistory(): void {
    this.isLoading = true;
    this.backupManager.listBackupHistory().then((records: CloudBackupRecord[]) => {
      this.backupRecords = records;
      this.isLoading = false;
    });
  }

  private getDeviceRecords(): CloudBackupRecord[] {
    return this.backupRecords.filter(r => r.deviceId === this.currentDeviceId);
  }

  private getOtherDeviceRecords(): CloudBackupRecord[] {
    return this.backupRecords.filter(r => r.deviceId !== this.currentDeviceId);
  }

  build() {
    HdsNavDestination() {
      Column() {
        RelativeContainer() {
          Stack() {
            if (this.isLoading) {
              Column() {
                LoadingProgress()
                  .color($r('sys.color.font_primary'))
                  .width(LengthMetrics.vp(80).value).height(LengthMetrics.vp(80).value)
              }
              .width('100%')
              .height('100%')
              .backgroundColor('#40000000')
              .justifyContent(FlexAlign.Center)
            }
            else
            {
              Column() {
                if (this.backupRecords.length === 0 && !this.isLoading) {
                  Column() {
                    SymbolGlyph($r('sys.symbol.rectangle_split_3x1'))
                      .fontSize(LengthMetrics.vp(48).value)
                      .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                    Text($r('app.string.cloud_backup_history_empty'))
                      .fontSize($r('sys.float.ohos_id_text_size_body1'))
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .margin({ top: $r('sys.float.padding_level2') })
                  }
                  .width('100%')
                  .layoutWeight(1)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                } else {
                  List({ space: LengthMetrics.vp(10).value, scroller: this.scroller }) {
                    ListItem()
                      .height(CommonConstants.AVOID_TOP_BASE_HEIGHT)

                    if (this.getDeviceRecords().length > 0) {
                      ListItem() {
                        Row() {
                          Text($r('app.string.cloud_backup_this_device'))
                            .fontSize($r('sys.float.ohos_id_text_size_sub_title2'))
                            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                            .fontWeight(FontWeight.Medium)
                        }
                        .width('100%')
                        .padding({ left: $r('sys.float.padding_level8'), top: LengthMetrics.vp(4).value, bottom: LengthMetrics.vp(2).value })
                      }

                      ForEach(this.getDeviceRecords(), (record: CloudBackupRecord) => {
                        ListItem() {
                          this.BackupRecordItem(record, true)
                        }
                      }, (record: CloudBackupRecord) => record.id)
                    }

                    if (this.getOtherDeviceRecords().length > 0) {
                      ListItem() {
                        Row() {
                          Text($r('app.string.cloud_backup_other_devices'))
                            .fontSize($r('sys.float.ohos_id_text_size_sub_title2'))
                            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                            .fontWeight(FontWeight.Medium)
                        }
                        .width('100%')
                        .padding({ left: $r('sys.float.padding_level8'), top: $r('sys.float.padding_level2'), bottom: LengthMetrics.vp(2).value })
                      }

                      ForEach(this.getOtherDeviceRecords(), (record: CloudBackupRecord) => {
                        ListItem() {
                          this.BackupRecordItem(record, false)
                        }
                      }, (record: CloudBackupRecord) => record.id)
                    }
                  }
                  .chainAnimation(true)
                  .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
                  .scrollBar(BarState.Off)
                  .backgroundColor($r('app.color.window_background'))
                  .width('100%')
                  .layoutWeight(1)
                  .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8'), bottom: $r('sys.float.padding_level8') })
                }

                Row() {
                  Text($r('app.string.cloud_backup_history_max_hint'))
                    .fontSize($r('sys.float.ohos_id_text_size_caption'))
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ bottom: $r('sys.float.padding_level2') })

                Row() {
                  Text($r('app.string.cloud_sync_device_id_hint'))
                    .fontSize($r('sys.float.ohos_id_text_size_caption'))
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .width('100%')
                .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8'), bottom: $r('sys.float.padding_level8') })
              }
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
          mainTitle: $r('app.string.cloud_backup_history_title'),
        },
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
  }

  @Builder
  BackupRecordItem(record: CloudBackupRecord, isCurrentDevice: boolean) {
    Column() {
      Row({ space: LengthMetrics.vp(12).value }) {
        Column() {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(LengthMetrics.vp(24).value)
            .fontColor([$r('app.color.str_main')])
        }
        .width(LengthMetrics.vp(44).value)
        .height(LengthMetrics.vp(44).value)
        .borderRadius($r('sys.float.corner_radius_level4'))
        .backgroundColor($r('app.color.item_bg'))
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column({ space: LengthMetrics.vp(4).value }) {
          Text(record.date)
            .fontSize($r('sys.float.ohos_id_text_size_body1'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: LengthMetrics.vp(8).value }) {
            Text($r('app.string.cloud_backup_record_tokens', record.tokenCount))
              .fontSize($r('sys.float.ohos_id_text_size_caption'))
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))

            Text(this.formatSize(record.size))
              .fontSize($r('sys.float.ohos_id_text_size_caption'))
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))

            if (record.encrypted) {
              Row({ space: LengthMetrics.vp(2).value }) {
                SymbolGlyph($r('sys.symbol.lock'))
                  .fontSize(LengthMetrics.vp(10).value)
                  .fontColor([$r('app.color.str_main')])
              }
            }
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: LengthMetrics.vp(6).value }) {
          SymbolGlyph($r('sys.symbol.arrowshape_down_to_line_fill'))
            .fontSize(LengthMetrics.vp(20).value)
            .fontColor([$r('app.color.str_main')])
            .onClick(() => {
              this.showRestoreConfirmDialog(record);
            })

          if (isCurrentDevice) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(LengthMetrics.vp(20).value)
              .fontColor([$r('sys.color.ohos_id_color_warning')])
              .onClick(() => {
                this.showDeleteConfirmDialog(record);
              })
          }
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding($r('sys.float.padding_level8'))
      .alignItems(VerticalAlign.Center)

      Row() {
        SymbolGlyph($r('sys.symbol.icloud'))
          .fontSize(LengthMetrics.vp(12).value)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
        Text(record.deviceName)
          .fontSize($r('sys.float.ohos_id_text_size_caption'))
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ left: LengthMetrics.vp(4).value })

          Text('·')
          .fontSize($r('sys.float.ohos_id_text_size_caption'))
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ left: LengthMetrics.vp(4).value, right: LengthMetrics.vp(4).value })

        if (record.location === 2) {
          SymbolGlyph($r('sys.symbol.arrow_down_circle'))
            .fontSize(LengthMetrics.vp(12).value)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          Text($r('app.string.cloud_sync_status_cloud_only'))
            .fontSize($r('sys.float.ohos_id_text_size_caption'))
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ left: LengthMetrics.vp(2).value })
        } else {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(LengthMetrics.vp(12).value)
            .fontColor([$r('app.color.str_main')])
          Text($r('app.string.cloud_sync_status_synced'))
            .fontSize($r('sys.float.ohos_id_text_size_caption'))
            .fontColor($r('app.color.str_main'))
            .margin({ left: LengthMetrics.vp(2).value })
        }
      }
      .padding({ left: LengthMetrics.vp(68).value, bottom: LengthMetrics.vp(10).value })
      .width('100%')
    }
    .width('100%')
    .backgroundColor($r('app.color.item_bg'))
    .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
    .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 10, offsetY: 10 })
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    return `${(bytes / 1024).toFixed(1)} KB`;
  }

  private showRestoreConfirmDialog(record: CloudBackupRecord): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.cloud_backup_restore_confirm_title'),
      message: $r('app.string.cloud_backup_restore_confirm_msg', record.date),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      buttonDirection: DialogButtonDirection.HORIZONTAL,
      buttons: [
        {
          value: $r('app.string.dialog_btn_confirm'),
          action: () => {
            this.triggerRestore(record.id);
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

  private showDeleteConfirmDialog(record: CloudBackupRecord): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.cloud_backup_delete_confirm_title'),
      message: $r('app.string.cloud_backup_delete_confirm_msg', record.date),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      buttonDirection: DialogButtonDirection.HORIZONTAL,
      buttons: [
        {
          value: $r('app.string.dialog_btn_confirm'),
          action: () => {
            this.triggerDelete(record.id);
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

  private triggerRestore(recordId: string): void {
    this.isLoading = true;
    this.backupManager.restoreFromBackupRecord(recordId).then((success: boolean) => {
      this.isLoading = false;
      if (success) {
        showSnackBar($r('app.string.cloud_backup_restore_success'), SnackBarNotifyType.SUCCESS);
      } else {
        showSnackBar($r('app.string.cloud_backup_restore_failed'), SnackBarNotifyType.WARNING);
      }
    });
  }

  private triggerDelete(recordId: string): void {
    this.isLoading = true;
    this.backupManager.deleteBackupRecord(recordId).then((success: boolean) => {
      this.isLoading = false;
      if (success) {
        this.updateLastSyncTimeAfterDelete(recordId);
        showSnackBar($r('app.string.cloud_backup_delete_success'), SnackBarNotifyType.SUCCESS);
        this.loadBackupHistory();
      } else {
        showSnackBar($r('app.string.cloud_backup_delete_failed'), SnackBarNotifyType.WARNING);
      }
    });
  }

  private updateLastSyncTimeAfterDelete(deletedRecordId: string): void {
    const lastTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string;
    if (!lastTime || lastTime.length < 10) {
      return;
    }
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${this.padZero(today.getMonth() + 1)}-${this.padZero(today.getDate())}`;
    if (!lastTime.startsWith(todayStr)) {
      return;
    }
    let deletedIsToday = false;
    for (const record of this.backupRecords) {
      if (record.id === deletedRecordId) {
        const recordDate = `${new Date(record.timestamp).getFullYear()}-${this.padZero(new Date(record.timestamp).getMonth() + 1)}-${this.padZero(new Date(record.timestamp).getDate())}`;
        if (recordDate === todayStr) {
          deletedIsToday = true;
        }
        break;
      }
    }
    if (!deletedIsToday) {
      return;
    }
    let latestRemaining: string = '';
    for (const record of this.backupRecords) {
      if (record.id === deletedRecordId) {
        continue;
      }
      const recordDate = `${new Date(record.timestamp).getFullYear()}-${this.padZero(new Date(record.timestamp).getMonth() + 1)}-${this.padZero(new Date(record.timestamp).getDate())}`;
      if (recordDate === todayStr) {
        latestRemaining = record.date;
        break;
      }
    }
    if (latestRemaining.length > 0) {
      AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, latestRemaining);
    } else {
      const yesterday = new Date(today.getTime() - 86400000);
      const yesterdayStr = `${yesterday.getFullYear()}-${this.padZero(yesterday.getMonth() + 1)}-${this.padZero(yesterday.getDate())} 23:59`;
      AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, yesterdayStr);
    }
  }

  private padZero(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }
}
