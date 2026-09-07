import { UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenBatchProgress, TokenBatchProgressCallback, TokenBatchStage, dialogSystemMaterial } from 'common';
import { TokenProgressDialogParams } from '../dialogs/TokenProgressDialog';

/** 由真实 UI 组件实现；不能在普通工具类中直接调用全局 @Builder。 */
export interface TokenBatchDialogHost {
  getUIContext(): UIContext;
  buildTokenProgressDialog(params: TokenProgressDialogParams): void;
}

/** 单个模态操作拥有自己的弹窗；不提前返回成功，也不允许重复提交或误取消事务。 */
export class TokenBatchOperation {
  private static busy: boolean = false;

  static isBusy(): boolean {
    return TokenBatchOperation.busy;
  }

  static async run(host: TokenBatchDialogHost, title: ResourceStr,
    operation: (report: TokenBatchProgressCallback) => Promise<void>): Promise<void> {
    if (TokenBatchOperation.busy) {
      throw new Error('A token operation is already running');
    }
    const context = host.getUIContext();
    TokenBatchOperation.busy = true;
    let dialogId: number | undefined = undefined;
    let running = true;
    const start = Date.now();
    try {
      const initial: TokenBatchProgress = { stage: TokenBatchStage.PREPARING, completed: 0, total: 0 };
      const params = new TokenProgressDialogParams(title, initial);
      const prompt = context.getPromptAction();
      dialogId = await prompt.openCustomDialog({
        systemMaterial: dialogSystemMaterial(),
        builder: () => host.buildTokenProgressDialog(params),
        autoCancel: false,
        alignment: DialogAlignment.Center,
        onWillDismiss: (action: DismissDialogAction) => {
          if (!running) {
            action.dismiss();
          }
        }
      });
      let lastUpdate = 0;
      let lastStage = TokenBatchStage.PREPARING;
      let stageStart = Date.now();
      const report = (progress: TokenBatchProgress): void => {
        if (!running) {
          return;
        }
        const now = Date.now();
        const changedStage = progress.stage !== lastStage;
        if (changedStage) {
          hilog.info(0xFF00, 'TokenBatchUI', `stage=${lastStage} elapsedMs=${now - stageStart}`);
          stageStart = now;
          lastStage = progress.stage;
        }
        // 每个阶段首尾必达；中间最多约12帧/秒，避免每个 ASSET 回调都重绘 Dialog。
        if (changedStage || progress.completed === 0 || progress.completed === progress.total || now - lastUpdate >= 80) {
          params.progress = progress;
          lastUpdate = now;
        }
      };
      await operation(report);
      hilog.info(0xFF00, 'TokenBatchUI', `operation finished totalMs=${Date.now() - start}`);
    } finally {
      running = false;
      try {
        if (dialogId !== undefined) {
          await context.getPromptAction().closeCustomDialog(dialogId);
        }
      } catch (_) {
        // 例如宿主已销毁；不把关闭弹窗失败误报成数据写入失败。
        hilog.warn(0xFF00, 'TokenBatchUI', 'Could not close progress dialog');
      } finally {
        TokenBatchOperation.busy = false;
      }
    }
  }
}
