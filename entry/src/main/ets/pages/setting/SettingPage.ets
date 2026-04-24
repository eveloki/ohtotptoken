import { TokenConfig } from '../../utils/TokenConfig';
import { BusinessError } from '@kit.BasicServicesKit';
import { bundleManager, common, ConfigurationConstant } from '@kit.AbilityKit';
import { convertToken2URI, generateFileNameWithDate } from '../../utils/TokenUtils'
import { showSnackBar, SnackBarNotifyType } from '../../utils/HdsSnackBarUtils';
import { SubItemToggle } from '../../components/SubItemToggle'
import { AppStorageV2, curves } from '@kit.ArkUI';
import { AppPreference, SettingColorMode, SettingValue, TokenPreference, EVENT_NAMES, PREF_KEYS,ROUTE_NAMES } from '../../utils/AppPreference';
import { SubItemButton } from '../../components/SubItemButton';
import { SettingItem } from '../../components/SettingItem';
import { userAuth } from '@kit.UserAuthenticationKit';
import { PermissionManager } from '../../utils/PermissionManager';
import { EncryptionPassWordDialog } from '../../dialogs/EncryptionPassWordDialog';
import { restoreFromBackup, saveBackupToFile, TokenBackup } from '../../utils/TokenBackup';
import { showSaveFilePicker, showSelectFilePicker, writeFileContent } from '../../utils/FileUtils';
import { throttle } from '../../utils/UiUtils';
import { SubItemDivider } from '../../components/SubItemDivider';
import { SubItemSelect } from '../../components/SubItemSelect';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SubItemIconManager } from '../../components/SubItemIconManager';
import { AppWindowInfo } from '../../entryability/EntryAbility';
import { MasterKeyPage } from '../MasterKeyPage';
import { RecoveryKeyRecordPage } from '../RecoveryKeyRecordPage';
import { AppearancePage } from '../AppearancePage';
import { ShowDataSyncDetailsPage } from '../ShowDataSyncDetailsPage';
import { PrivacyPage } from '../PrivacyPage';
import { AgreementPage } from '../AgreementPage';
import { FeedbackPage } from '../FeedbackPage';
import { ScrollEffectType } from '@kit.UIDesignKit';

@Preview
@ComponentV2
export struct SettingPage {
  pageInfos: NavPathStack = new NavPathStack();
  @Require @Param Tokens: Array<TokenConfig> = [];
  @Require @Param appBottomAvoidHeight: number = 0;
  @Require @Param appTopAvoidHeight: number = 0;
  @Require @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Param listScroller: Scroller = new Scroller();
  @Event backupReload: (conf: Array<TokenConfig>) => void = () => {};

