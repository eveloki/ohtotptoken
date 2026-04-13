import { AppStorageV2 } from '@kit.ArkUI';
import { TopNavigationView } from '../components/TopNavigationView';
import { CloudBackupManager } from '../utils/CloudBackupManager';
import { CloudBackupRecord } from '../utils/CloudBackupCrypto';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { showSnackBar, SnackBarNotifyType } from '../utils/HdsSnackBarUtils';

@Entry
@Preview
@ComponentV2
export struct ShowCloudBackupHistoryPage {
  pageInfos: NavPathStack | null = null;
  @Local backupRecords: CloudBackupRecord[] = [];
  @Local isLoading: boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  private backupManager: CloudBackupManager = CloudBackupManager.getInstance();

  aboutToAppear(): void {
    this.loadBackupHistory();
  }

  private loadBackupHistory(): void {
    this.isLoading = true;
    this.backupManager.listBackupHistory().then((records: CloudBackupRecord[]) => {
      this.backupRecords = records;
      this.isLoading = false;
    });
  }

  build() {
    NavDestination() {
      Column() {
        TopNavigationView({
          title: $r('app.string.cloud_backup_history_title'),
          onBackClick: () => {
            this.pageInfos?.pop('');
          }
        })
        RelativeContainer() {
          Stack() {
            if (this.isLoading) {
              Column() {
                LoadingProgress()
                  .color(Color.White)
                  .width(80).height(80)
              }
              .width('100%')
              .height('100%')
              .backgroundColor('#40000000')
              .justifyContent(FlexAlign.Center)
            }
            Column() {
              if (this.backupRecords.length === 0 && !this.isLoading) {
                Column() {
                  SymbolGlyph($r('sys.symbol.tray'))
                    .fontSize(48)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  Text($r('app.string.cloud_backup_history_empty'))
                    .fontSize(16)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 12 })
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
              } else {
                List({ space: 10 }) {
                  ForEach(this.backupRecords, (record: CloudBackupRecord) => {
                    ListItem() {
                      this.BackupRecordItem(record)
                    }
                  }, (record: CloudBackupRecord) => record.id)
                }
                .chainAnimation(true)
                .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
                .scrollBar(BarState.Off)
                .width('100%')
                .layoutWeight(1)
                .padding({ left: 10, right: 10, bottom: 10 })
              }

              Row() {
                Text($r('app.string.cloud_backup_history_max_hint'))
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 8, bottom: 16 })
            }
            .width('100%')
            .height('100%')
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

  @Builder
  BackupRecordItem(record: CloudBackupRecord) {
    Column() {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(24)
            .fontColor([$r('app.color.str_main')])
        }
        .width(44)
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.item_bg'))
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(record.date)
            .fontSize($r('sys.float.ohos_id_text_size_body1'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 8 }) {
            Text($r('app.string.cloud_backup_record_tokens', record.tokenCount))
              .fontSize($r('sys.float.ohos_id_text_size_caption'))
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))

            Text(this.formatSize(record.size))
              .fontSize($r('sys.float.ohos_id_text_size_caption'))
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))

            if (record.encrypted) {
              Row({ space: 2 }) {
                SymbolGlyph($r('sys.symbol.lock'))
                  .fontSize(10)
                  .fontColor([$r('app.color.str_main')])
              }
            }
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.arrow_turn_down'))
            .fontSize(20)
            .fontColor([$r('app.color.str_main')])
            .onClick(() => {
              this.showRestoreConfirmDialog(record);
            })

          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_warning')])
            .onClick(() => {
              this.showDeleteConfirmDialog(record);
            })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(12)
      .alignItems(VerticalAlign.Center)

      Row() {
        SymbolGlyph($r('sys.symbol.device_phone_portrait'))
          .fontSize(12)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
        Text(record.deviceName)
          .fontSize($r('sys.float.ohos_id_text_size_caption'))
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ left: 4 })
      }
      .padding({ left: 68, bottom: 10 })
      .width('100%')
    }
    .width('100%')
    .backgroundColor($r('app.color.item_bg'))
    .borderRadius(12)
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
        showSnackBar($r('app.string.cloud_backup_delete_success'), SnackBarNotifyType.SUCCESS);
        this.loadBackupHistory();
      } else {
        showSnackBar($r('app.string.cloud_backup_delete_failed'), SnackBarNotifyType.WARNING);
      }
    });
  }
}
