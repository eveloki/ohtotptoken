import { describe, it, expect } from '@ohos/hypium';
import {
  AppPreference,
  BUILTIN_DEFAULT_PACK_ID,
  IconPackArchiver,
  IconPackBackupStatus,
  IconPackCloudBackup,
  IconPackDevicePort,
  IconPackRestoreResult,
  IconPackSyncState,
  PREF_KEYS,
  mergeEnabledPacks,
} from 'common';
import { MemoryFs } from './fakes/BackupFakes';

/**
 * 图标包云备份状态机测试（Phase 2 FsGateway + IconPackArchiver 端口注入）。
 *
 * 覆盖：IDLE→X→IDLE 互斥转换（含并发拒绝与失败复位）、备份流程
 * （staging/zip/伴生元数据）、5 分钟去抖与云端较新判定、
 * 清理流程、状态查询降级、enabledPacks 合并策略（纯函数）。
 */

/** 可门控的假压缩器：compress 挂起直到测试放行，用于构造并发窗口 */
class GatedArchiver implements IconPackArchiver {
  compressCalls: number = 0;
  decompressCalls: number = 0;
  private release: (() => void) | null = null;
  private gate: Promise<void> | null = null;
  hang: boolean = false;

  compress(_srcDir: string, _destZip: string): Promise<void> {
    this.compressCalls++;
    if (this.hang) {
      this.gate = new Promise<void>((resolve: () => void) => {
        this.release = resolve;
      });
      return this.gate;
    }
    return Promise.resolve();
  }

  decompress(_zipPath: string, _destDir: string): Promise<void> {
    this.decompressCalls++;
    return Promise.resolve();
  }

  releaseGate(): void {
    if (this.release !== null) {
      this.release();
      this.release = null;
    }
  }
}

/** 假设备端口：LocalUnit 下 deviceInfo API 不可用 */
class FakeIconDevice implements IconPackDevicePort {
  deviceId(): string {
    return 'test-odid';
  }

  deviceName(): string {
    return 'TestDevice';
  }
}

function bindDeps(fs: MemoryFs, archiver: IconPackArchiver): void {
  IconPackCloudBackup.getInstance().useDepsForTest({
    fs: fs,
    archiver: archiver,
    device: new FakeIconDevice(),
    filesDir: '/data/files',
    cloudDir: '/cloud',
    cacheDir: '/data/cache',
  });
}

function resetSingleton(): void {
  IconPackCloudBackup.getInstance().resetForTest();
  AppPreference.setPreference(PREF_KEYS.ICON_PACK_CLOUD_SYNC_TIME, '');
}

/** 让出一轮事件循环（等待挂起操作完成状态迁移，避免用例间竞态） */
function delayForTurn(): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => resolve(), 1);
  });
}

