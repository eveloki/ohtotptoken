import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UIContext } from '@kit.ArkUI';

/**
 * 节流 在规定的时间内，只执行一次
 *
 */
export function throttle(func: (event: ClickEvent) => void, delay?: number) {
  let inThrottle: boolean;
  return (event: ClickEvent) => {
    if (!inThrottle) {
      func(event);
      inThrottle = true;
      setTimeout(() => inThrottle = false, delay ? delay : 1000);
    }
  };
}

/**
 * 字符串资源 → 当前语言文案。
 *
 * 页面里需要把 `$r(...)` 拼进普通字符串时使用；取不到上下文或资源缺失时
 * 返回空串而不是抛异常（提示类文案出错不应影响主流程）。
 */
export function resourceText(uiContext: UIContext | undefined, res: Resource): string {
  try {
    const ctx = uiContext?.getHostContext();
    if (ctx === undefined || ctx === null) {
      return '';
    }
    return ctx.resourceManager.getStringSync(res.id);
  } catch (error) {
    hilog.warn(0, 'UiUtils', `resourceText failed: ${error}`);
    return '';
  }
}

/**
 * 唤起系统浏览器打开网页
 *
 */
export function startBrowsableAbility(context: common.UIAbilityContext,url:string): void {
  let want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: url,
    parameters: {
      'ohos.ability.params.showDefaultPicker': true
    }
  };
  context.startAbility(want)
    .then(() => {
      hilog.info(0, 'UiUtils', 'Start browsableAbility successfully.');
    })
    .catch((err: BusinessError) => {
      hilog.error(err.code, 'UiUtils', `Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
    });
}