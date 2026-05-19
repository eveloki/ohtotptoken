import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { performBackup, performRestore } from '../utils/BackupRestoreHelper';

const TAG = 'BackupExtension';

/**
 * 换机备份恢复扩展.
 * 详细设计说明参见 BackupRestoreHelper.ets.
 *
 * onRelease说明：
 * 备份和恢复完成后都会触发，但不在onRelease中做任何数据操作，
 * 因为onRelease与文件传输的时序不确定，备份场景下可能清空尚未传输的数据。
 * 清理逻辑仅在onRestore成功后由performRestore内部执行。
 */
export default class BackupExtension extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    hilog.info(0, TAG, 'onBackup start');
    await performBackup(this.context);
    hilog.info(0, TAG, 'onBackup completed.');
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(0, TAG, `onRestore start, bundleVersion: ${JSON.stringify(bundleVersion)}`);
    await performRestore(this.context);
    hilog.info(0, TAG, 'onRestore completed.');
  }
}
