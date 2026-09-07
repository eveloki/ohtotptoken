import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenConfig, TokenBatchProgressCallback, restoreFromBackup, showSnackBar, SnackBarNotifyType } from 'common';
import { TokenBatchDialogHost, TokenBatchOperation } from './TokenBatchOperation';

export type TokenImportHandler = (tokens: TokenConfig[], report?: TokenBatchProgressCallback) => Promise<void>;

/** 文件读取/解密与数据库写入共用一个 Dialog，不能到解密结束后才显示 Loading。 */
export async function importBackupWithProgress(host: TokenBatchDialogHost, uri: string, encrypted: boolean,
  password: string, onImport: TokenImportHandler): Promise<boolean> {
  if (TokenBatchOperation.isBusy()) {
    return false;
  }
  let count = 0;
  try {
    await TokenBatchOperation.run(host, $r('app.string.token_batch_import_title'), async (report) => {
      const backup = await restoreFromBackup(uri, encrypted, password, report);
      count = backup.configs.length;
      await onImport(backup.configs, report);
    });
    showSnackBar($r('app.string.toast_multi_token_update', count), SnackBarNotifyType.SUCCESS);
    return true;
  } catch (_) {
    hilog.error(0xFF00, 'TokenBatchUI', 'Backup import failed');
    showSnackBar($r('app.string.token_batch_import_failed'), SnackBarNotifyType.ERROR);
    return false;
  }
}
