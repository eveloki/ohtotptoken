import { TokenConfig } from '../../utils/TokenConfig';
import { BusinessError } from '@kit.BasicServicesKit';
import { bundleManager,common } from '@kit.AbilityKit';
import { convertToken2URI, generateFileNameWithDate } from '../../utils/TokenUtils'
import { showSnackBar, SnackBarNotifyType } from '../../utils/HdsSnackBarUtils';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { EncryptionPassWordDialog } from '../../dialogs/EncryptionPassWordDialog';
import { restoreFromBackup, saveBackupToFile, TokenBackup } from '../../utils/TokenBackup';
import { showSaveFilePicker, showSelectFilePicker, writeFileContent } from '../../utils/FileUtils';
import { SubItemDivider } from '../../components/SubItemDivider';
import { LengthMetrics } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { CommonConstants } from '../../utils/CommonConstants';

@Preview
@ComponentV2
export struct BackupAndMigrationSheet {
  @Require @Param Tokens: Array<TokenConfig> = [];
  @Require @Param scrollEffectStyle: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Event backupReload: (conf: Array<TokenConfig>) => void = () => {};

  @Local versionCode?: number;
  private sheetScroller: Scroller = new Scroller();

  //备份时是否为导出模式
  private backup_is_input: boolean = true;
  private backup_select_uri: string = '';
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;

  aboutToAppear(): void {
    let bundleInfo = AppStorage.get<bundleManager.BundleInfo>("BundleInfo");
    this.versionCode = bundleInfo?.versionCode;
  }

