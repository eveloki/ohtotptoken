import { bundleManager,common } from '@kit.AbilityKit';
import { TokenConfig } from '../utils/TokenConfig';
import { SettingPage } from '../pages/setting/SettingPage'
import { BackupAndMigrationSheet } from '../pages/setting/BackupAndMigrationSheet'
import { SecuritySheet } from '../pages/setting/SecuritySheet'
import { AppearanceSheet } from '../pages/setting/AppearanceSheet'
import { DataSyncSheet } from '../pages/setting/DataSyncSheet'
import { AgreementSheet } from '../pages/setting/AgreementSheet'
import { AboutSheet } from '../pages/setting/AboutSheet'
import { FeedbackSheet } from '../pages/setting/FeedbackSheet'
import { util, url } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { showSnackBar, SnackBarNotifyType } from '../utils/HdsSnackBarUtils';
import { AppPreference, TokenPreference, SettingTopEffectType, SettingBottomTabsType, SCROLL_EFFECT_TYPE_MAP, EVENT_NAMES, PREF_KEYS,ROUTE_NAMES } from '../utils/AppPreference';
import { privacyManager } from '@kit.StoreKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import CommonEventManager from '@ohos.commonEventManager';
import { TokenStore } from '../utils/TokenStore';
import { PermissionManager } from '../utils/PermissionManager';
import { DropFilesDialog } from '../dialogs/DropFilesDialog';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { EncryptionPassWordDialog } from '../dialogs/EncryptionPassWordDialog';
import { restoreFromBackup,saveBackupToFile,TokenBackup } from '../utils/TokenBackup';
import { TokenIconPacks } from '../utils/TokenUtils';
import { DeviceInfoHelper } from '../utils/DeviceInfoHelper';
import { CloudBackupManager } from '../utils/CloudBackupManager';
// 申请锁屏下应用敏感数据访问权限
import { screenLockFileManager } from '@kit.AbilityKit';
import { TokenListPage } from './TokenListPage';
import { RestoreDataPage } from './RestoreDataPage';
import { MasterKeyPage } from './MasterKeyPage';
import { RecoveryKeyRecordPage } from './RecoveryKeyRecordPage';
import { AppearancePage } from './AppearancePage';
import { ShowDataSyncDetailsPage } from './ShowDataSyncDetailsPage';
import { ShowCloudSyncDetailsPage } from './ShowCloudSyncDetailsPage';
import { ShowCloudBackupHistoryPage } from './ShowCloudBackupHistoryPage';
import { ShowCodePage } from './ShowCodePage';
import { WebPage, WebPageParams } from './WebPage';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { AppLockOverlay } from './AppLockOverlay';
import { AppStorageV2, ComponentContent, SymbolGlyphModifier, window } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs,
  ScrollEffectType, HdsListItemCard,
  PrefixIcon,
  IconSize,
  SuffixArrow,
  hdsMaterial} from '@kit.UIDesignKit';
import { ArcTokenListPage } from './ArcTokenListPage';
import { LengthMetrics } from '@kit.ArkUI';
import { decodeProtobuf } from '../utils/GoogleAuthUtils';
import { TOTPConfigDialog } from '../dialogs/OTPConfigDialog';
import { URIConfigDialog } from '../dialogs/URIConfigDialog';
import { FortiConfigDialog } from '../dialogs/FortiConfigDialog';
import { SteamConfigDialog } from '../dialogs/SteamConfigDialog';
import { ScanBarCode } from '../utils/TokenUtils';
import { CommonConstants } from '../utils/CommonConstants';
import { HuaweiAccountManager, HuaweiUserInfo, HuaweiAccountLoginError } from '../utils/HuaweiAccountManager';

const TAG = 'PrivacySubscribe';

let tkStore = TokenStore.getInstance();

@Builder
function TokenAddMenuBuilder(host: Index) {
  Menu() {
    MenuItem({ content: $r('app.string.app_scan_code') })
      .onClick(() => {
        host.start_quick_scan();
      })
      .accessibilityText($r('app.string.app_scan_code'))
    MenuItem({ content: $r('app.string.tab_token_add_key') })
      .onClick(() => {
        host.openTotpAddDialog();
      })
      .accessibilityText($r('app.string.tab_token_add_key'))
    MenuItem({ content: $r('app.string.tab_token_add_uri') })
      .onClick(() => {
        host.openUriAddDialog();
      })
      .accessibilityText($r('app.string.tab_token_add_uri'))
    MenuItem({ content: $r('app.string.tab_token_add_forti_key') })
      .onClick(() => {
        host.openFortiAddDialog();
      })
      .accessibilityText($r('app.string.tab_token_add_forti_key'))
    MenuItem({ content: $r('app.string.tab_token_add_stream_key') })
      .onClick(() => {
        host.openSteamAddDialog();
      })
      .accessibilityText($r('app.string.tab_token_add_stream_key'))
  }
}

@Entry
@ComponentV2
struct Index {
  @Local CurrentTokens: TokenConfig[] = [];
  @Local tab_bar_index: number = 0;
  @Local token_loading: Boolean = true;
  @Local background_blur_flag: Boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local appCtx: common.UIAbilityContext = AppStorage.get('appContext') as common.UIAbilityContext;
  @Local tokenListScroller: Scroller = new Scroller();
  @Local arcTokenListScroller: Scroller = new Scroller();
  @Local settingEntryScroller: Scroller = new Scroller();
  @Local isSettingSheetVisible: boolean = false;
  @Local isBackupSheetVisible: boolean = false;
  @Local isSafetySheetVisible: boolean = false;
  @Local isAppearanceSheetVisible: boolean = false;
  @Local isDataSyncSheetVisible: boolean = false;
  @Local isAgreementSheetVisible: boolean = false;
  @Local isAboutSheetVisible: boolean = false;
  @Local isFeedbackSheetVisible: boolean = false;
  @Local isHuaweiLoggedIn: boolean = false;
  @Local huaweiUser: HuaweiUserInfo | null = null;
  @Local isAccountSheetVisible: boolean = false;
  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local CurrentTokensCount: number = 0;
  @Local scrollEffectVersion: number = 0;
  @Local isAppLockOverlayVisible: boolean = false;
  pageInfos: NavPathStack = new NavPathStack();

