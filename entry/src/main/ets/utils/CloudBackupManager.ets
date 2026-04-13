import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppPreference, PREF_KEYS } from './AppPreference';
import { CloudBackupCrypto, CloudBackupCryptoMode, CloudBackupHeader, CloudBackupPayload, CloudBackupRecord } from './CloudBackupCrypto';
import { TokenStore } from './TokenStore';

const TAG = 'CloudBackupManager';
const DOMAIN = 0xFF00;
const MAX_BACKUP_COUNT = 5;

export class CloudBackupManager {
  private static instance: CloudBackupManager | null = null;
  private crypto: CloudBackupCrypto = CloudBackupCrypto.getInstance();
  private mockBackupRecords: CloudBackupRecord[] = [];

  private constructor() {
    this.initMockBackupRecords();
  }

  static getInstance(): CloudBackupManager {
    if (!CloudBackupManager.instance) {
      CloudBackupManager.instance = new CloudBackupManager();
    }
    return CloudBackupManager.instance;
  }

  private initMockBackupRecords(): void {
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    const deviceNames: string[] = ['Mate 60 Pro', 'P60 Pro', 'MatePad Pro'];
    this.mockBackupRecords = [];
    const count = Math.min(MAX_BACKUP_COUNT, 3);
    for (let i = 0; i < count; i++) {
      const ts = now - i * dayMs;
      const d = new Date(ts);
      const dateStr = `${d.getFullYear()}-${this.padZero(d.getMonth() + 1)}-${this.padZero(d.getDate())} ${this.padZero(d.getHours())}:${this.padZero(d.getMinutes())}`;
      const record: CloudBackupRecord = {
        id: `bak_${ts}`,
        date: dateStr,
        timestamp: ts,
        tokenCount: 10 + Math.floor(Math.random() * 20),
        size: Math.floor(2048 + Math.random() * 8192),
        encrypted: true,
        deviceId: `device_${i}`,
        deviceName: deviceNames[i % deviceNames.length],
      };
      this.mockBackupRecords.push(record);
    }
  }

  private padZero(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  async backupToCloud(): Promise<boolean> {
    const isMasterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    const mode = this.crypto.getMode(isMasterKeySet);

    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'backupToCloud: no encryption mode, aborting');
      return false;
    }

    hilog.info(DOMAIN, TAG, `backupToCloud: starting backup, mode=${mode}`);

    const tokens = await TokenStore.getInstance().getTokens();
    const plaintext = JSON.stringify(tokens);

    hilog.info(DOMAIN, TAG, `backupToCloud: token count=${tokens.length}`);

    const encrypted = await this.crypto.encrypt(plaintext, mode);

    hilog.info(DOMAIN, TAG, `backupToCloud: encrypted size=${encrypted.length}, mock write to cloud`);

    const now = Date.now();
    const d = new Date(now);
    const dateStr = `${d.getFullYear()}-${this.padZero(d.getMonth() + 1)}-${this.padZero(d.getDate())} ${this.padZero(d.getHours())}:${this.padZero(d.getMinutes())}`;
    const newRecord: CloudBackupRecord = {
      id: `bak_${now}`,
      date: dateStr,
      timestamp: now,
      tokenCount: tokens.length,
      size: encrypted.length,
      encrypted: mode !== CloudBackupCryptoMode.NONE,
      deviceId: 'current_device',
      deviceName: 'This Device',
    };

    this.mockBackupRecords.unshift(newRecord);
    if (this.mockBackupRecords.length > MAX_BACKUP_COUNT) {
      this.mockBackupRecords = this.mockBackupRecords.slice(0, MAX_BACKUP_COUNT);
    }

    hilog.info(DOMAIN, TAG, 'backupToCloud: mock completed successfully');

    AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, dateStr);
    return true;
  }

  async restoreFromCloud(): Promise<boolean> {
    const isMasterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    const mode = this.crypto.getMode(isMasterKeySet);

    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'restoreFromCloud: no encryption mode, aborting');
      return false;
    }

    hilog.info(DOMAIN, TAG, `restoreFromCloud: starting restore, mode=${mode}`);

    hilog.info(DOMAIN, TAG, 'restoreFromCloud: mock read from cloud');

    const header: CloudBackupHeader = {
      version: 1,
      mode: mode,
      salt: 'mock_salt',
      iv: 'mock_iv',
    };
    const mockObj: CloudBackupPayload = {
      header: header,
      payload: '[]',
    };
    const mockEncrypted = JSON.stringify(mockObj);

    const decrypted = await this.crypto.decrypt(mockEncrypted, mode);

    hilog.info(DOMAIN, TAG, `restoreFromCloud: decrypted size=${decrypted.length}, mock restore completed`);

    return true;
  }

  async clearCloudStorage(): Promise<boolean> {
    hilog.info(DOMAIN, TAG, 'clearCloudStorage: mock clear');
    this.mockBackupRecords = [];
    AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, '');
    return true;
  }

  async listBackupHistory(): Promise<CloudBackupRecord[]> {
    hilog.info(DOMAIN, TAG, `listBackupHistory: returning ${this.mockBackupRecords.length} records`);
    return this.mockBackupRecords;
  }

  async restoreFromBackupRecord(recordId: string): Promise<boolean> {
    hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: id=${recordId}`);
    const record = this.mockBackupRecords.find((r: CloudBackupRecord): boolean => r.id === recordId);
    if (!record) {
      hilog.warn(DOMAIN, TAG, 'restoreFromBackupRecord: record not found');
      return false;
    }
    hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: mock restore from ${record.date}, tokens=${record.tokenCount}`);
    return true;
  }

  async deleteBackupRecord(recordId: string): Promise<boolean> {
    hilog.info(DOMAIN, TAG, `deleteBackupRecord: id=${recordId}`);
    const index = this.mockBackupRecords.findIndex((r: CloudBackupRecord): boolean => r.id === recordId);
    if (index === -1) {
      hilog.warn(DOMAIN, TAG, 'deleteBackupRecord: record not found');
      return false;
    }
    this.mockBackupRecords.splice(index, 1);
    hilog.info(DOMAIN, TAG, `deleteBackupRecord: deleted, remaining=${this.mockBackupRecords.length}`);
    return true;
  }

  get maxBackupCount(): number {
    return MAX_BACKUP_COUNT;
  }
}
