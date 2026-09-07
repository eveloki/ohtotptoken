import { hilog } from '@kit.PerformanceAnalysisKit';

export enum TokenBatchStage {
  PREPARING,
  READING,
  DECODING,
  DECRYPTING,
  PARSING,
  SAVING,
  COMMITTING,
  WRITING_SECRETS,
  REMOVING_SECRETS,
  ROLLING_BACK,
  DONE
}

/** 计数是当前阶段已处理/总数，不将 KV 提交等同于整个操作完成。 */
export interface TokenBatchProgress {
  stage: TokenBatchStage;
  completed: number;
  total: number;
}

export type TokenBatchProgressCallback = (progress: TokenBatchProgress) => void;

/** 进度观察者不参与事务结果；UI 已销毁或回调异常不能触发数据回滚。 */
export function reportTokenBatchProgress(callback: TokenBatchProgressCallback | undefined,
  stage: TokenBatchStage, completed: number = 0, total: number = 0): void {
  if (!callback) {
    return;
  }
  try {
    callback({ stage: stage, completed: completed, total: total });
  } catch (_) {
    hilog.warn(0xFF00, 'TokenBatchProgress', 'Progress observer failed; persistence continues');
  }
}