  /**
   * 获取当前的滚动效果类型
   * 根据用户设置的顶部效果类型映射到对应的ScrollEffectType
   */
  @Computed
  get currentScrollEffectType(): ScrollEffectType {
    // 依赖scrollEffectVersion以触发重新计算
    const _ = this.scrollEffectVersion;
    const topEffectType = AppPreference.getPreference(PREF_KEYS.APPEARANCE_TOP_EFFECT_TYPE) as SettingTopEffectType;
    return SCROLL_EFFECT_TYPE_MAP.get(topEffectType) ?? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  }

  private appIsInit = false;
  private appIsShow = false;
  private icon_pack_dir = this.appCtx.filesDir + "/icon_packs";
  private user_icon_dir = this.appCtx.filesDir + "/user_icons";
  private DropFilesDialogIsOpen:boolean = false;

  private readonly eventId = 'usual.event.PRIVACY_STATE_CHANGED';
  // 订阅者信息, 用于保存创建成功的订阅者对象，后续使用其完成订阅及退订的动作
  private subscriber: CommonEventManager.CommonEventSubscriber | undefined = undefined;
  // 事件列表
  private subscribeInfo: CommonEventManager.CommonEventSubscribeInfo = {
    events: [this.eventId]
  };
  //拖拽文件弹框
  private DropFilesDialogController: CustomDialogController | null = new CustomDialogController({
    builder: DropFilesDialog({}),
    cancel: () => {},
    autoCancel: true,
    openAnimation:({
      delay: 0,
      duration: 200, // 动画时长
      curve: Curve.EaseInOut, // 动画曲线
    }),
    closeAnimation:({
      delay: 0,
      duration: 200, // 动画时长
      curve: Curve.EaseInOut, // 动画曲线
    }),
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      hilog.info(0, 'Index', "reason=" + JSON.stringify(dismissDialogAction.reason))
      hilog.info(0, 'Index', "dialog onWillDismiss")
      this.DropFilesDialogIsOpen=false;
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

  private backup_select_uri: string = '';
  private readonly addTokenMenuTargetId: string = 'app_ua_add_token';
  private dialog_uri_config?: CustomDialogController;
  private dialog_totp_config?: CustomDialogController;
  private dialog_forti_config?: CustomDialogController;
  private dialog_steam_config?: CustomDialogController;

  aboutToAppear(): void {
    const accountInitPromise = HuaweiAccountManager.getInstance().init().then(() => {
      this.syncHuaweiAccountState();
    });
    const tokenStoreInitPromise = tkStore.initTokenStore().then(() => {
      if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.TOKEN_CHANGED, () => this.onTokenChanged());
      if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.TOP_EFFECT_TYPE_CHANGED, () => {
        this.scrollEffectVersion++;
      });
      return tkStore.getTokens().then((tokens) => {
        this.CurrentTokens = tokens;
        this.CurrentTokensCount = tokens.length;
        this.token_loading = false;
        this.restoreByKVCheck();
        this.appIsInit = true;
        AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING, false)
      });
    });

    Promise.all([accountInitPromise, tokenStoreInitPromise]).then(() => {
      CloudBackupManager.getInstance().checkAndAutoBackup();
    });

