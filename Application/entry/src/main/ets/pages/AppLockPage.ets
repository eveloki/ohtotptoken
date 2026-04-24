import { cryptoFramework } from "@kit.CryptoArchitectureKit";
import { userAuth } from "@kit.UserAuthenticationKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { router } from "@kit.ArkUI";
import { AppPreference, PREF_KEYS, ROUTE_NAMES } from "../utils/AppPreference";
import { common } from "@kit.AbilityKit";
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Preview
@ComponentV2
export struct AppLockPage {
  @Local appCtx: common.UIAbilityContext = AppStorage.get('appContext') as common.UIAbilityContext;

  onPageShow(): void {
    if (!AppPreference.getPreference(PREF_KEYS.SAFETY_LOCK_ENABLE)) {
      router.replaceUrl({ url: ROUTE_NAMES.IndexPage });
    } else if (AppPreference.getPreference(PREF_KEYS.SAFETY_AUTO_UNLOCK_ENABLE)) {
      requireUserAuth(this.appCtx);
    }
  }

  aboutToAppear(): void {
    router.clear();
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
            requireUserAuth(getContext(this));
          })

        Blank().layoutWeight(0.4)
      }
      .width('100%')
      .height('100%')
    }
    .height('100%')
  }
}

export function requireUserAuth(ctx: Context): void {
  try {
    const rand = cryptoFramework.createRandom();
    const len: number = 16;
    const randData: Uint8Array = rand?.generateRandomSync(len)?.data;
    // 设置认证参数
    const authParam: userAuth.AuthParam = {
      challenge: randData,
      authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
      authTrustLevel: userAuth.AuthTrustLevel.ATL3,
    };
    // 配置认证界面
    const widgetParam: userAuth.WidgetParam = {
      title: ctx.resourceManager.getStringSync($r('app.string.user_auth_prompt').id)
    };
    // 获取认证对象
    const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
    hilog.info(0, 'AppLockPage', 'get userAuth instance success');
    // 订阅认证结果
    userAuthInstance.on('result', {
      onResult(result) {
        hilog.info(0, 'AppLockPage', `userAuthInstance callback result: ${JSON.stringify(result)}`);
        // 可在认证结束或其他业务需要场景，取消订阅认证结果
        if (result.result == userAuth.UserAuthResultCode.SUCCESS) {
          if (ctx.eventHub != undefined) {
            AppStorage.setOrCreate('app_lock_need_show', false);
            router.replaceUrl({ url: ROUTE_NAMES.IndexPage });
          }
        }
        userAuthInstance.off('result');
      }
    });
    hilog.info(0, 'AppLockPage', 'auth on success');
    userAuthInstance.start();
    hilog.info(0, 'AppLockPage', 'auth start success');
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    hilog.error(err?.code ?? 0, 'AppLockPage', `auth catch error. Code is ${err?.code}, message is ${err?.message}`);
  }
}