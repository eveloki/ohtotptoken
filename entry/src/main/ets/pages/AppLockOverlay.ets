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

      RelativeContainer() {
        Row() {
          Column() {
            SymbolGlyph($r('sys.symbol.lock_fill'))
              .fontSize(70)
              .fontWeight(FontWeight.Bold)
              .fontColor([$r('app.color.str_main')])
              .alignRules({
                center: { anchor: '__container__', align: VerticalAlign.Center },
                middle: { anchor: '__container__', align: HorizontalAlign.Center }
              })
              .effectStrategy(2)
            Divider().vertical(false).height(20)
            Text($r('app.string.app_locking'))
              .fontSize(20)
            Text($r('app.string.app_unlock'))
              .fontSize(20)
              .fontColor('#3498db')
              .offset({ top: '40%' })
              .textAlign(TextAlign.Center)
          }
        }
        .width('80%')
        .height('80%')
        .alignRules({
          top: { anchor: "__container__", align: VerticalAlign.Top },
          bottom: { anchor: "__container__", align: VerticalAlign.Bottom },
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          bias: { vertical: 0.3 }
        })
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.triggerAuth();
    })
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
