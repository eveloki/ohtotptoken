import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = `FileBackupExtensionAbility`;
export default class BackupExtension extends  BackupExtensionAbility {
  //onBackup
  async onBackup ()   {
    hilog.info(0x0000, TAG, `onBackup ok`);
  }

  //onRestore
  async onRestore (bundleVersion : BundleVersion) {
    hilog.info(0x0000, TAG, `onRestore ok ${JSON.stringify(bundleVersion)}`);
    hilog.info(0x0000, TAG, `onRestore end`);
  }
}