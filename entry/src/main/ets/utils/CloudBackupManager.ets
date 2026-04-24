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

/**
 * 云备份管理器
 * 
 * 提供基于 HarmonyOS 端云文件协同的令牌数据备份和恢复功能：
 * - 使用 context.cloudFileDir 作为云文件目录，文件自动上云
 * - 使用 cloudSync.FileSync 进行端云同步
 * - 使用 cloudSync.CloudFileCache 进行文件缓存
 * - 备份文件命名：backup_<timestamp>.enc
 * - 设备信息存储：device_info.json
 * - 最多保留5个备份文件，按时间倒序排列
 * 
 * @module CloudBackupManager
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppPreference, PREF_KEYS } from './AppPreference';
import { CloudBackupCrypto, CloudBackupCryptoMode, CloudBackupHeader, CloudBackupPayload, CloudBackupRecord } from './CloudBackupCrypto';
import { TokenStore } from './TokenStore';
import { TokenConfig } from './TokenConfig';
import { fileIo as fs, cloudSync, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { DeviceInfoHelper } from './DeviceInfoHelper';

/** 日志标签 */
const TAG = 'CloudBackupManager';
/** 日志域 */
const DOMAIN = 0xFF00;
/** 最大备份数量 */
const MAX_BACKUP_COUNT = 5;
/** 备份文件前缀 */
const BACKUP_FILE_PREFIX = 'otp_backup_';
/** 备份文件扩展名 */
const BACKUP_FILE_EXT = '.enc';
/** 备份元数据扩展名 */
const BACKUP_META_EXT = '.meta';
/** 设备信息文件名 */
const DEVICE_INFO_FILE = 'otp_device_info.json';

/**
 * 设备信息接口
 * 存储在 device_info.json 中，用于标识备份来源设备
 */
interface DeviceInfo {
  /** 设备唯一标识 */
  deviceId: string;
  /** 设备名称 */
  deviceName: string;
}

/**
 * 云备份管理器类
 * 
 * 功能说明：
 * 1. 备份：将所有令牌加密后保存到 cloudFileDir，自动同步到云端
 * 2. 恢复：从云端备份文件解密并恢复令牌数据
 * 3. 管理：查看、删除历史备份记录
 * 4. 同步：使用 cloudSync.FileSync 自动同步文件到云端
 * 
 * 使用示例：
 * ```ts
 * // 备份到云端
 * const success = await CloudBackupManager.getInstance().backupToCloud();
 * 
 * // 从云端恢复
 * const restored = await CloudBackupManager.getInstance().restoreFromCloud();
 * 
 * // 获取备份历史
 * const history = await CloudBackupManager.getInstance().listBackupHistory();
 * ```
 */
export class CloudBackupManager {
  /** 单例实例 */
  private static instance: CloudBackupManager | null = null;
  /** 加密工具实例 */
  private crypto: CloudBackupCrypto = CloudBackupCrypto.getInstance();
  /** 应用上下文 */
  private context: common.UIAbilityContext | undefined = undefined;
  /** 云文件目录路径 */
  private cloudDir: string = '';
  /** 端云同步实例 */
  private fileSync: cloudSync.FileSync | null = null;

  private constructor() {
  }

  /**
   * 获取 CloudBackupManager 单例实例
   * @returns CloudBackupManager 实例
   */
  static getInstance(): CloudBackupManager {
    if (!CloudBackupManager.instance) {
      CloudBackupManager.instance = new CloudBackupManager();
    }
    return CloudBackupManager.instance;
  }

