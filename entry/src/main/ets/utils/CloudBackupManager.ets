/*
 * Copyright (c) 2023-2024 ohtotptoken Project Contributors
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppPreference, PREF_KEYS } from './AppPreference';
import { CloudBackupCrypto, CloudBackupCryptoMode, CloudBackupRecord, CloudBackupTokenError } from './CloudBackupCrypto';
import { TokenStore } from './TokenStore';
import { TokenConfig } from './TokenConfig';
import { fileIo as fs, cloudSync, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { DeviceInfoHelper } from './DeviceInfoHelper';
import { HuaweiAccountManager } from './HuaweiAccountManager';

const TAG = 'CloudBackupManager';
const DOMAIN = 0xFF00;
const MAX_BACKUP_COUNT = 5;
const BACKUP_FILE_PREFIX = 'otp_backup_';
const BACKUP_FILE_EXT = '.enc';

export class CloudBackupManager {
  private static instance: CloudBackupManager | null = null;
  private crypto: CloudBackupCrypto = CloudBackupCrypto.getInstance();
  private context: common.UIAbilityContext | undefined = undefined;
  private cloudDir: string = '';
  private fileSync: cloudSync.FileSync | null = null;

  private constructor() {
  }

  static getInstance(): CloudBackupManager {
    if (!CloudBackupManager.instance) {
      CloudBackupManager.instance = new CloudBackupManager();
    }
    return CloudBackupManager.instance;
  }

  async init(): Promise<void> {
    if (this.context) {
      return;
    }
    this.context = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;
    if (!this.context) {
      hilog.error(DOMAIN, TAG, 'init: failed to get appContext');
      return;
    }

    try {
      this.cloudDir = this.context.cloudFileDir;
      hilog.info(DOMAIN, TAG, `init: cloudDir=${this.cloudDir}`);
      await this.ensureCloudDirExists();
    } catch (e) {
      hilog.error(DOMAIN, TAG, `init: error=${JSON.stringify(e)}`);
    }
  }

  private async ensureCloudDirExists(): Promise<void> {
    try {
      const stat = await fs.stat(this.cloudDir);
      hilog.info(DOMAIN, TAG, `ensureCloudDirExists: exists, location=${stat.location}`);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `ensureCloudDirExists: not exist, creating`);
      try {
        await fs.mkdir(this.cloudDir);
        hilog.info(DOMAIN, TAG, 'ensureCloudDirExists: created');
      } catch (err) {
        hilog.error(DOMAIN, TAG, `ensureCloudDirExists: create error=${JSON.stringify(err)}`);
      }
    }
  }

  async backupToCloud(): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'backupToCloud: not initialized');
      return false;
    }

    const accountMgr = HuaweiAccountManager.getInstance();
    if (!accountMgr.userLogin) {
      hilog.warn(DOMAIN, TAG, 'backupToCloud: Huawei account not logged in, aborting');
      return false;
    }

    const encryptKey = accountMgr.userAccount.unionId;
    const mode = this.crypto.getMode(true);
    const deviceId = DeviceInfoHelper.getInstance().getDeviceId();
    const deviceName = DeviceInfoHelper.getInstance().getDeviceName();

    hilog.info(DOMAIN, TAG, `backupToCloud: starting backup, mode=${mode}`);

    const tokens = await TokenStore.getInstance().getTokens();
    const plaintext = JSON.stringify(tokens);
    const now = Date.now();

    hilog.info(DOMAIN, TAG, `backupToCloud: token count=${tokens.length}`);

    const token = await this.crypto.encrypt(
      plaintext, mode, encryptKey,
      tokens.length, now,
      deviceId, deviceName,
    );

    hilog.info(DOMAIN, TAG, `backupToCloud: token size=${token.length}`);

    const fileName = `${BACKUP_FILE_PREFIX}${now}${BACKUP_FILE_EXT}`;
    const filePath = `${this.cloudDir}/${fileName}`;

    try {
      const file = fs.openSync(filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const writeLen = fs.writeSync(file.fd, token);
      fs.closeSync(file);
      hilog.info(DOMAIN, TAG, `backupToCloud: wrote ${writeLen} bytes to ${fileName}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `backupToCloud: write error=${JSON.stringify(e)}`);
      return false;
    }

    const records = await this.listBackupRecords();
    const deviceRecords = records.filter(r => r.deviceId === deviceId);
    if (deviceRecords.length > MAX_BACKUP_COUNT) {
      const oldestRecord = deviceRecords[deviceRecords.length - 1];
      hilog.info(DOMAIN, TAG, `backupToCloud: max count reached, deleting oldest ${oldestRecord.id}`);
      await this.deleteBackupFile(oldestRecord.id);
    }

    await this.syncToCloud();

    const d = new Date(now);
    const dateStr = `${d.getFullYear()}-${this.padZero(d.getMonth() + 1)}-${this.padZero(d.getDate())} ${this.padZero(d.getHours())}:${this.padZero(d.getMinutes())}`;
    AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, dateStr);

    hilog.info(DOMAIN, TAG, 'backupToCloud: completed successfully');
    return true;
  }

  async restoreFromCloud(): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'restoreFromCloud: not initialized');
      return false;
    }

    const accountMgr = HuaweiAccountManager.getInstance();
    if (!accountMgr.userLogin) {
      hilog.warn(DOMAIN, TAG, 'restoreFromCloud: Huawei account not logged in, aborting');
      return false;
    }

    hilog.info(DOMAIN, TAG, 'restoreFromCloud: starting restore');

    const records = await this.listBackupRecords();
    if (records.length === 0) {
      hilog.warn(DOMAIN, TAG, 'restoreFromCloud: no backup records found');
      return false;
    }

    const latestRecord = records[0];
    return await this.restoreFromBackupRecord(latestRecord.id);
  }

  async clearCloudStorage(): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'clearCloudStorage: not initialized');
      return false;
    }

    if (!HuaweiAccountManager.getInstance().userLogin) {
      hilog.warn(DOMAIN, TAG, 'clearCloudStorage: Huawei account not logged in, aborting');
      return false;
    }

    hilog.info(DOMAIN, TAG, 'clearCloudStorage: clearing');

    try {
      const records = await this.listBackupRecords();
      for (const record of records) {
        await this.deleteBackupFile(record.id);
      }
      AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, '');
      hilog.info(DOMAIN, TAG, 'clearCloudStorage: completed');
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `clearCloudStorage: error=${JSON.stringify(e)}`);
      return false;
    }
  }

  async clearDeviceCloudStorage(): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'clearDeviceCloudStorage: not initialized');
      return false;
    }

    if (!HuaweiAccountManager.getInstance().userLogin) {
      hilog.warn(DOMAIN, TAG, 'clearDeviceCloudStorage: Huawei account not logged in, aborting');
      return false;
    }

    const deviceId = DeviceInfoHelper.getInstance().getDeviceId();
    hilog.info(DOMAIN, TAG, `clearDeviceCloudStorage: clearing device=${deviceId}`);

    try {
      const records = await this.listBackupRecords();
      const deviceRecords = records.filter((r: CloudBackupRecord) => r.deviceId === deviceId);
      for (const record of deviceRecords) {
        await this.deleteBackupFile(record.id);
      }
      AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, '');
      hilog.info(DOMAIN, TAG, `clearDeviceCloudStorage: completed, deleted ${deviceRecords.length}`);
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `clearDeviceCloudStorage: error=${JSON.stringify(e)}`);
      return false;
    }
  }

  async listBackupHistory(): Promise<CloudBackupRecord[]> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'listBackupHistory: not initialized');
      return [];
    }

    return await this.listBackupRecords();
  }

  async checkAndAutoBackup(): Promise<void> {
    const enabled = AppPreference.getPreference(PREF_KEYS.APPEARANCE_HUAWEI_CLOUD_SYNC_ENABLE) as boolean;
    if (!enabled) {
      return;
    }

    if (!HuaweiAccountManager.getInstance().userLogin) {
      return;
    }

    const lastTime = AppPreference.getPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME) as string;
    if (lastTime && lastTime.length >= 10) {
      const today = new Date();
      const todayStr = `${today.getFullYear()}-${this.padZero(today.getMonth() + 1)}-${this.padZero(today.getDate())}`;
      if (lastTime.startsWith(todayStr)) {
        hilog.info(DOMAIN, TAG, 'checkAndAutoBackup: already backed up today, skipping');
        return;
      }
    }

    hilog.info(DOMAIN, TAG, 'checkAndAutoBackup: starting auto backup');
    const success = await this.backupToCloud();
    hilog.info(DOMAIN, TAG, `checkAndAutoBackup: result=${success}`);
  }

  async restoreFromBackupRecord(recordId: string): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'restoreFromBackupRecord: not initialized');
      return false;
    }

    const accountMgr = HuaweiAccountManager.getInstance();
    if (!accountMgr.userLogin) {
      hilog.warn(DOMAIN, TAG, 'restoreFromBackupRecord: Huawei account not logged in, aborting');
      return false;
    }

    const encryptKey = accountMgr.userAccount.unionId;
    const mode = this.crypto.getMode(true);

    hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: id=${recordId}`);

    const filePath = `${this.cloudDir}/${recordId}`;
    try {
      const stat = await fs.stat(filePath);
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: file size=${stat.size}, location=${stat.location}`);

      if (stat.location === 2) {
        hilog.info(DOMAIN, TAG, 'restoreFromBackupRecord: file is in cloud, caching');
        await this.cacheFile(filePath);
      }

      const tokenContent = await this.readFileContent(filePath);
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: read ${tokenContent.length} chars`);

      const decrypted = await this.crypto.decrypt(tokenContent, mode, encryptKey);
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: decrypted size=${decrypted.length}`);

      const tokens: TokenConfig[] = JSON.parse(decrypted) as TokenConfig[];
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: token count=${tokens.length}`);

      for (const token of tokens) {
        await TokenStore.getInstance().updateToken(token);
      }

      hilog.info(DOMAIN, TAG, 'restoreFromBackupRecord: completed successfully');
      return true;
    } catch (e) {
      if (e instanceof CloudBackupTokenError) {
        hilog.error(DOMAIN, TAG, `restoreFromBackupRecord: token error: ${e.message}`);
      } else {
        hilog.error(DOMAIN, TAG, `restoreFromBackupRecord: error=${JSON.stringify(e)}`);
      }
      return false;
    }
  }

  async deleteBackupRecord(recordId: string): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'deleteBackupRecord: not initialized');
      return false;
    }

    hilog.info(DOMAIN, TAG, `deleteBackupRecord: id=${recordId}`);
    const result = await this.deleteBackupFile(recordId);
    if (result) {
      await this.syncToCloud();
    }
    return result;
  }

  private async deleteBackupFile(fileName: string): Promise<boolean> {
    const filePath = `${this.cloudDir}/${fileName}`;
    try {
      await fs.unlink(filePath);
      hilog.info(DOMAIN, TAG, `deleteBackupFile: deleted ${fileName}`);
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `deleteBackupFile: error=${JSON.stringify(e)}`);
      return false;
    }
  }

  private async listBackupRecords(): Promise<CloudBackupRecord[]> {
    const records: CloudBackupRecord[] = [];
    try {
      const files = fs.listFileSync(this.cloudDir);

      for (const fileName of files) {
        if (!fileName.startsWith(BACKUP_FILE_PREFIX) || !fileName.endsWith(BACKUP_FILE_EXT)) {
          continue;
        }

        const filePath = `${this.cloudDir}/${fileName}`;
        try {
          const stat = await fs.stat(filePath);
          const timestampStr = fileName.replace(BACKUP_FILE_PREFIX, '').replace(BACKUP_FILE_EXT, '');
          const timestamp = parseInt(timestampStr);

          if (isNaN(timestamp)) {
            continue;
          }

          let tokenCount = 0;
          let fileSize = stat.size;
          let deviceId = '';
          let deviceName = '';
          try {
            const tokenContent = await this.readFileContent(filePath);
            const header = this.crypto.parseTokenHeader(tokenContent);
            tokenCount = header.tokenCount;
            fileSize = header.size;
            deviceId = header.deviceId;
            deviceName = header.deviceName;
          } catch (e) {
            hilog.warn(DOMAIN, TAG, `listBackupRecords: parse header failed for ${fileName}, using file stat`);
          }

          const d = new Date(timestamp);
          const dateStr = `${d.getFullYear()}-${this.padZero(d.getMonth() + 1)}-${this.padZero(d.getDate())} ${this.padZero(d.getHours())}:${this.padZero(d.getMinutes())}`;

          records.push({
            id: fileName,
            date: dateStr,
            timestamp: timestamp,
            tokenCount: tokenCount,
            size: fileSize,
            encrypted: true,
            deviceId: deviceId,
            deviceName: deviceName,
            location: stat.location,
          });
        } catch (e) {
          hilog.error(DOMAIN, TAG, `listBackupRecords: stat error for ${fileName}=${JSON.stringify(e)}`);
        }
      }

      records.sort((a, b) => b.timestamp - a.timestamp);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `listBackupRecords: error=${JSON.stringify(e)}`);
    }

    hilog.info(DOMAIN, TAG, `listBackupRecords: returning ${records.length} records`);
    return records;
  }

  private async readFileContent(filePath: string): Promise<string> {
    const stat = await fs.stat(filePath);
    const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
    const bufferArray = new ArrayBuffer(stat.size);
    const readLen = fs.readSync(file.fd, bufferArray);
    fs.closeSync(file);
    const uint8Array = new Uint8Array(bufferArray.slice(0, readLen));
    return buffer.from(uint8Array).toString('utf-8');
  }

  private async syncToCloud(): Promise<void> {
    if (!this.fileSync) {
      this.fileSync = new cloudSync.FileSync();
    }

    try {
      await this.fileSync.start();
      hilog.info(DOMAIN, TAG, 'syncToCloud: started');
    } catch (e) {
      hilog.error(DOMAIN, TAG, `syncToCloud: error=${JSON.stringify(e)}`);
    }
  }

  private async cacheFile(filePath: string): Promise<void> {
    const uri = fileUri.getUriFromPath(filePath);
    const cache = new cloudSync.CloudFileCache();
    try {
      await cache.start(uri);
      hilog.info(DOMAIN, TAG, `cacheFile: cached ${filePath}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `cacheFile: error=${JSON.stringify(e)}`);
    }
  }

  get maxBackupCount(): number {
    return MAX_BACKUP_COUNT;
  }

  private padZero(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }
}
