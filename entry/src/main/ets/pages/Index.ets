import { bundleManager,common } from '@kit.AbilityKit';
import { otpType, TokenConfig } from '../utils/TokenConfig';
import { SettingPage } from '../pages/setting/SettingPage'
import { BackupAndMigrationSheet } from '../pages/setting/BackupAndMigrationSheet'
import { SecuritySheet } from '../pages/setting/SecuritySheet'
import { AppearanceSheet } from '../pages/setting/AppearanceSheet'
import { DataSyncSheet } from '../pages/setting/DataSyncSheet'
import { AgreementSheet } from '../pages/setting/AgreementSheet'
import { AboutSheet } from '../pages/setting/AboutSheet'
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { showSnackBar, SnackBarNotifyType } from '../utils/HdsSnackBarUtils';
import { AppPreference, TokenPreference, SettingTopEffectType, SettingBottomTabsType, SCROLL_EFFECT_TYPE_MAP, EVENT_NAMES, PREF_KEYS, ROUTE_NAMES } from '../utils/AppPreference';
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
// 申请锁屏下应用敏感数据访问权限
import { screenLockFileManager } from '@kit.AbilityKit';
import { TokenListPage } from './TokenListPage';
import { RestoreDataPage } from './RestoreDataPage';
import { MasterKeyPage } from './MasterKeyPage';
import { RecoveryKeyRecordPage } from './RecoveryKeyRecordPage';
import { AppearancePage } from './AppearancePage';
import { ShowDataSyncDetailsPage } from './ShowDataSyncDetailsPage';
import { ShowCodePage } from './ShowCodePage';
import { PrivacyPage } from './PrivacyPage';
import { AgreementPage } from './AgreementPage';
import { AppLockPage } from './AppLockPage';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { AppStorageV2, SymbolGlyphModifier, window } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs,
  ScrollEffectType, HdsListItemCard,
  PrefixIcon,
  IconSize,
  SuffixArrow} from '@kit.UIDesignKit';
import { ArcTokenListPage } from './ArcTokenListPage';
import { LengthMetrics } from '@kit.ArkUI';
import { testProtobufToJson } from '../utils/GoogleAuthUtils';

const TAG = 'PrivacySubscribe';