    this.subscribeDistributedAccountLogout();
    PermissionManager.getInstance().verifyPermissionsAndPushEvent();
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).then((bundleInfo) => {
      AppStorage.setOrCreate("BundleInfo", bundleInfo);
    });
    AppStorage.setOrCreate("AppPrivacyManageInfoUrl",
      'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1537746898868267328');
    fs.access(this.icon_pack_dir).then((res) => {
      if (!res) {
        fs.mkdir(this.icon_pack_dir);
      } else {
        if (TokenIconPacks.aegis_icon_packs.length === 0) {
          this.refreshIconPack();
        }
      }
    });

    // save certification for forti token
    let cer_path = this.appCtx.filesDir + "/fmt.ks"
    fs.access(cer_path, fs.AccessModeType.EXIST).then((exist) => {
      if (!exist) {
        fs.open(cer_path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE).then((cer_file) => {
          let arr = this.appCtx.resourceManager.getRawFileContentSync('ftm.ks')
          fs.write(cer_file.fd, arr.buffer).then((cnt) => {
            hilog.info(0, 'Index', 'store fmt.ks to cache dir')
          })
            .catch((err:BusinessError) => {
              hilog.error(err.code, 'Index', `${err.message}`)
            })
        })
      }
    })
    DeviceInfoHelper.getInstance().init();
    this.GetPrivacyManageInfo();
    // 订阅KV数据库同步完成事件
    if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.KV_STORE_SYNC_COMPLETE,() => {
      AppPreference.setPreference(PREF_KEYS.DB_KV_SYNC_TIME, Date().toString());
    })

    //订阅RDB数据库同步完成事件
    if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.RDB_STORE_SYNC_COMPLETE,() => {
      //todo 接收同步完成后刷新数据
    })

    //订阅权限变更 主页面不需要取消订阅 没有意义
    if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.DATASYNC_PERMISSIONS_UPDATE, (isAccess: boolean) => {
      if (!isAccess) {
        //如果数据同步权限被关闭 则需要将两个同步都关闭
        AppPreference.setPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE, false);
        AppPreference.setPreference(PREF_KEYS.DB_RDS_CLOUD_SYNC_ENABLE, false);
      }
    })

    if (this.appCtx.eventHub != undefined) this.appCtx.eventHub.on(EVENT_NAMES.START_QUICK_SCAN, () => {
      this.start_quick_scan();
    });

    if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.FILE_DROP, (uri: string) => {
      this.backup_select_uri = uri;
      if (this.backup_select_uri.endsWith('.bak')) { // 后缀bak为加密包 唤醒加密导入弹窗
        this.password_input_dialog?.open();
      } else if (this.backup_select_uri.endsWith('.json')) {
        restoreFromBackup(uri).then((backup) => {
          this.updateTokenConfigs(backup.configs).then(() => {
            tkStore.sortTokens();
          });
        });
      }
      setTimeout(() => {
        this.DropFilesDialogIsOpen = false;
        this.DropFilesDialogController?.close();
        }, 250)
    });

    // periodically update timestamp for tokens
    setInterval(() => {
      if (this.appCtx != undefined && this.appIsShow)
        if (this.appCtx.eventHub != undefined)
           this.updateTimestamp();
    }, 1000);
  }

  //region 导入
  private password_input_dialog: CustomDialogController | null = new CustomDialogController({
    builder: EncryptionPassWordDialog({
      cancel: () => {},
      confirm: (password: string) => {
        restoreFromBackup(this.backup_select_uri, true, password).then((backup) => {
          this.updateTokenConfigs(backup.configs).then(() => {
            tkStore.sortTokens();
          });
        });
      },
    }),
    cancel: () => {},
    autoCancel: true,
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      hilog.info(0, 'Index', "reason=" + JSON.stringify(dismissDialogAction.reason))
      hilog.info(0, 'Index', "dialog onWillDismiss")
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

  refreshIconPack(): void {
    TokenIconPacks.addUserIconPack(this.user_icon_dir);
    fs.listFile(this.icon_pack_dir).then((paths) => {
      paths.forEach((path) => {
        TokenIconPacks.addAegisIconPack(this.icon_pack_dir + "/" + path);
      })
    });
  }

  updateTimestamp(): void {
    const timestamp = Math.floor(systemDateTime.getTime() / 1000);
    if (this.appCtx.eventHub != undefined) {
      this.appCtx.eventHub.emit(EVENT_NAMES.TIMESTAMP_CHANGED, timestamp, false);
    }
  }

  restoreByKVCheck():void{
    //冷启动优化
    setTimeout(() => {
      tkStore.RestoreByKVCheckAsync().then((n:number)=>{
        if (this.CurrentTokens.length == 0 && n>0) {
          this.pageInfos.pushPathByName(ROUTE_NAMES.RestoreDataPage, null);
        }
      }).catch((err:BusinessError)=>{
        hilog.error(err.code,"RestoreByKVCheckAsync",err.message)
      })
    }, 1000)

  }

  onPageHide(): void {
    this.appIsShow = false;
    hilog.info(0, TAG, "onPageHide");
    //备份还原场景检测是否有备份数据
    if (this.CurrentTokens.length > 0 && this.appIsInit && !AppPreference.getPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING)) {
      //todo需要申请锁屏后读取权限 需要实现后台任务备份
      try {
        AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING,true)
        //申请锁屏后访问加密文件的权限
        let acquireStatus = screenLockFileManager.acquireAccess();
        if (acquireStatus === screenLockFileManager.AccessStatus.ACCESS_GRANTED) {
          hilog.info(0x0000, 'testTag', 'acquireAccess successfully.');
          //let thisContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
          tkStore.BuckupToKVAsync().then((n)=>{
            //tkStore.RestoreByKVAsync();
            //更新存档时间
            if (n > 0) {
              AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_TIME, Date().toString());
            }
          }).catch((err:BusinessError) => {
            hilog.error(err.code,"BuckupToKVAsync",`${err.message}`)
          }).finally(() => {
            AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING, false);
          });
        }
        else
        {
          AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING, false);
        }
      } catch (err) {
        let message = (err as BusinessError).message;
        hilog.error(0x0000, 'testTag', 'acquireAccess failed: %{public}s', message);
        AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING, false);
      }

    }
  }

  onPageShow(): void {
    this.appIsShow = true;
    const needShowLock = AppStorage.get<boolean>('app_lock_need_show') ?? false;
    if (!needShowLock) {
      this.pageInfos.clear();
    }
    if (needShowLock && AppPreference.getPreference(PREF_KEYS.SAFETY_LOCK_ENABLE)) {
      this.isAppLockOverlayVisible = true;
    }
    AppStorage.setOrCreate('app_lock_need_show', false);
    const timestamp = Math.floor(systemDateTime.getTime() / 1000);
    if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.emit(EVENT_NAMES.TIMESTAMP_CHANGED, timestamp, true);
    //页面打开的时候刷新token
    tkStore.LoadTokenByDataBase().then(() => {
      // 接收同步完成后刷新数据
      tkStore.getTokens().then((tokens) => {
        this.CurrentTokens = tokens;
        this.token_loading = false;
      });
    });

    let context = this.appCtx as common.UIAbilityContext;
    let windowStage = context.windowStage;
    windowStage.on("windowStageEvent", (data) => {
      this.background_blur_flag = (
        AppPreference.getPreference(PREF_KEYS.SAFETY_BACKGROUND_BLUR_ENABLE) as boolean &&
        data === window.WindowStageEventType.PAUSED
      );
    })

    if (AppPreference.getPreference(PREF_KEYS.WANT_QUICK_SCAN)) {
      if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.emit(EVENT_NAMES.START_QUICK_SCAN);
      AppPreference.setPreference(PREF_KEYS.WANT_QUICK_SCAN, false);
    }
  }

  async onTokenChanged(): Promise<void> {
    this.CurrentTokens = await tkStore.getTokens();
  }

  async updateTokenConfig(conf: TokenConfig, toast: boolean = true): Promise<void> {
    await tkStore.updateToken(conf);
    if (toast) {
      showSnackBar($r('app.string.toast_token_update', conf.TokenIssuer, conf.TokenName), SnackBarNotifyType.SUCCESS);
    }
  }

  async updateTokenConfigs(tokens: Array<TokenConfig>): Promise<void> {
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i].TokenUUID === undefined) {
        tokens[i].TokenUUID = util.generateRandomUUID();
      }
      await this.updateTokenConfig(tokens[i], false);
    }
    showSnackBar($r('app.string.toast_multi_token_update', tokens.length), SnackBarNotifyType.SUCCESS);
  }

  private syncHuaweiAccountState(): void {
    this.isHuaweiLoggedIn = HuaweiAccountManager.getInstance().userLogin;
    this.huaweiUser = HuaweiAccountManager.getInstance().userAccount;
  }

  private async triggerHuaweiLogin(): Promise<void> {
    try {
      const result = await HuaweiAccountManager.getInstance().login(this.getUIContext());
      this.syncHuaweiAccountState();
      this.isAccountSheetVisible = true;
    } catch (error) {
      this.syncHuaweiAccountState();
      const loginError = error as HuaweiAccountLoginError;
      if (HuaweiAccountManager.isUserCancel(loginError.code)) {
        return;
      }
      const errorMsg = HuaweiAccountManager.getLoginErrorResource(loginError.code);
      if (errorMsg) {
        showSnackBar(errorMsg, SnackBarNotifyType.ERROR);
      }
    }
  }

  private confirmHuaweiLogin(): void {
    HuaweiAccountManager.getInstance().selectHuaweiAccountToLogin();
    this.syncHuaweiAccountState();
    this.isAccountSheetVisible = false;
    showSnackBar($r('app.string.huawei_account_login_success'), SnackBarNotifyType.SUCCESS);
  }

  private showLogoutConfirmDialog(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.huawei_account_logout_confirm_title'),
      message: $r('app.string.huawei_account_logout_confirm_msg'),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      buttonDirection: DialogButtonDirection.HORIZONTAL,
      buttons: [
        {
          value: $r('app.string.dialog_btn_confirm'),
          action: () => {
            HuaweiAccountManager.getInstance().logout().then(() => {
              this.syncHuaweiAccountState();
              this.isAccountSheetVisible = false;
            });
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

  private subscribeDistributedAccountLogout(): void {
    const subscribeInfo: CommonEventManager.CommonEventSubscribeInfo = {
      events: [
        CommonEventManager.Support.COMMON_EVENT_DISTRIBUTED_ACCOUNT_LOGOUT,
      ],
    };
    CommonEventManager.createSubscriber(subscribeInfo).then((subscriber) => {
      CommonEventManager.subscribe(subscriber, (err) => {
        if (!err) {
          HuaweiAccountManager.getInstance().logout().then(() => {
            this.syncHuaweiAccountState();
          });
        }
      });
    });
  }

  private openAddTokenMenu(): void {
    const uiContext = this.getUIContext();
    const promptAction = uiContext.getPromptAction();
    const contentNode = new ComponentContent(uiContext, wrapBuilder(TokenAddMenuBuilder), this);
    try {
      promptAction.openMenu(contentNode, { id: this.addTokenMenuTargetId }, {});
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(err.code, 'Index', `openAddTokenMenu failed: ${err.message}`);
    }
  }

  start_quick_scan() {
    ScanBarCode().then((code) => {
      if (code.startsWith('otpauth-migration://offline?data=')) {
        const data = new url.URLParams(url.URL.parseURL(code).search).get('data');
        decodeProtobuf(decodeURIComponent(data ?? '')).then((confs) => {
          this.updateTokenConfigs(confs);
        });
      } else if (code.startsWith('otpauth://')) {
        this.dialog_totp_config = new CustomDialogController({
          builder: TOTPConfigDialog({
            scan_code_original_Value: code,
            confirm: (new_conf) => {
              this.updateTokenConfig(JSON.parse(new_conf), true)
            }
          })
        })
        this.dialog_totp_config.open()
      }
    });
  }

  openTotpAddDialog(): void {
    this.dialog_totp_config = new CustomDialogController({
      builder: TOTPConfigDialog({
        confirm: (new_conf) => {
          this.updateTokenConfig(JSON.parse(new_conf), true)
        }
      })
    })
    this.dialog_totp_config.open()
  }

  openUriAddDialog(): void {
    this.dialog_uri_config = new CustomDialogController({
      builder: URIConfigDialog({
        confirm: (tokens) => {
          this.updateTokenConfigs(tokens);
        }
      })
    })
    this.dialog_uri_config.open()
  }

  openFortiAddDialog(): void {
    this.dialog_forti_config = new CustomDialogController({
      builder: FortiConfigDialog({
        confirm: (new_conf) => {
          this.updateTokenConfig(JSON.parse(new_conf), true)
        }
      })
    })
    this.dialog_forti_config.open()
  }

  openSteamAddDialog(): void {
    this.dialog_steam_config = new CustomDialogController({
      builder: SteamConfigDialog({
        confirm: (new_conf) => {
          this.updateTokenConfig(JSON.parse(new_conf), true)
        }
      })
    })
    this.dialog_steam_config.open()
  }

  // 准备接入标准化隐私托管
  async GetPrivacyManageInfo(): Promise<void> {
    try {
      let appPrivacyManageInfo: privacyManager.AppPrivacyMgmtInfo = privacyManager.getAppPrivacyMgmtInfo();
      hilog.info(0, 'TAG', "Succeeded in getting AppPrivacyManageInfo type: " + appPrivacyManageInfo["type"]);
      let privacyLinkInfoArray : privacyManager.AppPrivacyLink[] = appPrivacyManageInfo.privacyInfo;
      hilog.info(0, 'TAG', "Succeeded in getting AppPrivacyManageInfo size = " + privacyLinkInfoArray.length);
      for (let i = 0; i < privacyLinkInfoArray.length; i++) {
        hilog.info(0, 'TAG', "Succeeded in getting AppPrivacyManageInfo type = " + privacyLinkInfoArray[i]["type"] + ", version = " + privacyLinkInfoArray[i]["versionCode"] + ", url = " + privacyLinkInfoArray[i]["url"]);

      }
      AppStorage.setOrCreate("AppPrivacyManageInfoUrl", privacyLinkInfoArray[0]["url"]);
    } catch (error) {
      hilog.error(0, 'TAG', "GetAppPrivacyManageInfoPublic exception code: " + error.code + ", exception message: " + error.message);
    }

    hilog.info(0, TAG, "subscribe");
    // 创建订阅者
    CommonEventManager.createSubscriber(this.subscribeInfo).then((commonEventSubscriber) => {
      hilog.info(0, TAG, "createSubscriber");
      this.subscriber = commonEventSubscriber;

      // 订阅公共事件
      try {
        CommonEventManager.subscribe(this.subscriber, (err, data) => {
          if (err) {
            hilog.error(0, TAG, `subscribe failed, code is ${err?.code}, message is ${err?.message}`);
            return;
          }

          let result = JSON.parse(data?.data ?? '{}')?.resultType as number;
          if (result === 1) {
            //向用户申请权限
            //PermissionManager.reqPermissionsFromUser(this.appCtx);
          }
        });
      } catch (error) {
        hilog.error(0, TAG, "init createSubscriber failed, exception code: " + error.code + ", exception message: " + error.message);
      }
    });
  }

  @Builder
  SettingSheetBuilder() {
  SettingPage({
      Tokens: this.CurrentTokens,
      appBottomAvoidHeight: this.window.AvoidBottomHeight,
      appTopAvoidHeight: 0,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      listScroller: this.settingEntryScroller,
      backupReload: async (conf) => {
        await this.updateTokenConfigs(conf);
        tkStore.sortTokens();
      }
    })
      .height('100%')
  }

  @Builder
  BackupAndMigrationSheetBuilder() {
    BackupAndMigrationSheet({
      Tokens: this.CurrentTokens,
      scrollEffectStyle: this.currentScrollEffectType,
      backupReload: async (conf) => {
        await this.updateTokenConfigs(conf);
        tkStore.sortTokens();
      }
    })
      .height('100%')
  }

  @Builder
  SecuritySheetBuilder() {
    SecuritySheet({
      scrollEffectStyle: this.currentScrollEffectType,
    })
      .height('100%')
  }

  @Builder
  AppearanceSheetBuilder() {
    AppearanceSheet({
      scrollEffectType: this.currentScrollEffectType,
    })
      .height('100%')
  }

  @Builder
  DataSyncSheetBuilder() {
    DataSyncSheet({
      scrollEffectType: this.currentScrollEffectType,
    })
      .height('100%')
  }

  @Builder
  AgreementSheetBuilder() {
    AgreementSheet({
      scrollEffectType: this.currentScrollEffectType,
    })
      .height('100%')
  }

  @Builder
  AboutSheetBuilder() {
    AboutSheet({
      scrollEffectStyle: this.currentScrollEffectType,
    })
      .height('100%')
  }

  @Builder
  FeedbackSheetBuilder() {
    FeedbackSheet({
      scrollEffectType: this.currentScrollEffectType,
    })
      .height('100%')
  }

  @Builder
  AppLockOverlayBuilder() {
    AppLockOverlay({
      onUnlock: () => {
        this.isAppLockOverlayVisible = false;
      }
    })
  }

  @Builder
  AccountSheetBuilder() {
    Column() {
      Column() {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
          .fontSize($r('sys.float.Display_L'))
          .fontColor([$r('sys.color.icon_emphasize')])
          .aspectRatio(1)

        Text(this.isHuaweiLoggedIn ?
          $r('app.string.huawei_account_current') :
          $r('app.string.huawei_account_select_title'))
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .margin({ top: $r('sys.float.padding_level10') })

        if (this.huaweiUser) {
          if (this.huaweiUser.avatarUri !== '') {
            Image(this.huaweiUser.avatarUri)
              .draggable(false)
              .width(85)
              .height(85)
              .borderRadius(42.5)
              .margin({ top: 40 })
          } else if (this.huaweiUser.nickname !== '') {
            Text(this.huaweiUser.nickname.length > 0 ?
              this.huaweiUser.nickname.substring(this.huaweiUser.nickname.length - 1) : '')
              .width(85)
              .height(85)
              .borderRadius(42.5)
              .backgroundColor($r('sys.color.ohos_id_color_tertiary'))
              .linearGradient({
                colors: [
                  [$r('sys.color.ohos_id_color_tertiary'), 0.0],
                  [$r('sys.color.ohos_id_color_foreground_contrary'), 1.0]
                ]
              })
              .fontColor($r('sys.color.font_on_primary'))
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Center)
              .margin({ top: 40 })
          }

          Text(this.huaweiUser.nickname)
            .margin({ top: $r('sys.float.padding_level12') })
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
        }
      }
      .margin({ top: $r('sys.float.padding_level16') })

      Blank();

      Button(this.isHuaweiLoggedIn ?
        $r('app.string.huawei_account_logout') :
        $r('app.string.huawei_account_select_to_login'))
        .type(ButtonType.Capsule)
        .fontSize($r('sys.float.Body_L'))
        .role(this.isHuaweiLoggedIn ? ButtonRole.ERROR : ButtonRole.NORMAL)
        .buttonStyle(this.isHuaweiLoggedIn ? ButtonStyleMode.NORMAL : ButtonStyleMode.EMPHASIZED)
        .width('100%')
        .margin({ bottom: $r('sys.float.padding_level5') })
        .onClick(() => {
          if (this.isHuaweiLoggedIn) {
            this.showLogoutConfirmDialog();
          } else {
            this.confirmHuaweiLogin();
          }
        })
    }
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    .width('100%')
    .height('100%')
  }

  @Builder
  SettingEntryCardBuilder() {
    List({ space: 10, scroller: this.settingEntryScroller }) {
      // 顶部占位空间，用于触发渐变模糊效果
      ListItem() {
        Column()
          .width('100%')
          .height(CommonConstants.AVOID_TOP_BASE_HEIGHT + this.window.AvoidTopHeight)
      }

      // 华为账号登录卡片
      ListItem() {
        Row({ space: 16 }) {
          if (this.isHuaweiLoggedIn && this.huaweiUser && this.huaweiUser.avatarUri !== '') {
            Image(this.huaweiUser.avatarUri)
              .draggable(false)
              .width(48)
              .height(48)
              .borderRadius(24)
          } else if (this.isHuaweiLoggedIn && this.huaweiUser && this.huaweiUser.nickname !== '') {
            Text(this.huaweiUser.nickname.length > 0 ?
              this.huaweiUser.nickname.substring(this.huaweiUser.nickname.length - 1) : '')
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor($r('sys.color.ohos_id_color_tertiary'))
              .linearGradient({
                colors: [
                  [$r('sys.color.ohos_id_color_tertiary'), 0.0],
                  [$r('sys.color.ohos_id_color_foreground_contrary'), 1.0]
                ]
              })
              .fontColor($r('sys.color.font_on_primary'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Center)
          } else {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
              .fontSize(48)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }

          Column({ space: 4 }) {
            Text(this.isHuaweiLoggedIn && this.huaweiUser ?
              this.huaweiUser.nickname : $r('app.string.huawei_account_login'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.isHuaweiLoggedIn ?
              $r('app.string.huawei_account_current') :
              $r('app.string.huawei_account_login_desc'))
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .alignItems(VerticalAlign.Center)
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
        .onClick(() => {
          if (!this.isHuaweiLoggedIn) {
            this.triggerHuaweiLogin();
          } else {
            this.isAccountSheetVisible = true;
          }
        })
        .bindSheet($$this.isAccountSheetVisible, this.AccountSheetBuilder(), {
          detents: [SheetSize.MEDIUM],
          preferType: SheetType.BOTTOM,
          dragBar: true,
        })
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })

      // 备份与迁移入口
      ListItem() {
        Column() {
          HdsListItemCard({
            cardPrefixMargin: $r('sys.float.padding_level2'),
            cardSuffixMargin: $r('sys.float.padding_level2'),
            cardBackgroundColor: $r('app.color.item_bg'),
            cardHeight: CommonConstants.SETTING_OPTION_CARD_HEIGHT,
            prefixItem: new PrefixIcon({
              iconSize: IconSize.SYSTEM_ICON,
              iconValue: {
                symbol: $r('sys.symbol.save')
              }
            }),
            textItem: {
              primaryText: {
                text: $r('app.string.setting_backup')
              }
            },
            suffixItem: new SuffixArrow({}),
            onClick: () => {
              this.isBackupSheetVisible = true;
            }
          })
            .bindSheet($$this.isBackupSheetVisible, this.BackupAndMigrationSheetBuilder(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.BOTTOM,
              dragBar: true,
            })
        }
        .padding({
          top: $r('sys.float.padding_level2'),
          bottom: $r('sys.float.padding_level2'),
        })
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })

      // 安全性入口
      ListItem() {
        Column() {
          HdsListItemCard({
            cardPrefixMargin: $r('sys.float.padding_level2'),
            cardSuffixMargin: $r('sys.float.padding_level2'),
            cardBackgroundColor: $r('app.color.item_bg'),
            cardHeight: CommonConstants.SETTING_OPTION_CARD_HEIGHT,
            prefixItem: new PrefixIcon({
              iconSize: IconSize.SYSTEM_ICON,
              iconValue: {
                symbol: $r('sys.symbol.staroflife_rectangle')
              }
            }),
            textItem: {
              primaryText: {
                text: $r('app.string.setting_safety')
              }
            },
            suffixItem: new SuffixArrow({}),
            onClick: () => {
              this.isSafetySheetVisible = true;
            }
          })
            .bindSheet($$this.isSafetySheetVisible, this.SecuritySheetBuilder(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.BOTTOM,
              dragBar: true,
            })
        }
        .padding({
          top: $r('sys.float.padding_level2'),
          bottom: $r('sys.float.padding_level2'),
        })
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })

      // 外观与功能入口
      ListItem() {
        Column() {
          HdsListItemCard({
            cardPrefixMargin: $r('sys.float.padding_level2'),
            cardSuffixMargin: $r('sys.float.padding_level2'),
            cardBackgroundColor: $r('app.color.item_bg'),
            cardHeight: CommonConstants.SETTING_OPTION_CARD_HEIGHT,
            prefixItem: new PrefixIcon({
              iconSize: IconSize.SYSTEM_ICON,
              iconValue: {
                symbol: $r('sys.symbol.chevron_up_2_circle')
              }
            }),
            textItem: {
              primaryText: {
                text: $r('app.string.app_appearance')
              }
            },
            suffixItem: new SuffixArrow({}),
            onClick: () => {
              this.isAppearanceSheetVisible = true;
            }
          })
            .bindSheet($$this.isAppearanceSheetVisible, this.AppearanceSheetBuilder(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.BOTTOM,
              dragBar: true,
            })
        }
        .padding({
          top: $r('sys.float.padding_level2'),
          bottom: $r('sys.float.padding_level2'),
        })
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })

      // 数据同步入口
      ListItem() {
        Column() {
          HdsListItemCard({
            cardPrefixMargin: $r('sys.float.padding_level2'),
            cardSuffixMargin: $r('sys.float.padding_level2'),
            cardBackgroundColor: $r('app.color.item_bg'),
            cardHeight: CommonConstants.SETTING_OPTION_CARD_HEIGHT,
            prefixItem: new PrefixIcon({
              iconSize: IconSize.SYSTEM_ICON,
              iconValue: {
                symbol: $r('sys.symbol.link')
              }
            }),
            textItem: {
              primaryText: {
                text: $r('app.string.data_sync')
              }
            },
            suffixItem: new SuffixArrow({}),
            onClick: () => {
              this.isDataSyncSheetVisible = true;
            }
          })
            .bindSheet($$this.isDataSyncSheetVisible, this.DataSyncSheetBuilder(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.BOTTOM,
              dragBar: true,
            })
        }
        .padding({
          top: $r('sys.float.padding_level2'),
          bottom: $r('sys.float.padding_level2'),
        })
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })

      // 协议与声明入口
      ListItem() {
        Column() {
          HdsListItemCard({
            cardPrefixMargin: $r('sys.float.padding_level2'),
            cardSuffixMargin: $r('sys.float.padding_level2'),
            cardBackgroundColor: $r('app.color.item_bg'),
            cardHeight: CommonConstants.SETTING_OPTION_CARD_HEIGHT,
            prefixItem: new PrefixIcon({
              iconSize: IconSize.SYSTEM_ICON,
              iconValue: {
                symbol: $r('sys.symbol.person_shield')
              }
            }),
            textItem: {
              primaryText: {
                text: $r('app.string.setting_agreement_statement')
              }
            },
            suffixItem: new SuffixArrow({}),
            onClick: () => {
              this.isAgreementSheetVisible = true;
            }
          })
            .bindSheet($$this.isAgreementSheetVisible, this.AgreementSheetBuilder(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.BOTTOM,
              dragBar: true,
            })
        }
        .padding({
          top: $r('sys.float.padding_level2'),
          bottom: $r('sys.float.padding_level2'),
        })
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })

      // 建议与反馈入口
      ListItem() {
        Column() {
          HdsListItemCard({
            cardPrefixMargin: $r('sys.float.padding_level2'),
            cardSuffixMargin: $r('sys.float.padding_level2'),
            cardBackgroundColor: $r('app.color.item_bg'),
            cardHeight: CommonConstants.SETTING_OPTION_CARD_HEIGHT,
            prefixItem: new PrefixIcon({
              iconSize: IconSize.SYSTEM_ICON,
              iconValue: {
                symbol: $r('sys.symbol.envelope')
              }
            }),
            textItem: {
              primaryText: {
                text: $r('app.string.setting_feedback')
              }
            },
            suffixItem: new SuffixArrow({}),
            onClick: () => {
              this.isFeedbackSheetVisible = true;
            }
          })
            .bindSheet($$this.isFeedbackSheetVisible, this.FeedbackSheetBuilder(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.BOTTOM,
              dragBar: true,
            })
        }
        .padding({
          top: $r('sys.float.padding_level2'),
          bottom: $r('sys.float.padding_level2'),
        })
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })

      // 关于入口
      ListItem() {
        Column() {
          HdsListItemCard({
            cardPrefixMargin: $r('sys.float.padding_level2'),
            cardSuffixMargin: $r('sys.float.padding_level2'),
            cardBackgroundColor: $r('app.color.item_bg'),
            cardHeight: CommonConstants.SETTING_OPTION_CARD_HEIGHT,
            prefixItem: new PrefixIcon({
              iconSize: IconSize.SYSTEM_ICON,
              iconValue: {
                symbol: $r('sys.symbol.info_circle')
              }
            }),
            textItem: {
              primaryText: {
                text: $r('app.string.setting_about')
              }
            },
            suffixItem: new SuffixArrow({}),
            onClick: () => {
              this.isAboutSheetVisible = true;
            }
          })
            .bindSheet($$this.isAboutSheetVisible, this.AboutSheetBuilder(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.BOTTOM,
              dragBar: true,
            })
        }
        .padding({
          top: $r('sys.float.padding_level2'),
          bottom: $r('sys.float.padding_level2'),
        })
        .borderRadius($r('sys.float.ohos_id_menu_outer_border_radius'))
        .backgroundColor($r('app.color.item_bg'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })
    }
    .chainAnimation(true)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .backgroundColor($r('app.color.window_background'))
  }

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === ROUTE_NAMES.RestoreDataPage) {
      RestoreDataPage()
    } else if (name === ROUTE_NAMES.MasterKeyPage) {
      MasterKeyPage()
    } else if (name === ROUTE_NAMES.RecoveryKeyRecordPage) {
      RecoveryKeyRecordPage()
    } else if (name === ROUTE_NAMES.AppearancePage) {
      AppearancePage({ scrollEffectType: this.currentScrollEffectType })
    } else if (name === ROUTE_NAMES.ShowDataSyncDetailsPage) {
      ShowDataSyncDetailsPage({ scrollEffectType: this.currentScrollEffectType })
    } else if (name === ROUTE_NAMES.ShowCloudSyncDetailsPage) {
      ShowCloudSyncDetailsPage({ scrollEffectType: this.currentScrollEffectType })
    } else if (name === ROUTE_NAMES.ShowCloudBackupHistoryPage) {
      ShowCloudBackupHistoryPage({ scrollEffectType: this.currentScrollEffectType })
    } else if (name === ROUTE_NAMES.ShowCodePage) {
      ShowCodePage()
    } else if (name === ROUTE_NAMES.WebPage) {
      WebPage({ scrollEffectType: this.currentScrollEffectType, pageParams: param as WebPageParams })
    }
  }

  build() {
    Navigation(this.pageInfos) {
    Stack() {
      if (this.token_loading) {
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
      .backgroundColor('#40000000')
      .justifyContent(FlexAlign.Center)
    } else if (
      (this.window.HeightBreakpoint === HeightBreakpoint.HEIGHT_MD) &&
        this.window.WidthBreakpoint === WidthBreakpoint.WIDTH_XS
    ) {
      HdsNavigation() {
        ArcTokenListPage({
          Tokens: this.CurrentTokens,
          TabBarVisible: false,
          appBottomAvoidHeight: this.window.AvoidBottomHeight,
          appTopAvoidHeight: this.window.AvoidTopHeight,
          appWindowSize: this.window.Size,
          updateTokenConfig: this.updateTokenConfig,
          updateTokenConfigs: this.updateTokenConfigs,
          listScroller: this.arcTokenListScroller,
        })
      }
      .bindToScrollable([this.arcTokenListScroller])
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true) // 设置mini类型隐藏后退按钮
      .titleBar({
        avoidLayoutSafeArea: true, // 状态栏安全区沉浸
        style: {
          originalStyle: {
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary'),
              },
              menuStyle: {
                iconColor: $r('sys.color.icon_primary')
              },
            }
          },
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: this.currentScrollEffectType,
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        content: {
          title: {
            mainTitle: $r('app.string.EntryAbility_label')
          },
          menu: {
            value: [
              {
                content: {
                  label: $r('app.string.app_ua_search_token'),
                  icon: $r('sys.symbol.magnifyingglass'),
                  isEnabled: true,
                  action: () => {
                    if (this.appCtx.eventHub != undefined) this.appCtx.eventHub.emit(EVENT_NAMES.TOGGLE_TOKEN_SEARCH);
                  }
                }
              }
            ]
          }
        }
      })
    } else if (
      (this.window.HeightBreakpoint === HeightBreakpoint.HEIGHT_MD ||
        this.window.HeightBreakpoint === HeightBreakpoint.HEIGHT_SM) &&
        this.window.WidthBreakpoint === WidthBreakpoint.WIDTH_SM
    ) {
      HdsNavigation() {
        Column() {
          TokenListPage({
            Tokens: this.CurrentTokens,
            TabBarVisible: false,
            appBottomAvoidHeight: this.window.AvoidBottomHeight,
            appTopAvoidHeight: this.window.AvoidTopHeight,
            appWindowSize: this.window.Size,
            updateTokenConfig: this.updateTokenConfig,
            updateTokenConfigs: this.updateTokenConfigs,
            listScroller: this.tokenListScroller,
          })
        }
        .backgroundColor($r('app.color.window_background'))

      }
      .bindToScrollable([this.tokenListScroller])
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true) // 设置mini类型隐藏后退按钮
      .titleBar({
        avoidLayoutSafeArea: true, // 状态栏安全区沉浸
        style: {
          originalStyle: {
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary'),
              },
              menuStyle: {
                iconColor: $r('sys.color.icon_primary')
              },
            }
          },
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: this.currentScrollEffectType // 渐变模糊
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        content: {
          title: {
            mainTitle: $r('app.string.EntryAbility_label')
          },
          menu: {
            value: [
              {
                content: {
                  label: $r('app.string.app_ua_search_token'),
                  icon: $r('sys.symbol.magnifyingglass'),
                  isEnabled: true,
                  action: () => {
                    if (this.appCtx.eventHub != undefined) this.appCtx.eventHub.emit(EVENT_NAMES.TOGGLE_TOKEN_SEARCH);
                  }
                }
              },
              {
                content: {
                  label: $r('app.string.app_ua_add_token'),
                  icon: $r('sys.symbol.plus'),
                  isEnabled: true,
                  componentId: this.addTokenMenuTargetId,
                  action: () => {
                    this.openAddTokenMenu();
                  }
                }
              }
            ]
          }
        }
      })

    } else {

      Column() {
        HdsTabs({ index: this.tab_bar_index }) {
          TabContent() {
            HdsNavigation() {
              TokenListPage({
                Tokens: this.CurrentTokens,
                TabBarVisible: true,
                appBottomAvoidHeight: this.window.AvoidBottomHeight,
                appTopAvoidHeight: this.window.AvoidTopHeight,
                appWindowSize: this.window.Size,
                updateTokenConfig: this.updateTokenConfig,
                updateTokenConfigs: this.updateTokenConfigs,
                listScroller: this.tokenListScroller,
              })
            }
            .bindToScrollable([this.tokenListScroller])
            .titleMode(HdsNavigationTitleMode.MINI)
            .hideBackButton(true) // 设置mini类型隐藏后退按钮
            .titleBar({
              avoidLayoutSafeArea: true, // 状态栏安全区沉浸
              style: {
                originalStyle: {
                  contentStyle: {
                    titleStyle: {
                      mainTitleColor: $r('sys.color.font_primary'),
                    },
                    menuStyle: {
                      iconColor: $r('sys.color.icon_primary')
                    },
                  }
                },
                scrollEffectOpts: {
                  enableScrollEffect: true,
                  scrollEffectType: this.currentScrollEffectType // 渐变模糊
                },
                systemMaterialEffect: {
                  materialType: hdsMaterial.MaterialType.ADAPTIVE,
                  materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                }
              },
              content: {
                title: {
                  mainTitle: $r('app.string.EntryAbility_label'),
                },
                menu: {
                  value: [
                    {
                      content: {
                        label: $r('app.string.app_ua_search_token'),
                        icon: $r('sys.symbol.magnifyingglass'),
                        isEnabled: true,
                        action: () => {
                          if (this.appCtx.eventHub != undefined) this.appCtx.eventHub.emit(EVENT_NAMES.TOGGLE_TOKEN_SEARCH);
                        }
                      }
                    },
                    {
                      content: {
                        label: $r('app.string.app_ua_add_token'),
                        icon: $r('sys.symbol.plus'),
                        isEnabled: true,
                        componentId: this.addTokenMenuTargetId,
                        action: () => {
                          this.openAddTokenMenu();
                        }
                      }
                    }
                  ]
                }
              }
            })
          }
          .backgroundColor($r('app.color.window_background'))
          .tabBar(BottomTabBarStyle.of(
            {
              normal: new SymbolGlyphModifier($r('sys.symbol.key_fill')),
              selected: new SymbolGlyphModifier($r('sys.symbol.key_fill'))
            },
            $r('app.string.tab_token'))
            .verticalAlign(VerticalAlign.Center)
          )
          .tabIndex(0)

          TabContent() {
            HdsNavigation() {
              this.SettingEntryCardBuilder()
            }
            .bindToScrollable([this.settingEntryScroller])
            .titleMode(HdsNavigationTitleMode.MINI)
            .hideBackButton(true) // 设置mini类型隐藏后退按钮
            .titleBar({
              avoidLayoutSafeArea: true, // 状态栏安全区沉浸
              style: {
                originalStyle: {
                  contentStyle: {
                    titleStyle: {
                      mainTitleColor: $r('sys.color.font_primary'),
                    },
                    menuStyle: {
                      iconColor: $r('sys.color.icon_primary')
                    },
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
                  scrollEffectType: this.currentScrollEffectType // 实时模糊，渐变是GRADIENT_BLUR
                },
                systemMaterialEffect: {
                  materialType: hdsMaterial.MaterialType.ADAPTIVE,
                  materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                }
              },
              content: {
                title: {
                  mainTitle: $r('app.string.tab_me')
                },
                menu: {
                  value: []
                }
              }
            })
          }
          .backgroundColor($r('app.color.window_background'))
          .tabBar(BottomTabBarStyle.of(
            {
              normal: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill_1')),
              selected: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill_1')),
            },
            $r('app.string.tab_me'))
            .verticalAlign(VerticalAlign.Center)
          )
          .tabIndex(1)
        }
        .barBackgroundColor($r('app.color.tab_bar_bg'))
        .backgroundColor($r('app.color.window_background'))
        .layoutWeight(1)
        .barOverlap(true)
        .barBackgroundColor(Color.Transparent)
        .barBackgroundBlurStyle(BlurStyle.Regular)
        .barPosition(BarPosition.End)
        .barFloatingStyle({
          barBottomMargin: 28,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
        .vertical(false)
        .barMode(BarMode.Fixed)
        .animationDuration(300)
        .onChange((index) => {
          this.tab_bar_index = index;
        })
      }
      }
    }
    .width('100%')
    .height('100%')
    .allowDrop([uniformTypeDescriptor.UniformDataType.FILE])
    .onDrop(() => {
      this.DropFilesDialogIsOpen = false;
      this.DropFilesDialogController?.close();
    })
    .onDragEnter(() => {
      if (!this.DropFilesDialogIsOpen) {
        this.DropFilesDialogIsOpen = true;
        this.DropFilesDialogController?.open();
      }
    })
    .onDragLeave(() => {
      this.DropFilesDialogIsOpen = false;
      this.DropFilesDialogController?.close();
    })
    .foregroundBlurStyle(this.background_blur_flag ? BlurStyle.Thin : BlurStyle.NONE, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT
    })
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.navDestinationBuilder)
    .bindContentCover($$this.isAppLockOverlayVisible, this.AppLockOverlayBuilder(), {
      modalTransition: ModalTransition.NONE,
      onWillDismiss: (dismissContentCoverAction: DismissContentCoverAction) => {
      },
    })
  }
}
