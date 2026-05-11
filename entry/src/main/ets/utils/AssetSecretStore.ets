import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'AssetSecretStore';
const DOMAIN = 0xFF00;

const ALIAS_PREFIX = 'opt_token_secret_';

const MAX_SECRET_BYTES = 900;

function stringToUint8Array(str: string): Uint8Array {
  const encoder = new util.TextEncoder();
  return encoder.encodeInto(str);
}

function uint8ArrayToString(arr: Uint8Array): string {
  const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  return decoder.decodeToString(arr, { stream: false });
}

/**
 * Asset Store Kit 关键资产存储封装.
 *
 * 将 TokenSecret 存储到 HarmonyOS ASSET（TEE 硬件保护 + AES256-GCM），
 * 替代加密 KV 数据库中的软件加密存储。
 *
 * 设计要点：
 * - ALIAS 格式: `{ALIAS_PREFIX}{TokenUUID}`，每条 Secret 一个 ASSET 条目
 * - SyncType.TRUSTED_DEVICE: 支持换机克隆时自动同步到新设备
 * - Accessibility.DEVICE_FIRST_UNLOCKED: 开机首次解锁后即可访问
 * - ConflictResolution.OVERWRITE: upsert 语义，写入时若已存在则覆盖
 * - Secret 大小限制: UTF-8 编码后 ≤ 900 字节（ASSET 单条上限 1KB，预留元数据空间）
 */
export class AssetSecretStore {
  private static instance: AssetSecretStore;

  private constructor() {}

  public static getInstance(): AssetSecretStore {
    if (!AssetSecretStore.instance) {
      AssetSecretStore.instance = new AssetSecretStore();
    }
    return AssetSecretStore.instance;
  }

  /** 检查 Secret 的 UTF-8 字节长度是否在 ASSET 存储限制内 */
  public isSecretSizeValid(secret: string): boolean {
    if (secret.length === 0) {
      return false;
    }
    return stringToUint8Array(secret).byteLength <= MAX_SECRET_BYTES;
  }

  /** 构建 ASSET ALIAS: {ALIAS_PREFIX}{tokenUUID} */
  private buildAlias(tokenUUID: string): Uint8Array {
    return stringToUint8Array(`${ALIAS_PREFIX}${tokenUUID}`);
  }

  /**
   * 写入或更新 Secret 到 ASSET.
   *
   * 使用 ConflictResolution.OVERWRITE 实现 upsert 语义，
   * 无论条目是否已存在都能正常写入。
   *
   * @returns true=写入成功, false=Secret 过大或 ASSET 写入失败（降级到 KV）
   */
  async upsertSecret(tokenUUID: string, secret: string): Promise<boolean> {
    if (!this.isSecretSizeValid(secret)) {
      hilog.warn(DOMAIN, TAG, `upsertSecret: secret size exceeds limit for ${tokenUUID}, skipping ASSET`);
      return false;
    }

    const attr: asset.AssetMap = new Map();
    attr.set(asset.Tag.SECRET, stringToUint8Array(secret));
    attr.set(asset.Tag.ALIAS, this.buildAlias(tokenUUID));
    attr.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attr.set(asset.Tag.SYNC_TYPE, asset.SyncType.TRUSTED_DEVICE);
    attr.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);

    try {
      await asset.add(attr);
      hilog.info(DOMAIN, TAG, `upsertSecret: saved ${tokenUUID}`);
      return true;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, `upsertSecret: failed for ${tokenUUID}, code=${err.code}, msg=${err.message}`);
      return false;
    }
  }

  /**
   * 从 ASSET 查询单条 Secret.
   *
   * @returns Secret 明文字符串, null=未找到或查询失败
   */
  async querySecret(tokenUUID: string): Promise<string | null> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.buildAlias(tokenUUID));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);

    try {
      const results: Array<asset.AssetMap> = await asset.query(query);
      if (results.length > 0) {
        const secretBytes = results[0].get(asset.Tag.SECRET) as Uint8Array;
        return uint8ArrayToString(secretBytes);
      }
      return null;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, `querySecret: failed for ${tokenUUID}, code=${err.code}, msg=${err.message}`);
      return null;
    }
  }

  /**
   * 从 ASSET 删除单条 Secret.
   *
   * 条目不存在时静默忽略（错误码 24000002），不视为异常。
   */
  async removeSecret(tokenUUID: string): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.buildAlias(tokenUUID));

    try {
      await asset.remove(query);
      hilog.info(DOMAIN, TAG, `removeSecret: removed ${tokenUUID}`);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, `removeSecret: failed for ${tokenUUID}, code=${err.code}, msg=${err.message}`);
    }
  }

  /**
   * 批量查询 ASSET 中的 Secret.
   *
   * 逐条查询（ASSET 不支持按 ALIAS 前缀批量查询），
   * 单条查询失败不影响其他条目。
   */
  async batchQuerySecrets(tokenUUIDs: string[]): Promise<Map<string, string>> {
    const result = new Map<string, string>();

    for (const uuid of tokenUUIDs) {
      const secret = await this.querySecret(uuid);
      if (secret !== null) {
        result.set(uuid, secret);
      }
    }

    hilog.info(DOMAIN, TAG, `batchQuerySecrets: found ${result.size}/${tokenUUIDs.length}`);
    return result;
  }
}
