import {
  common,
  AbilityConstant,
  UIAbility, Want, Configuration,
  ApplicationStateChangeCallback,
  ConfigurationConstant,
} from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageV2, router, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppPreference, SettingColorMode } from '../utils/AppPreference';
import { relationalStore  } from '@kit.ArkData';

//单版本分布式键值数据库
let rdbStore: relationalStore.RdbStore | null = null;

@ObservedV2
export class AppWindowInfo {
  @Trace AvoidTopHeight: number = 0;
  @Trace AvoidBottomHeight: number = 0;
  @Trace WidthBreakpoint: WidthBreakpoint = 0;
  @Trace HeightBreakpoint: HeightBreakpoint = 0;
  @Trace Size: window.Size = { width: 0, height: 0};
  @Trace ColorMode: ConfigurationConstant.ColorMode = -1;
  @Trace Context?: common.UIAbilityContext;
  @Trace uiContext?: UIContext;
  @Trace WindowClass?: window.Window;
}

export default class EntryAbility extends UIAbility {
  private uiContext?: UIContext;
  private onWindowSizeChange: (windowSize: window.Size) => void = (windowSize: window.Size) => {
    let win: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
    let widthBp: WidthBreakpoint = this.uiContext!.getWindowWidthBreakpoint();
    let heightBp: HeightBreakpoint = this.uiContext!.getWindowHeightBreakpoint();
    win.WidthBreakpoint = widthBp;
    win.HeightBreakpoint = heightBp;
    win.Size = windowSize;
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate("appContext", this.context);
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');

    if ((want.parameters!['action'] as string) == 'quick_scan') {
      AppPreference.setPreference('app_want_quick_scan', true);
      AppPreference.setPreference('app_want_uri', want.uri!);
    }

    //监听前后台变化
    let applicationStateChangeCallback: ApplicationStateChangeCallback = {
      onApplicationForeground() {
        console.info('applicationStateChangeCallback onApplicationForeground');
      },
      onApplicationBackground() {
        console.info('applicationStateChangeCallback onApplicationBackground');
        if (AppPreference.getPreference('app_safety_lock_enable')) {
          router.pushUrl({ url: 'pages/AppLockPage' })
        }
      }
    }

    // 1.获取applicationContext
    let applicationContext = this.context.getApplicationContext();
    try {
      // 2.通过applicationContext注册应用前后台状态监听
      applicationContext.on('applicationStateChange', applicationStateChangeCallback);
    } catch (paramError) {
      console.error(`error: ${(paramError as BusinessError).code}, ${(paramError as BusinessError).message}`);
    }
  }

  onDestroy(): void {
    AppPreference.saveSettings();
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    let win: AppWindowInfo = AppStorageV2.connect(AppWindowInfo, () => new AppWindowInfo())!;

    win.ColorMode = this.context.config.colorMode ?? -1;
    win.Context = this.context;

    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    AppPreference.loadSettings().then(() => {
      windowStage.loadContent('pages/AppLockPage', (err) => {
        if (err.code) {
          hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
          return;
        }

        let windowClass: window.Window = windowStage.getMainWindowSync();
        this.uiContext = windowClass.getUIContext();

        win.uiContext = this.uiContext;
        win.WindowClass = windowClass;

        windowClass.setWindowLayoutFullScreen(true)

        const avoidAreaTop = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        const avoidAreaBottom = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);

        // save window avoid area info
        win.AvoidTopHeight = px2vp(avoidAreaBottom.topRect.height);
        win.AvoidBottomHeight = px2vp(avoidAreaTop.bottomRect.height);

        windowClass.on('avoidAreaChange', (data) => {
          if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
            win.AvoidBottomHeight = px2vp(data.area.bottomRect.height);
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM)
            win.AvoidTopHeight = px2vp(data.area.topRect.height);
        });

        const widthBp: WidthBreakpoint = this.uiContext.getWindowWidthBreakpoint();
        const heightBp: HeightBreakpoint = this.uiContext.getWindowHeightBreakpoint();
        win.Size = windowClass.getWindowProperties().windowRect;
        win.WidthBreakpoint = widthBp;
        win.HeightBreakpoint = heightBp;
        windowClass.on('windowSizeChange', this.onWindowSizeChange);
        // apply app settings
        this.applySettings(windowClass);

        hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
      });
    });
  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if ((want.parameters!['action'] as string) == 'quick_scan') {
      AppPreference.setPreference('app_want_quick_scan', true);
      AppPreference.setPreference('app_want_uri', want.uri!);
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    let window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
    window.ColorMode = newConfig.colorMode ?? -1;
  }
  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }

  applySettings(windowClass: window.Window): void {
    // Color Mode
    const color_mode = AppPreference.getPreference('app_appearance_color_mode') as number;
    const color_map: Map<SettingColorMode, ConfigurationConstant.ColorMode> = new Map([
      [SettingColorMode.System, ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET],
      [SettingColorMode.Dark, ConfigurationConstant.ColorMode.COLOR_MODE_DARK],
      [SettingColorMode.Light, ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT],
    ]);
    this.context.getApplicationContext().setColorMode(color_map.get(color_mode ?? 0));

    // 设置隐私模式
    let privacy_mode = AppPreference.getPreference('app_safety_privacy_enable') as boolean;
    if (privacy_mode) {
      try {
        windowClass.setWindowPrivacyMode(true).catch((err: BusinessError) => {
          console.error(`Failed to set the window to privacy mode. Cause code: ${err.code}, message: ${err.message}`);
        });
      } catch (exception) {
        console.error(`Failed to set the window to privacy mode. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    }
  }

  //初始化RDB数据库
  initRdbStore(): void{
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: "main_rdb_store.db",
      encrypt: true,//加密
      securityLevel: relationalStore.SecurityLevel.S3
    };
    relationalStore.getRdbStore(this.context, STORE_CONFIG, (err: BusinessError, __rdbStore: relationalStore.RdbStore) => {
      rdbStore = __rdbStore;
      if (err) {
        console.error(`Get RdbStore failed, code is ${err.code},message is ${err.message}`);
        return;
      }
      console.info('Get RdbStore successfully.');
    })
  }

}