  @Local versionName?: string;
  @Local appName?: string;
  @Local RdbSyncEnable: SettingValue = false;
  @Local is_loaded: boolean = false;
  @Local is_master_key_enable: boolean = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY) as boolean;
  @Local is_master_key_set: boolean = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;

  @Local debug_mode_is_on: boolean = AppPreference.getPreference(PREF_KEYS.DEBUG_MODE_ON) as boolean;
  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  //备份时是否为导出模式
  private backup_is_input: boolean = true;
  private backup_select_uri: string = '';
  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;
  private versionCode?: number;
  private str_about_app: string = '';
  private str_opensource_leg: string = '';
  private debug_mode_counter: number = 0;

  aboutToAppear(): void {
    let bundleInfo = AppStorage.get<bundleManager.BundleInfo>("BundleInfo");
    this.versionCode = bundleInfo?.versionCode;
    this.versionName = 'Version:' + bundleInfo?.versionName;
    this.appName = bundleInfo?.name;
    this.RdbSyncEnable = AppPreference.getPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE);
    //订阅权限变更
    this.appCtx.eventHub.on(EVENT_NAMES.DATASYNC_PERMISSIONS_UPDATE, this.updateDATASYNCPermissions);
  }

  //更新数据同步权限
  updateDATASYNCPermissions(isAccess: boolean) {
    if (!isAccess) {
      this.RdbSyncEnable = false;
      AppPreference.setPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE, false);
    }
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
      hilog.info(0, 'SettingPage', "reason=" + JSON.stringify(dismissDialogAction.reason))
      hilog.info(0, 'SettingPage', "dialog onWillDismiss")
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
              hilog.info(0, 'SettingPage', 'Callback when button3 is clicked')
            }
          },
        ],
        cancel: () => {
          hilog.info(0, 'SettingPage', 'Closed callbacks')
        },
        onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
          hilog.info(0, 'SettingPage', "reason=" + JSON.stringify(dismissDialogAction.reason))
          hilog.info(0, 'SettingPage', "dialog onWillDismiss")
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
              hilog.info(0, 'SettingPage', 'Callback when button3 is clicked')
            }
          },
        ],
        cancel: () => {
          hilog.info(0, 'SettingPage', 'Closed callbacks')
        },
        onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
          hilog.info(0, 'SettingPage', "reason=" + JSON.stringify(dismissDialogAction.reason))
          hilog.info(0, 'SettingPage', "dialog onWillDismiss")
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
    this.appCtx.eventHub.off(EVENT_NAMES.DATASYNC_PERMISSIONS_UPDATE, this.updateDATASYNCPermissions);
  }

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === ROUTE_NAMES.MasterKeyPage) {
      MasterKeyPage()
    } else if (name === ROUTE_NAMES.RecoveryKeyRecordPage) {
      RecoveryKeyRecordPage()
    } else if (name === ROUTE_NAMES.AppearancePage) {
      AppearancePage({scrollEffectType: this.scrollEffectType})
    } else if (name === ROUTE_NAMES.ShowDataSyncDetailsPage) {
      ShowDataSyncDetailsPage({scrollEffectType: this.scrollEffectType})
    } else if (name === ROUTE_NAMES.PrivacyPage) {
      PrivacyPage({ scrollEffectType: this.scrollEffectType })
    } else if (name === ROUTE_NAMES.AgreementPage) {
      AgreementPage({ scrollEffectType: this.scrollEffectType })
    } else if (name === ROUTE_NAMES.FeedbackPage) {
      FeedbackPage({ scrollEffectType: this.scrollEffectType })
    }
  }

  build() {
    Navigation(this.pageInfos) {
    Stack() {
      if (this.is_loaded) {
        Column() {
          LoadingProgress()
            .color(Color.White)
            .width(80).height(80)
          Text('Loading..')
            .fontSize(16)
            .fontColor(Color.White)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10, scroller: this.listScroller }) {
          ListItemGroup() {
            ListItem() {

            }
          }

          ListItem() {
            SettingItem({ title: $r('app.string.setting_backup') }) {
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

          ListItem() {
            SettingItem({ title: $r('app.string.setting_safety') }) {
              SubItemToggle({
                icon: $r('sys.symbol.staroflife_rectangle'),
                title: $r('app.string.restore_master_key'),
                isOn: AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY) as boolean,
                description: $r('app.string.restore_master_key_msg'),
                onChange: (IsOn: boolean) => {
                  this.window.uiContext?.animateTo({ curve: curves.springMotion() }, () => {
                    this.is_master_key_enable = IsOn;
                  })
                  AppPreference.setPreference(PREF_KEYS.USE_MASTER_KEY, IsOn);
                }
              })
              if (this.is_master_key_enable) {
                SubItemDivider()
                SubItemButton({
                  symbol: $r('sys.symbol.key_shield'),
                  text: $r('app.string.restore_master_key_set'),
                  description:this.is_master_key_set?$r('app.string.restore_master_key_reset_desc'):$r('app.string.restore_master_key_no_set_desc'),
                  descriptionColor:this.is_master_key_set?$r('sys.color.ohos_id_color_text_secondary'):$r('app.color.token_progress_next_color_end')
                })
                  .onClick(throttle((event) => {
                    this.pageInfos.pushPathByName(ROUTE_NAMES.MasterKeyPage,null);
                  }, 1000))
              }

              SubItemDivider()

              SubItemToggle({
                icon: $r('sys.symbol.hand_raised_hexagon'),
                title: $r('app.string.setting_safety_privacy'),
                isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_PRIVACY_ENABLE) as boolean,
                description: $r('app.string.setting_safety_privacy_des'),
                onChange: (IsOn: boolean) => {
                  AppPreference.setPreference(PREF_KEYS.SAFETY_PRIVACY_ENABLE, IsOn);
                  try {
                    this.window.WindowClass?.setWindowPrivacyMode(IsOn).catch((err: BusinessError) => {
                      hilog.error(err.code, 'SettingPage', `Failed to set the window to privacy mode. Cause code: ${err.code}, message: ${err.message}`);
                    });
                  } catch (exception) {
                    hilog.error(exception.code, 'SettingPage', `Failed to set the window to privacy mode. Cause code: ${exception.code}, message: ${exception.message}`);
                  }
                }
              })

              SubItemDivider()

              SubItemToggle({
                icon: $r('sys.symbol.key_shield'),
                title: $r('app.string.setting_safety_lock'),
                isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_LOCK_ENABLE) as boolean,
                description: $r('app.string.setting_safety_lock_des'),
                onChange: (IsOn: boolean) => {
                  if (IsOn) {
                    try {
                      userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
                    } catch (err) {
                      const error = err as BusinessError;
                      showSnackBar(error.message, SnackBarNotifyType.ERROR);
                      return;
                    }
                  }
                  AppPreference.setPreference(PREF_KEYS.SAFETY_LOCK_ENABLE, IsOn);
                }
              })

              SubItemDivider()

              SubItemToggle({
                icon: $r('sys.symbol.eye_slash'),
                title: $r('app.string.setting_hide_token'),
                isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_HIDE_TOKEN_ENABLE) as boolean,
                description: $r('app.string.setting_safety_hide_token_des'),
                onChange: (IsOn: boolean) => {
                  AppPreference.setPreference(PREF_KEYS.SAFETY_HIDE_TOKEN_ENABLE, IsOn);
                  this.token_preference.app_safety_hide_token_enable = IsOn;
                }
              })

              SubItemDivider()

              SubItemToggle({
                icon: $r('sys.symbol.blur_bar'),
                title: $r('app.string.setting_background_blur'),
                isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_BACKGROUND_BLUR_ENABLE) as boolean,
                description: $r('app.string.setting_background_blur_des'),
                onChange: (IsOn: boolean) => {
                  AppPreference.setPreference(PREF_KEYS.SAFETY_BACKGROUND_BLUR_ENABLE, IsOn);
                }
              })
            }
          }
          .padding({ left: 10, right: 10 })

          ListItem() {
            SettingItem({ title: $r('app.string.app_appearance') }) {
              SubItemToggle({
                icon: $r('sys.symbol.chevron_up_2_circle'),
                title: $r('app.string.show_next_token'),
                isOn: AppPreference.getPreference(PREF_KEYS.APPEARANCE_SHOW_NEXT_TOKEN_ENABLE) as boolean,
                description: $r('app.string.show_next_token_des'),
                onChange: (IsOn: boolean) => {
                  AppPreference.setPreference(PREF_KEYS.APPEARANCE_SHOW_NEXT_TOKEN_ENABLE, IsOn);
                  this.token_preference.app_appearance_show_next_token_enable = IsOn;
                }
              })

              SubItemDivider()

              SubItemToggle({
                icon: $r('sys.symbol.hand_draw'),
                title: $r('app.string.setting_holding_hand_awareness'),
                isOn: AppPreference.getPreference(PREF_KEYS.APPEARANCE_HOLDING_HAND_ENABLE) as boolean,
                description: $r('app.string.setting_holding_hand_awareness_des'),
                onChange: (IsOn: boolean) => {
                  AppPreference.setPreference(PREF_KEYS.APPEARANCE_HOLDING_HAND_ENABLE, IsOn);
                  this.token_preference.app_appearance_holding_hand_enable = IsOn;
                  this.appCtx.eventHub.emit(EVENT_NAMES.HOLDING_HAND_PREFERENCE_CHANGED, IsOn);
                }
              })

              SubItemDivider()

              if (this.debug_mode_is_on) {
                SubItemToggle({
                  icon: $r('sys.symbol.gearshape'),
                  title: $r('app.string.debug_mode'),
                  isOn: AppPreference.getPreference(PREF_KEYS.DEBUG_MODE_ON) as boolean,
                  description: $r('app.string.debug_mode_des'),
                  onChange: (IsOn: boolean) => {
                    this.window.uiContext?.animateTo({ curve: curves.springMotion() }, () => {
                      this.debug_mode_is_on = IsOn;
                    })
                    AppPreference.setPreference(PREF_KEYS.DEBUG_MODE_ON, IsOn);
                  }
                })

                SubItemDivider()
              }

              SubItemToggle({
                icon: $r('sys.symbol.face'),
                title: $r('app.string.auto_unlock'),
                isOn: AppPreference.getPreference(PREF_KEYS.SAFETY_AUTO_UNLOCK_ENABLE) as boolean,
                description: $r('app.string.auto_unlock_des'),
                onChange: (IsOn: boolean) => {
                  AppPreference.setPreference(PREF_KEYS.SAFETY_AUTO_UNLOCK_ENABLE, IsOn);
                }
              })

              SubItemDivider()

              SubItemSelect({
                icon: $r('sys.symbol.dark'),
                title: $r('app.string.setting_color_mode'),
                values: [$r('app.string.setting_color_mode_system'), $r('app.string.setting_color_mode_dark'),
                  $r('app.string.setting_color_mode_light'),],
                description: $r('app.string.setting_color_mode_desc'),
                selected: AppPreference.getPreference(PREF_KEYS.APPEARANCE_COLOR_MODE) as number ??
                SettingColorMode.System,
                onChange: (index: number) => {
                  AppPreference.setPreference(PREF_KEYS.APPEARANCE_COLOR_MODE, index);
                  const color_map: Map<SettingColorMode, ConfigurationConstant.ColorMode> = new Map([
                    [SettingColorMode.System, ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET],
                    [SettingColorMode.Dark, ConfigurationConstant.ColorMode.COLOR_MODE_DARK],
                    [SettingColorMode.Light, ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT],
                  ]);
                  this.appCtx.getApplicationContext().setColorMode(color_map.get(index));
                }
              })

              SubItemDivider()

              SubItemIconManager()

              SubItemDivider()

              SubItemButton({
                symbol: $r("sys.symbol.paintpalette"),
                text: $r('app.string.customize_appearance')
              })
                .onClick(throttle((event) => {
                  this.pageInfos.pushPathByName(ROUTE_NAMES.AppearancePage,null);
                }, 1000))
            }
          }
          .padding({ left: 10, right: 10 })

          ListItem() {
            SettingItem({ title: $r('app.string.data_sync') }) {
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
                    this.pageInfos.pushPathByName(ROUTE_NAMES.ShowDataSyncDetailsPage,null);
                }, 1000))
            }
          }
          .padding({ left: 10, right: 10 })

          ListItem() {
            SettingItem({ title: $r('app.string.setting_agreement_statement') }) {
              SubItemButton({ symbol: $r("sys.symbol.person_shield"), text: $r('app.string.privacy_statement') })
                .onClick(throttle((event) => {
                    this.pageInfos.pushPathByName(ROUTE_NAMES.PrivacyPage,null);
                }, 1000))

              SubItemDivider()

              SubItemButton({
                symbol: $r("sys.symbol.doc_plaintext_and_pencil"),
                text: $r('app.string.user_agreement')
              })
                .onClick(throttle((event) => {
                  this.pageInfos.pushPathByName(ROUTE_NAMES.AgreementPage,null);
                }, 1000))

            }
          }
          .padding({ left: 10, right: 10 })

          ListItem() {
            SettingItem({ title: $r('app.string.setting_about') }) {
              Text(this.str_about_app)
                .fontSize(10)
                .fontColor($r('app.color.str_gray'))
                .padding(10)
            }
          }
          .padding({ left: 10, right: 10 })
          .onClick(() => {
            if (!this.debug_mode_is_on) {
              setTimeout(() => {
                this.debug_mode_counter = 0;
              }, 2000);
              if (this.debug_mode_counter > 7) {
                  this.window.uiContext?.animateTo({ curve: curves.springMotion() }, () => {
                    this.debug_mode_is_on = true;
                    AppPreference.setPreference(PREF_KEYS.DEBUG_MODE_ON, true);
                    showSnackBar('DEBUG MODE ON', SnackBarNotifyType.INFO);
                  })

              }
              this.debug_mode_counter++;
            }
          })

          ListItem() {
            SettingItem({ title: $r('app.string.setting_opensource_leg') }) {
              Text(this.str_opensource_leg)
                .fontSize(10)
                .fontColor($r('app.color.str_gray'))
                .padding(10)
            }
          }
          .padding({ left: 10, right: 10 })

          ListItemGroup() {
            ListItem() {
              Row() {
                //Hyperlink('https://github.com/SolidFaker/ohtotptoken/issues', $r('app.string.app_issue_feedback'))
                //  .height(10)
                //  .padding({ left: 10 })
                Hyperlink('https://beian.miit.gov.cn/', '粤ICP备2020075515号-2A')
                  .height(10)
                  .padding({ left: 10 })
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
            }
            .padding({ left: 10, right: 10 })
          }

          ListItemGroup() {
            ListItem() {
              Row()
                .width('100%')
                .height(this.appBottomAvoidHeight + 60)
            }
          }
        }
        .chainAnimation(true)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      }
    }
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.navDestinationBuilder)
  }
}
