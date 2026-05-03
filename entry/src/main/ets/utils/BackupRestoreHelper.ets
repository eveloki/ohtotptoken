import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KvManager } from './KvManager';

const TAG = 'BackupRestoreHelper';

/**
 * 换机备份恢复公共逻辑.
 *
 * 核心设计：
 * 加密KV数据库的密钥绑定在设备TEE中，换机后新设备无法解密旧设备的加密KV文件。
 * 因此需要通过非加密KV数据库作为中转：
 * - 备份：加密KV → 非加密KV（系统随后自动传输非加密KV文件到新设备）
 * - 恢复：非加密KV → 加密KV（恢复完成后清理非加密KV中的明文数据）
 *
 * 非加密KV虽然encrypt=false，但运行在HarmonyOS KV存储框架的系统保护内存中，
 * 安全等级（S4）远高于应用层JSON文件。
 *
 * BackupExtension运行在独立进程中，KvManager单例为空，
 * 需要通过ExtensionContext重新初始化KV存储。
 *
 * 关于onRelease超时与触发时机：
 * onRelease在备份和恢复完成后都会触发（scenario: 1=备份, 2=恢复）。
 * 由于onRelease与文件传输的时序不确定，onRelease中不做任何数据操作，
 * 避免在备份场景下清空尚未传输的非加密KV数据导致备份失效。
 * 清理逻辑仅在onRestore中执行，此时数据已从非加密KV恢复到加密KV，清理是安全的。
 * onRelease的5秒超时对本方案无影响，因为onRelease为空实现。
 */

/**
 * 执行换机备份：加密KV → 非加密KV.
 * 备份完成后不清理非加密KV，因为系统需要在onBackup之后传输非加密KV文件到新设备.
 * DataSyncToNoEncryptDatabase内部会先清空非加密KV再写入，避免旧数据残留.
 * 操作失败时抛出Error，由BackupExtension感知并处理.
 *
 * @param ctx - BackupExtensionContext
 * @returns 同步条数
 */
export async function performBackup(ctx: common.Context): Promise<number> {
  hilog.info(0, TAG, 'performBackup start');
  const kvMgr = KvManager.getInstance();
  await kvMgr.initKvManagerForBackup(ctx);
  const count = await kvMgr.DataSyncToNoEncryptDatabase();
  hilog.info(0, TAG, `performBackup: synced ${count} entries to non-encrypted KV.`);
  return count;
}

/**
 * 执行换机恢复：非加密KV → 加密KV.
 * 仅在恢复成功（count > 0）时才清理非加密KV，避免恢复失败时清除唯一数据副本.
 * DataSyncToEncryptDatabase失败时抛出Error，由BackupExtension感知并处理.
 *
 * @param ctx - BackupExtensionContext
 * @returns 恢复条数
 */
export async function performRestore(ctx: common.Context): Promise<number> {
  hilog.info(0, TAG, 'performRestore start');
  const kvMgr = KvManager.getInstance();
  await kvMgr.initKvManagerForBackup(ctx);
  const count = await kvMgr.DataSyncToEncryptDatabase();
  if (count > 0) {
    hilog.info(0, TAG, `performRestore: restored ${count} entries to encrypted KV.`);
    await kvMgr.ClearNoEncryptDatabase();
    hilog.info(0, TAG, 'performRestore: non-encrypted KV cleared.');
  } else {
    hilog.info(0, TAG, 'performRestore: no entries restored, skipping clear to preserve data.');
  }
  return count;
}