  /**
   * 初始化云备份管理器
   * - 获取应用上下文
   * - 获取云文件目录路径
   * - 确保云目录存在
   * - 初始化设备信息
   */
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
      await this.initDeviceInfo();
    } catch (e) {
      hilog.error(DOMAIN, TAG, `init: error=${JSON.stringify(e)}`);
    }
  }

  /**
   * 确保云文件目录存在
   * 如果目录不存在则创建
   */
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

  /**
   * 初始化设备信息
   * 
   * 创建或更新 device_info.json 文件，存储设备ID和设备名称
   * 用于标识备份来源设备
   */
  private async initDeviceInfo(): Promise<void> {
    const deviceInfoPath = `${this.cloudDir}/${DEVICE_INFO_FILE}`;
    try {
      // 尝试读取现有设备信息文件
      const file = fs.openSync(deviceInfoPath, fs.OpenMode.READ_ONLY | fs.OpenMode.CREATE);
      const stat = await fs.stat(deviceInfoPath);
      if (stat.size > 0) {
        fs.closeSync(file);
        hilog.info(DOMAIN, TAG, 'initDeviceInfo: device info file already exists');
        return;
      }
      fs.closeSync(file);
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'initDeviceInfo: no existing file, creating new');
    }

    // 创建新的设备信息文件
    const newDeviceInfo: DeviceInfo = {
      deviceId: this.getDeviceId(),
      deviceName: this.getDeviceName(),
    };
    const text = JSON.stringify(newDeviceInfo);
    const file = fs.openSync(deviceInfoPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
    const writeLen = fs.writeSync(file.fd, text);
    fs.closeSync(file);
    hilog.info(DOMAIN, TAG, `initDeviceInfo: created, deviceId=${newDeviceInfo.deviceId}, deviceName=${newDeviceInfo.deviceName}, wrote=${writeLen}`);
  }

  /**
   * 获取设备ID
   * 
   * 使用 DeviceInfoHelper 获取设备唯一标识符（ODID）
   * 根据华为文档，ODID 可作为设备唯一标识，无需特殊权限
   * 
   * @returns 设备唯一标识
   */
  private getDeviceId(): string {
    return DeviceInfoHelper.getInstance().getDeviceId();
  }

  /**
   * 获取设备名称
   * 
   * 使用 DeviceInfoHelper 获取设备市场名称（marketName）
   * 
   * @returns 设备市场名称
   */
  private getDeviceName(): string {
    return DeviceInfoHelper.getInstance().getDeviceName();
  }

  /**
   * 获取设备信息
   * @returns 设备信息对象
   */
  private async getDeviceInfo(): Promise<DeviceInfo> {
    const deviceInfoPath = `${this.cloudDir}/${DEVICE_INFO_FILE}`;
    try {
      const file = fs.openSync(deviceInfoPath, fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(deviceInfoPath);
      const bufferArray = new ArrayBuffer(stat.size);
      const readLen = fs.readSync(file.fd, bufferArray);
      fs.closeSync(file);
      const uint8Array = new Uint8Array(bufferArray.slice(0, readLen));
      const text = buffer.from(uint8Array).toString('utf-8');
      return JSON.parse(text) as DeviceInfo;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `getDeviceInfo: error=${JSON.stringify(e)}`);
      return {
        deviceId: 'unknown_device',
        deviceName: 'Unknown Device',
      };
    }
  }

  /**
   * 备份令牌数据到云端
   * 
   * 流程：
   * 1. 检查是否已设置主密码
   * 2. 获取所有令牌数据
   * 3. 使用主密码加密令牌数据
   * 4. 将加密数据写入云文件目录
   * 5. 如果备份数量超过限制，删除最旧的备份
   * 6. 触发端云同步
   * 
   * @returns 是否备份成功
   */
  async backupToCloud(): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'backupToCloud: not initialized');
      return false;
    }

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

    hilog.info(DOMAIN, TAG, `backupToCloud: encrypted size=${encrypted.length}`);

    const now = Date.now();
    const d = new Date(now);
    const dateStr = `${d.getFullYear()}-${this.padZero(d.getMonth() + 1)}-${this.padZero(d.getDate())} ${this.padZero(d.getHours())}:${this.padZero(d.getMinutes())}`;
    const fileName = `${BACKUP_FILE_PREFIX}${now}${BACKUP_FILE_EXT}`;
    const filePath = `${this.cloudDir}/${fileName}`;

    try {
      const file = fs.openSync(filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const writeLen = fs.writeSync(file.fd, encrypted);
      fs.closeSync(file);
      hilog.info(DOMAIN, TAG, `backupToCloud: wrote ${writeLen} bytes to ${fileName}`);

      this.saveBackupMeta(fileName, tokens.length, encrypted.length);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `backupToCloud: write error=${JSON.stringify(e)}`);
      return false;
    }

    const records = await this.listBackupRecords();
    const deviceInfo = await this.getDeviceInfo();

    if (records.length >= MAX_BACKUP_COUNT) {
      const oldestRecord = records[records.length - 1];
      hilog.info(DOMAIN, TAG, `backupToCloud: max count reached, deleting oldest ${oldestRecord.id}`);
      await this.deleteBackupFile(oldestRecord.id);
    }

    const newRecord: CloudBackupRecord = {
      id: fileName,
      date: dateStr,
      timestamp: now,
      tokenCount: tokens.length,
      size: encrypted.length,
      encrypted: true,
      deviceId: deviceInfo.deviceId,
      deviceName: deviceInfo.deviceName,
    };

    await this.syncToCloud();
    AppPreference.setPreference(PREF_KEYS.CLOUD_SYNC_LAST_TIME, dateStr);

    hilog.info(DOMAIN, TAG, 'backupToCloud: completed successfully');
    return true;
  }

  /**
   * 从云端恢复令牌数据
   * 
   * 流程：
   * 1. 检查是否已设置主密码
   * 2. 查找最新的备份记录
   * 3. 调用 restoreFromBackupRecord 恢复数据
   * 
   * @returns 是否恢复成功
   */
  async restoreFromCloud(): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'restoreFromCloud: not initialized');
      return false;
    }

    const isMasterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    const mode = this.crypto.getMode(isMasterKeySet);

    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'restoreFromCloud: no encryption mode, aborting');
      return false;
    }

    hilog.info(DOMAIN, TAG, `restoreFromCloud: starting restore, mode=${mode}`);

    const records = await this.listBackupRecords();
    if (records.length === 0) {
      hilog.warn(DOMAIN, TAG, 'restoreFromCloud: no backup records found');
      return false;
    }

    const latestRecord = records[0];
    return await this.restoreFromBackupRecord(latestRecord.id);
  }

  /**
   * 清空云存储
   * 删除所有备份文件并重置同步时间
   * 
   * @returns 是否清空成功
   */
  async clearCloudStorage(): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'clearCloudStorage: not initialized');
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

  /**
   * 获取备份历史记录列表
   * 
   * @returns 备份记录数组，按时间倒序排列
   */
  async listBackupHistory(): Promise<CloudBackupRecord[]> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'listBackupHistory: not initialized');
      return [];
    }

    return await this.listBackupRecords();
  }

  /**
   * 检查并在需要时自动备份
   * 条件：云备份开关开启 + 主密码已设置 + 当天未备份
   */
  async checkAndAutoBackup(): Promise<void> {
    const enabled = AppPreference.getPreference(PREF_KEYS.APPEARANCE_HUAWEI_CLOUD_SYNC_ENABLE) as boolean;
    if (!enabled) {
      return;
    }

    const masterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    if (!masterKeySet) {
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

  /**
   * 从指定的备份记录恢复令牌数据
   * 
   * 流程：
   * 1. 检查文件位置，如果仅在云端（location=2），先缓存到本地
   * 2. 读取备份文件内容
   * 3. 使用主密码解密数据
   * 4. 解析 JSON 并更新令牌存储
   * 
   * @param recordId - 备份记录ID（文件名）
   * @returns 是否恢复成功
   */
  async restoreFromBackupRecord(recordId: string): Promise<boolean> {
    await this.init();
    if (!this.context || !this.cloudDir) {
      hilog.error(DOMAIN, TAG, 'restoreFromBackupRecord: not initialized');
      return false;
    }

    const isMasterKeySet = AppPreference.getPreference(PREF_KEYS.USE_MASTER_KEY_SET) as boolean;
    const mode = this.crypto.getMode(isMasterKeySet);

    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'restoreFromBackupRecord: no encryption mode, aborting');
      return false;
    }

    hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: id=${recordId}`);

    const filePath = `${this.cloudDir}/${recordId}`;
    try {
      const stat = await fs.stat(filePath);
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: file size=${stat.size}, location=${stat.location}`);

      if (stat.location === 2) {
        hilog.info(DOMAIN, TAG, 'restoreFromBackupRecord: file is in cloud, caching');
        await this.cacheFile(filePath);
      }

      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const bufferArray = new ArrayBuffer(stat.size);
      const readLen = fs.readSync(file.fd, bufferArray);
      fs.closeSync(file);

      const uint8Array = new Uint8Array(bufferArray.slice(0, readLen));
      const encrypted = buffer.from(uint8Array).toString('utf-8');
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: read ${readLen} bytes`);

      const decrypted = await this.crypto.decrypt(encrypted, mode);
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: decrypted size=${decrypted.length}`);

      const tokens: TokenConfig[] = JSON.parse(decrypted) as TokenConfig[];
      hilog.info(DOMAIN, TAG, `restoreFromBackupRecord: token count=${tokens.length}`);

      for (const token of tokens) {
        await TokenStore.getInstance().updateToken(token);
      }

      hilog.info(DOMAIN, TAG, 'restoreFromBackupRecord: completed successfully');
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `restoreFromBackupRecord: error=${JSON.stringify(e)}`);
      return false;
    }
  }

  /**
   * 删除指定的备份记录
   * 删除备份文件后触发端云同步
   * 
   * @param recordId - 备份记录ID（文件名）
   * @returns 是否删除成功
   */
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

  /**
   * 删除备份文件
   * 
   * @param fileName - 备份文件名
   * @returns 是否删除成功
   */
  private async deleteBackupFile(fileName: string): Promise<boolean> {
    const filePath = `${this.cloudDir}/${fileName}`;
    try {
      await fs.unlink(filePath);
      const metaPath = `${this.cloudDir}/${fileName.replace(BACKUP_FILE_EXT, BACKUP_META_EXT)}`;
      try {
        await fs.unlink(metaPath);
      } catch (_) {}
      hilog.info(DOMAIN, TAG, `deleteBackupFile: deleted ${fileName}`);
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `deleteBackupFile: error=${JSON.stringify(e)}`);
      return false;
    }
  }

  /**
   * 列出所有备份记录
   * 
   * 流程：
   * 1. 扫描云文件目录
   * 2. 筛选符合命名规则的备份文件（backup_<timestamp>.enc）
   * 3. 解析文件名获取时间戳
   * 4. 读取文件元数据（大小、位置等）
   * 5. 按时间倒序排列
   * 
   * @returns 备份记录数组，按时间倒序排列
   */
  private async listBackupRecords(): Promise<CloudBackupRecord[]> {
    const records: CloudBackupRecord[] = [];
    try {
      const files = fs.listFileSync(this.cloudDir);
      const deviceInfo = await this.getDeviceInfo();

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

          const d = new Date(timestamp);
          const dateStr = `${d.getFullYear()}-${this.padZero(d.getMonth() + 1)}-${this.padZero(d.getDate())} ${this.padZero(d.getHours())}:${this.padZero(d.getMinutes())}`;

          records.push({
            id: fileName,
            date: dateStr,
            timestamp: timestamp,
            tokenCount: this.readBackupMeta(fileName),
            size: stat.size,
            encrypted: true,
            deviceId: deviceInfo.deviceId,
            deviceName: deviceInfo.deviceName,
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

  /**
   * 触发端云同步
   * 使用 cloudSync.FileSync 将本地文件同步到云端
   */
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

  /**
   * 缓存云端文件到本地
   * 使用 cloudSync.CloudFileCache 将仅在云端的文件下载到本地
   * 
   * @param filePath - 文件路径
   */
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

  /**
   * 获取最大备份数量
   * @returns 最大备份数量（5）
   */
  get maxBackupCount(): number {
    return MAX_BACKUP_COUNT;
  }

  /**
   * 保存备份元数据
   * 将令牌数量等信息写入 .meta 文件
   */
  private saveBackupMeta(backupFileName: string, tokenCount: number, size: number): void {
    const metaPath = `${this.cloudDir}/${backupFileName.replace(BACKUP_FILE_EXT, BACKUP_META_EXT)}`;
    try {
      const meta = JSON.stringify({ tokenCount: tokenCount, size: size });
      const file = fs.openSync(metaPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, meta);
      fs.closeSync(file);
      hilog.info(DOMAIN, TAG, `saveBackupMeta: saved meta for ${backupFileName}, tokenCount=${tokenCount}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `saveBackupMeta: error=${JSON.stringify(e)}`);
    }
  }

  /**
   * 读取备份元数据中的令牌数量
   */
  private readBackupMeta(backupFileName: string): number {
    const metaPath = `${this.cloudDir}/${backupFileName.replace(BACKUP_FILE_EXT, BACKUP_META_EXT)}`;
    try {
      const file = fs.openSync(metaPath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(metaPath);
      const buf = new ArrayBuffer(stat.size);
      const readLen = fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text = buffer.from(new Uint8Array(buf.slice(0, readLen))).toString('utf-8');
      const meta = JSON.parse(text) as Record<string, number>;
      return meta['tokenCount'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /**
   * 数字补零
   * 将小于10的数字格式化为两位数
   * 
   * @param n - 数字
   * @returns 格式化后的字符串
   */
  private padZero(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }
}
