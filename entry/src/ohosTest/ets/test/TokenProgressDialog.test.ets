import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { ComponentContent, window, UIContext } from '@kit.ArkUI';
import { TokenBatchStage } from 'common';
import { TokenBatchDialogHost, TokenBatchOperation } from '../../../main/ets/utils/TokenBatchOperation';
import { TokenProgressDialog, TokenProgressDialogParams } from '../../../main/ets/dialogs/TokenProgressDialog';

class HostParams {
  onReady: (host: TokenBatchDialogHost) => void;
  constructor(onReady: (host: TokenBatchDialogHost) => void) { this.onReady = onReady; }
}

@ComponentV2
struct ProgressTestHost {
  @Require @Param params: HostParams;

  aboutToAppear(): void { this.params.onReady(this); }

  @Builder
  buildTokenProgressDialog(params: TokenProgressDialogParams) {
    TokenProgressDialog({ params: params })
  }

  build() {
    Column() { Text('Dialog test host') }
      .id('token_progress_test_host')
  }
}

@Builder
function testHostBuilder(params: HostParams) {
  ProgressTestHost({ params: params })
}

/** 只验证真实 Dialog 的更新与释放，不点击设备、不读写令牌。 */
export default function tokenProgressDialogTest(): void {
  describe('TokenProgressDialogDeviceTest', () => {
    let driver: Driver;
    let context: common.UIAbilityContext;
    let uiContext: UIContext;
    let host: TokenBatchDialogHost;
    let hostContent: ComponentContent<HostParams> | undefined = undefined;
    beforeAll(async () => {
      // UITest 连接在测试运行阶段建立，不能在 describe 注册阶段提前 create。
      driver = Driver.create();
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      try {
        context = (await delegator.getCurrentTopAbility()).context as common.UIAbilityContext;
      } catch (_) {
        const monitor: abilityDelegatorRegistry.AbilityMonitor = { abilityName: 'EntryAbility' };
        await delegator.addAbilityMonitor(monitor);
        try {
          await delegator.startAbility({
            bundleName: abilityDelegatorRegistry.getArguments().bundleName,
            abilityName: 'EntryAbility'
          });
          context = (await delegator.waitAbilityMonitor(monitor, 20000)).context as common.UIAbilityContext;
        } finally {
          await delegator.removeAbilityMonitor(monitor);
        }
      }
      await driver.waitForComponent(ON.id('hdsTabs'), 10000);
      const mainWindow = await window.getLastWindow(context);
      uiContext = mainWindow.getUIContext();
      // 仅测试夹具通过 ComponentContent 挂载真实组件；生产弹窗由组件内 builder 创建。
      hostContent = new ComponentContent(uiContext, wrapBuilder(testHostBuilder),
        new HostParams((value: TokenBatchDialogHost) => { host = value; }));
      await uiContext.getPromptAction().openCustomDialog(hostContent);
      await driver.waitForComponent(ON.id('token_progress_test_host'), 5000);
    });
    afterAll(async () => {
      if (hostContent) {
        await uiContext.getPromptAction().closeCustomDialog(hostContent);
        hostContent.dispose();
      }
    });

    it('dialog_shows_only_loading_text_despite_progress_updates_then_closes', 0, async () => {
      await TokenBatchOperation.run(host, $r('app.string.token_batch_import_title'), async (report) => {
        report({ stage: TokenBatchStage.WRITING_SECRETS, completed: 0, total: 64 });
        const loading = context.resourceManager.getStringSync($r('app.string.token_batch_loading').id);
        const first = await driver.waitForComponent(ON.text(loading), 5000);
        expect(first !== null).assertTrue();
        expect(await driver.findComponent(ON.type('LoadingProgress')) !== null).assertTrue();
        report({ stage: TokenBatchStage.WRITING_SECRETS, completed: 64, total: 64 });
        const last = await driver.waitForComponent(ON.text(loading), 5000);
        expect(last !== null).assertTrue();
        report({ stage: TokenBatchStage.COMMITTING, completed: 0, total: 0 });
        expect(await driver.waitForComponent(ON.text(loading), 5000) !== null).assertTrue();
      });
      expect(TokenBatchOperation.isBusy()).assertFalse();
      expect(await driver.findComponent(ON.id('token_batch_progress_dialog'))).assertNull();
    });

    it('failed_operation_closes_dialog_and_allows_retry', 0, async () => {
      let rejected = false;
      let sawDialog = false;
      try {
        await TokenBatchOperation.run(host, $r('app.string.token_batch_delete_title'), async (report) => {
          report({ stage: TokenBatchStage.ROLLING_BACK, completed: 0, total: 0 });
          sawDialog = await driver.waitForComponent(ON.id('token_batch_progress_dialog'), 5000) !== null;
          throw new Error('Injected test failure without data changes');
        });
      } catch (_) {
        rejected = true;
      }
      expect(rejected).assertTrue();
      expect(sawDialog).assertTrue();
      expect(TokenBatchOperation.isBusy()).assertFalse();
      expect(await driver.findComponent(ON.id('token_batch_progress_dialog'))).assertNull();
      await TokenBatchOperation.run(host, $r('app.string.token_batch_favorite_title'), async () => {});
      expect(TokenBatchOperation.isBusy()).assertFalse();
    });
  });
}