let tkStore = TokenStore.getInstance();

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
  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local CurrentTokensCount: number = 0;
  @Local scrollEffectVersion: number = 0;
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
    return SCROLL_EFFECT_TYPE_MAP.get(topEffectType) ?? ScrollEffectType.GRADIENT_BLUR;
  }

  private appIsInit = false;
  private appIsShow = false;

  private readonly eventId = 'usual.event.PRIVACY_STATE_CHANGED';
  private icon_pack_dir = this.appCtx.filesDir + "/icon_packs";
  private user_icon_dir = this.appCtx.filesDir + "/user_icons";
  private DropFilesDialogIsOpen:boolean = false;

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
      console.info("reason=" + JSON.stringify(dismissDialogAction.reason))
      console.log("dialog onWillDismiss")
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

  aboutToAppear(): void {
    PermissionManager.getInstance().verifyPermissionsAndPushEvent();
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).then((bundleInfo) => {
      AppStorage.setOrCreate("BundleInfo", bundleInfo);
    });
    //配置预定义好的来自华为官方的个人隐私条款链接
    AppStorage.setOrCreate("AppPrivacyManageInfoUrl",
      'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1537746898868267328');

    tkStore.initTokenStore().then(() => {
      if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.TOKEN_CHANGED, () => this.onTokenChanged());
      // 订阅顶部模糊效果类型变更事件
      if (this.appCtx.eventHub!= undefined) this.appCtx.eventHub.on(EVENT_NAMES.TOP_EFFECT_TYPE_CHANGED, () => {
        // 触发UI重新渲染，更新滚动效果类型
        this.scrollEffectVersion++;
      });
      tkStore.getTokens().then((tokens) => {
        this.CurrentTokens = tokens;
        this.CurrentTokensCount = tokens.length;
        this.token_loading = false;
        // DEBUG MODE
        this.restoreByKVCheck();
        this.appIsInit = true;
        AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING,false)
      });
    });

    // create icon pack dir
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
            console.log('store fmt.ks to cache dir')
          })
            .catch((err:BusinessError) => {
              console.error(`${err.message}`)
            })
        })
      }
    })

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
      console.info("reason=" + JSON.stringify(dismissDialogAction.reason))
      console.log("dialog onWillDismiss")
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
  //endregion

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
            AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING,false);
          });
        }
        else
        {
          AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING,false);
        }
      } catch (err) {
        let message = (err as BusinessError).message;
        hilog.error(0x0000, 'testTag', 'acquireAccess failed: %{public}s', message);
        AppPreference.setPreference(PREF_KEYS.DB_KV_ARCHIVE_IS_RUNNING,false);
      }

    }
  }

  onPageShow(): void {
    this.pageInfos.clear();
    this.appIsShow = true;
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
      backupReload: async (conf) => {
        await this.updateTokenConfigs(conf);
        tkStore.sortTokens();
      }
    })
      .height('100%')
  }

  @Builder
  SecuritySheetBuilder() {
    SecuritySheet()
      .height('100%')
  }

  @Builder
  AppearanceSheetBuilder() {
    AppearanceSheet()
      .height('100%')
  }

  @Builder
  DataSyncSheetBuilder() {
    DataSyncSheet()
      .height('100%')
  }

  @Builder
  AgreementSheetBuilder() {
    AgreementSheet()
      .height('100%')
  }

  @Builder
  AboutSheetBuilder() {
    AboutSheet()
      .height('100%')
  }

  @Builder
  SettingEntryCardBuilder() {
    List({ space: 10, scroller: this.settingEntryScroller }) {
      // 顶部占位空间，用于触发渐变模糊效果
      ListItem() {
        Column()
          .width('100%')
          .height(LengthMetrics.vp(120).value)
      }
      // 备份与迁移入口
      ListItem() {
        HdsListItemCard({
          cardHeight: this.token_preference.app_appearance_item_height,
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

      // 安全性入口
      ListItem() {
        HdsListItemCard({
          cardHeight: this.token_preference.app_appearance_item_height,
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

      // 外观与功能入口
      ListItem() {
        HdsListItemCard({
          cardHeight: this.token_preference.app_appearance_item_height,
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

      // 数据同步入口
      ListItem() {
        HdsListItemCard({
          cardHeight: this.token_preference.app_appearance_item_height,
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

      // 协议与声明入口
      ListItem() {
        HdsListItemCard({
          cardHeight: this.token_preference.app_appearance_item_height,
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

      // 关于入口
      ListItem() {
        HdsListItemCard({
          cardHeight: this.token_preference.app_appearance_item_height,
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


    }

    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, {alwaysEnabled: true})
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
      AppearancePage()
    } else if (name === ROUTE_NAMES.ShowDataSyncDetailsPage) {
      ShowDataSyncDetailsPage()
    } else if (name === ROUTE_NAMES.ShowCodePage) {
      ShowCodePage()
    } else if (name === ROUTE_NAMES.PrivacyPage) {
      PrivacyPage()
    } else if (name === ROUTE_NAMES.AgreementPage) {
      AgreementPage()
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
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        avoidLayoutSafeArea: true, // 状态栏安全区沉浸
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: this.currentScrollEffectType,
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
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        avoidLayoutSafeArea: true, // 状态栏安全区沉浸
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: this.currentScrollEffectType // 渐变模糊
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
            .titleMode(HdsNavigationTitleMode.MODAL)
            .titleBar({
              avoidLayoutSafeArea: true, // 状态栏安全区沉浸
              style: {
                scrollEffectOpts: {
                  enableScrollEffect: true,
                  scrollEffectType: this.currentScrollEffectType // 渐变模糊
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
            .verticalAlign(VerticalAlign.Top)
            .padding({top: LengthMetrics.vp(10)})
          )
          .tabIndex(0)

          TabContent() {
            HdsNavigation() {
              this.SettingEntryCardBuilder()
            }
            .bindToScrollable([this.settingEntryScroller])
            .titleMode(HdsNavigationTitleMode.MODAL)
            .titleBar({
              avoidLayoutSafeArea: true, // 状态栏安全区沉浸
              style: {
                scrollEffectOpts: {
                  enableScrollEffect: true,
                  scrollEffectType: this.currentScrollEffectType // 实时模糊，渐变是GRADIENT_BLUR
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
            .verticalAlign(VerticalAlign.Top)
            .padding({top:  LengthMetrics.vp(10)})
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
        .vertical(false)
        .barHeight(50 + this.window.AvoidBottomHeight)
        .barMode(BarMode.Fixed)
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
  }
}
