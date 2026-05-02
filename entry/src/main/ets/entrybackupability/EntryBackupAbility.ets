import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { performBackup, performRestore } from '../utils/BackupRestoreHelper';

const TAG = 'EntryBackupAbility';

/**
 * 换机备份恢复扩展（EntryBackupAbility入口）.
 * 与BackupExtension功能一致，保留两个入口以兼容不同系统版本.
 * 详细设计说明参见 BackupRestoreHelper.ets.
 */
export default class EntryBackupAbility extends BackupExtensionAbility {
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
