import { cryptoFramework } from "@kit.CryptoArchitectureKit";
import { userAuth } from "@kit.UserAuthenticationKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { common } from "@kit.AbilityKit";
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppPreference, PREF_KEYS } from "../utils/AppPreference";

@ComponentV2
export struct AppLockOverlay {
  @Param onUnlock: () => void = () => {};
  @Local appCtx: common.UIAbilityContext = AppStorage.get('appContext') as common.UIAbilityContext;

  aboutToAppear(): void {
    if (AppPreference.getPreference(PREF_KEYS.SAFETY_AUTO_UNLOCK_ENABLE)) {
      this.triggerAuth();
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .foregroundBlurStyle(BlurStyle.Thin, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0,
        })

      Column() {
        Blank().layoutWeight(1)

        Column({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.lock_fill'))
            .fontSize(64)
            .fontColor([$r('app.color.str_main')])
            .effectStrategy(2)

          Text($r('app.string.app_locking'))
            .fontSize(16)
            .fontColor($r('app.color.str_gray'))
            .textAlign(TextAlign.Center)
        }

        Blank().layoutWeight(1)

        Button($r('app.string.app_biometric_login'))
          .width('75%')
          .height(48)
          .fontSize(18)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.button_blue'))
          .borderRadius(24)
          .type(ButtonType.Normal)
          .onClick(() => {
            this.triggerAuth();
          })

        Blank().layoutWeight(0.4)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  private triggerAuth(): void {
    const onUnlock = this.onUnlock;
    try {
      const rand = cryptoFramework.createRandom();
      const len: number = 16;
      const randData: Uint8Array = rand?.generateRandomSync(len)?.data;
      const authParam: userAuth.AuthParam = {
        challenge: randData,
        authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
      };
      const widgetParam: userAuth.WidgetParam = {
        title: this.appCtx.resourceManager.getStringSync($r('app.string.user_auth_prompt').id)
      };
      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      hilog.info(0, 'AppLockOverlay', 'get userAuth instance success');
      userAuthInstance.on('result', {
        onResult(result) {
          hilog.info(0, 'AppLockOverlay', `userAuthInstance callback result: ${JSON.stringify(result)}`);
          if (result.result == userAuth.UserAuthResultCode.SUCCESS) {
            onUnlock();
          }
          userAuthInstance.off('result');
        }
      });
      userAuthInstance.start();
      hilog.info(0, 'AppLockOverlay', 'auth start success');
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.error(err?.code ?? 0, 'AppLockOverlay', `auth catch error. Code is ${err?.code}, message is ${err?.message}`);
    }
  }
}