  //region 加密导入导出
  private password_input_dialog: CustomDialogController | null = new CustomDialogController({
    builder: EncryptionPassWordDialog({
      cancel: () => {},
      confirm: (password: string) => {
        if (this.backup_is_input) { // 如果是导出 就要调用导出加密函数
          showSaveFilePicker([`totp_backup_${generateFileNameWithDate()}.bak`], ['BAK|.bak']).then((uris) => {
            const backup: TokenBackup = new TokenBackup(this.versionCode ?? 0, this.Tokens);
            if (uris[0] !== undefined && uris[0] !== '') {
                  saveBackupToFile(uris[0], backup, true, password).then(() => {
                    showSnackBar($r('app.string.toast_backup_success'), SnackBarNotifyType.SUCCESS);
                  }).catch((reason: BusinessError) => {
                    showSnackBar(reason.message, SnackBarNotifyType.ERROR);
                  });
            }
          });
        } else { // 加密导入
          restoreFromBackup(this.backup_select_uri, true, password).then((backup) => {
            this.backupReload(backup.configs);
          });
        }
      },
    }),
    cancel: () => {},
    autoCancel: true,
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      hilog.info(0, 'BackupAndMigrationSheet', "reason=" + JSON.stringify(dismissDialogAction.reason))
      hilog.info(0, 'BackupAndMigrationSheet', "dialog onWillDismiss")
      if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
        dismissDialogAction.dismiss()
      }
      if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
        dismissDialogAction.dismiss()
      }
    },
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -20 },
    gridCount: 4,
    customStyle: false,
    cornerRadius: 10,
  })

  async callFilePickerSaveMigrationFile(): Promise<void> {
    this.getUIContext().showAlertDialog(
      {
        title: $r('app.string.setting_migration_output'),
        subtitle: $r('app.string.setting_migration_output_des'),
        message: $r('app.string.setting_migration_output_msg'),
        autoCancel: true,
        alignment: DialogAlignment.Bottom,
        gridCount: 4,
        offset: { dx: 0, dy: -20 },
        buttonDirection: DialogButtonDirection.HORIZONTAL,
        buttons: [
          {
            value: $r('app.string.setting_migration_confirm'),
            action: () => {
              showSaveFilePicker([`totp_migration_${generateFileNameWithDate()}.txt`], ['TEXT|.txt']).then((uris) => {
                let migration_content: string = '';
                this.Tokens.forEach((token) => {
                  migration_content += convertToken2URI(token) + "\n";
                })
                if (uris[0] !== undefined && uris[0] !== '') {
                  writeFileContent(uris[0], migration_content);
                }
              });
            }
          },
          {
            value: $r('app.string.setting_backup_cancel'),
            enabled: true,
            action: () => {
              hilog.info(0, 'BackupAndMigrationSheet', 'Callback when button3 is clicked')
            }
          },
        ],
        cancel: () => {
          hilog.info(0, 'BackupAndMigrationSheet', 'Closed callbacks')
        },
        onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
          hilog.info(0, 'BackupAndMigrationSheet', "reason=" + JSON.stringify(dismissDialogAction.reason))
          hilog.info(0, 'BackupAndMigrationSheet', "dialog onWillDismiss")
          if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
            dismissDialogAction.dismiss()
          }
          if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
            dismissDialogAction.dismiss()
          }
        }
      }
    );
  }

  async callFilePickerSaveFile(): Promise<void> {
    this.getUIContext().showAlertDialog(
      {
        title: $r('app.string.setting_backup_output'),
        subtitle: $r('app.string.setting_backup_output_des'),
        message: $r('app.string.setting_backup_output_msg'),
        autoCancel: true,
        alignment: DialogAlignment.Bottom,
        gridCount: 4,
        offset: { dx: 0, dy: -20 },
        buttonDirection: DialogButtonDirection.HORIZONTAL,
        buttons: [
          {
            value: $r('app.string.setting_backup_type_default'),
            action: () => {
              showSaveFilePicker([`totp_backup_${generateFileNameWithDate()}.json`], ['JSON|.json']).then((uris) => {
                const backup: TokenBackup = new TokenBackup(this.versionCode, this.Tokens);
                if (uris[0] !== undefined && uris[0] !== '') {
                  saveBackupToFile(uris[0], backup).then(() => {
                    showSnackBar($r('app.string.toast_backup_success'), SnackBarNotifyType.SUCCESS);
                  }).catch((reason: BusinessError) => {
                    showSnackBar(reason.message, SnackBarNotifyType.ERROR);
                  });
                }
              });
            }
          },
          {
            value: $r('app.string.setting_backup_type_enc'),
            action: () => {
              this.password_input_dialog?.open();
            }
          },
          {
            value: $r('app.string.setting_backup_cancel'),
            enabled: true,
            action: () => {
              hilog.info(0, 'BackupAndMigrationSheet', 'Callback when button3 is clicked')
            }
          },
        ],
        cancel: () => {
          hilog.info(0, 'BackupAndMigrationSheet', 'Closed callbacks')
        },
        onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
          hilog.info(0, 'BackupAndMigrationSheet', "reason=" + JSON.stringify(dismissDialogAction.reason))
          hilog.info(0, 'BackupAndMigrationSheet', "dialog onWillDismiss")
          if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
            dismissDialogAction.dismiss()
          }
          if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
            dismissDialogAction.dismiss()
          }
        }
      }
    );
  }

  async callFilePickerSelectFile(): Promise<void> {
    showSelectFilePicker(1, ['JSON|.json', 'BAK|.bak']).then((uris) => {
      this.backup_select_uri = uris[0];
      if (this.backup_select_uri.endsWith('.bak')) {
        //后缀bak为加密包 唤醒加密导入弹窗
        this.password_input_dialog?.open();
      } else {
        restoreFromBackup(uris[0]).then((backup) => {
          this.backupReload(backup.configs);
        })
      }
    });
  }

  //endregion
  // 在自定义组件即将析构销毁时将dialogController置空
  aboutToDisappear() {
    this.password_input_dialog = null // 将dialogController置空
  }

  build() {
    Column() {
      HdsNavigation() {
        Column({ space: LengthMetrics.vp(12).value }) {
          List({ scroller: this.sheetScroller, space: 10 }) {
            // 顶部避让
            ListItem()
              .height(CommonConstants.AVOID_TOP_BASE_HEIGHT)

            // 选项内容
            ListItem() {
              SettingItem({ title: "" }) {
                SubItemButton({
                  symbol: $r('sys.symbol.save'),
                  text: $r('app.string.setting_backup_export')
                })
                  .onClick(() => {
                    this.backup_is_input = true;
                    this.callFilePickerSaveFile()
                  })

                SubItemDivider()

                SubItemButton({
                  symbol: $r('sys.symbol.folder'),
                  text: $r('app.string.setting_backup_import')
                })
                  .onClick(() => {
                    this.backup_is_input = false;
                    this.callFilePickerSelectFile()
                  })

                SubItemDivider()

                SubItemButton({
                  symbol: $r('sys.symbol.briefcase'),
                  text: $r('app.string.setting_migration')
                })
                  .onClick(() => {
                    this.callFilePickerSaveMigrationFile()
                  })
              }
            }
            .padding({ left: 10, right: 10 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .backgroundColor($r('app.color.window_background'))
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.window_background'))
      }
      .bindToScrollable([this.sheetScroller])
      .titleMode(HdsNavigationTitleMode.MODAL)
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
            scrollEffectType: this.scrollEffectStyle
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        content: {
          title: {
            mainTitle: $r('app.string.setting_backup'),
          },
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}