export default function iconPackCloudBackupTest() {
  describe('iconPackCloudBackupTest', () => {
    it('backup_full_flow_writes_zip_meta_and_timestamp', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);
      // 本地有图标包内容；假压缩器不产 zip，预置供 copyFile 到 cloudDir
      fs.files.set('/data/files/icon_packs/pack1.json', '{}');
      fs.files.set('/data/cache/icon_packs_backup.zip', 'zip');

      const ok = await IconPackCloudBackup.getInstance().backupIconPacks();
      expect(ok).assertTrue();
      expect(archiver.compressCalls).assertEqual(1);
      // zip 与伴生元数据文件落到 cloudDir
      expect(fs.files.has('/cloud/icon_packs_backup.zip')).assertTrue();
      expect(fs.files.has('/cloud/icon_packs_sync_meta.json')).assertTrue();
      const meta = fs.files.get('/cloud/icon_packs_sync_meta.json') ?? '';
      // 伴生元数据含设备与包列表字段
      expect(meta.includes('"deviceName":"TestDevice"')).assertTrue();
      expect(meta.includes('"packs"')).assertTrue();
      // 时间戳记录（防抖基准）
      const lastTime = AppPreference.getPreference(PREF_KEYS.ICON_PACK_CLOUD_SYNC_TIME) as string;
      expect(lastTime.length > 0).assertTrue();
      // staging 目录清理
      expect(fs.files.has('/data/cache/icon_pack_staging/icon_packs_meta.json')).assertFalse();
    });

    it('backup_without_content_skips_cleanly', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);

      const ok = await IconPackCloudBackup.getInstance().backupIconPacks();
      expect(ok).assertTrue();
      expect(archiver.compressCalls).assertEqual(0);
      expect(fs.files.size).assertEqual(0);
    });

    it('backup_failure_returns_false_and_resets_state_to_idle', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      fs.files.set('/data/files/icon_packs/pack1.json', '{}');
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);
      fs.failWrite = true;

      const ok = await IconPackCloudBackup.getInstance().backupIconPacks();
      expect(ok).assertFalse();
      // 失败也必须回到 IDLE，否则状态机永久锁死
      expect(IconPackCloudBackup.getInstance().getState()).assertEqual(IconPackSyncState.IDLE);
    });

    it('operations_are_mutually_exclusive_via_state_machine', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      fs.files.set('/data/files/icon_packs/pack1.json', '{}');
      fs.files.set('/data/cache/icon_packs_backup.zip', 'zip');
      const archiver = new GatedArchiver();
      archiver.hang = true;
      bindDeps(fs, archiver);

      // 等待备份进入 BACKING_UP（挂起在 compress 门控上）
      const pending = IconPackCloudBackup.getInstance().backupIconPacks();
      await delayForTurn();
      expect(IconPackCloudBackup.getInstance().getState()).assertEqual(IconPackSyncState.BACKING_UP);

      // 并发操作全部被拒绝
      expect(await IconPackCloudBackup.getInstance().checkCloudBackupNewer()).assertFalse();
      expect(await IconPackCloudBackup.getInstance().clearCloudBackup()).assertFalse();
      const restore = await IconPackCloudBackup.getInstance().restoreIconPacks();
      expect(restore.restoredCount).assertEqual(0);
      expect(restore.restoredFiles).assertEqual(0);

      archiver.releaseGate();
      expect(await pending).assertTrue();
      expect(IconPackCloudBackup.getInstance().getState()).assertEqual(IconPackSyncState.IDLE);
    });

    it('check_newer_true_when_cloud_meta_is_fresher', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);
      AppPreference.setPreference(PREF_KEYS.ICON_PACK_CLOUD_SYNC_TIME, '1000');
      fs.files.set('/cloud/icon_packs_sync_meta.json', '{"version":1,"timestamp":5000,"deviceId":"d","deviceName":"M","enabledPacks":[],"deletedPacks":[],"packs":[]}');

      const newer = await IconPackCloudBackup.getInstance().checkCloudBackupNewer();
      expect(newer).assertTrue();
    });

    it('check_newer_false_when_within_five_minutes_debounce', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);
      // 刚刚恢复过（相对 stub 时钟 1 分钟前）→ 去抖跳过
      AppPreference.setPreference(PREF_KEYS.ICON_PACK_CLOUD_SYNC_TIME, `${Date.now() - 60000}`);
      fs.files.set('/cloud/icon_packs_sync_meta.json', '{"version":1,"timestamp":9999999999999,"deviceId":"","deviceName":"","enabledPacks":[],"deletedPacks":[],"packs":[]}');

      const newer = await IconPackCloudBackup.getInstance().checkCloudBackupNewer();
      expect(newer).assertFalse();
    });

    it('check_newer_false_when_meta_missing', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);

      expect(await IconPackCloudBackup.getInstance().checkCloudBackupNewer()).assertFalse();
    });

    it('clear_removes_zip_and_meta_and_returns_true', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);
      fs.files.set('/cloud/icon_packs_backup.zip', 'zip');
      fs.files.set('/cloud/icon_packs_sync_meta.json', '{}');

      const ok = await IconPackCloudBackup.getInstance().clearCloudBackup();
      expect(ok).assertTrue();
      expect(fs.files.size).assertEqual(0);
    });

    it('status_reports_zip_and_meta_fields', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);
      fs.files.set('/cloud/icon_packs_backup.zip', 'zipdata');
      fs.files.set('/cloud/icon_packs_sync_meta.json',
        '{"version":1,"timestamp":7000,"deviceId":"dev-1","deviceName":"Mate60","enabledPacks":["p1"],"deletedPacks":[],"packs":[{"uuid":"p1","name":"Pack One","version":2,"iconCount":10}]}');

      const status: IconPackBackupStatus = await IconPackCloudBackup.getInstance().getCloudBackupStatus();
      expect(status.exists).assertTrue();
      expect(status.size).assertEqual(7);
      expect(status.packCount).assertEqual(1);
      expect(status.sourceDeviceId).assertEqual('dev-1');
      expect(status.sourceDeviceName).assertEqual('Mate60');
      expect(status.packs.length).assertEqual(1);
      expect(status.packs[0].iconCount).assertEqual(10);
    });

    it('status_falls_back_to_local_pack_count_when_meta_missing', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);

      const status = await IconPackCloudBackup.getInstance().getCloudBackupStatus();
      // 无 zip、无 meta：exists=false，包数回退本地内存（LocalUnit 下为 0）
      expect(status.exists).assertFalse();
      expect(status.packCount).assertEqual(0);
    });

    it('merge_enabled_packs_appends_local_only_and_defaults_when_empty', 0, () => {
      // 云端列表为基础，本地独有追加
      let merged = mergeEnabledPacks(['p1', 'p2'], ['p2', 'p3', 'p4']);
      expect(merged.join(',')).assertEqual('p1,p2,p3,p4');

      // 云端为空 → 内置默认包兜底 + 本地追加
      merged = mergeEnabledPacks([], ['p9']);
      expect(merged.join(',')).assertEqual(`${BUILTIN_DEFAULT_PACK_ID},p9`);
    });

    it('restore_returns_empty_result_without_state_leak', 0, async () => {
      resetSingleton();
      const fs = new MemoryFs();
      const archiver = new GatedArchiver();
      bindDeps(fs, archiver);
      // 云端无 zip → stat 失败 → 空结果
      const result: IconPackRestoreResult = await IconPackCloudBackup.getInstance().restoreIconPacks();
      expect(result.restoredCount).assertEqual(0);
      expect(IconPackCloudBackup.getInstance().getState()).assertEqual(IconPackSyncState.IDLE);
    });
  });
}
