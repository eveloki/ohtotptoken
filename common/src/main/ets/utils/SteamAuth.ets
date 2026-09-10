import { maFile } from './SteamUtils';

/** ASSET 单条上限 900 字节，分片时留出元数据余量 */
export const STEAM_SECRET_CHUNK_BYTES: number = 800;

/**
 * Steam 账号授权数据（登录/迁移得到的验证器凭证）。
 *
 * 与旧的 `maFile` 相比：
 * - 增加 `steamid`（扫码登录与交易确认必需）、`refreshToken`（换取 access_token）
 * - 字段名改为 camelCase，避免与 mafile 的 snake_case 混用
 * - **敏感字段（identitySecret / revocationCode / refreshToken）不随 TokenConfig 序列化**，
 *   由 SteamSecretStore 单独写入 ASSET（TEE）
 *
 * 兼容：读取旧数据时用 `fromMaFile()` 转换，写回旧路径时用 `toMaFile()`。
 */
export class SteamAuth {
  accountName: string = '';
  /** SteamID64（字符串保存，避免 bigint 在 JSON 序列化中的问题） */
  steamid: string = '';
  /** 交易确认接口的 `p=` 参数，必须与添加时一致 */
  deviceId: string = '';
  serialNumber: string = '';
  tokenGid: string = '';
  uri: string = '';
  serverTime: number = 0;
  steamguardScheme: number = 1;

  // ---- 以下字段仅内存持有，持久化走 ASSET ----
  /** base64，用于交易确认签名（HMAC-SHA1） */
  identitySecret: string = '';
  /** 撤销验证器用 */
  revocationCode: string = '';
  /** 换取 access_token（JWT，可能超过 ASSET 单条上限，需分片） */
  refreshToken: string = '';
  /** 短期缓存，不持久化 */
  accessToken: string = '';
  accessTokenExp: number = 0;

  /** 是否具备扫码登录/交易确认所需的完整凭证 */
  hasConfirmationCredentials(): boolean {
    return this.refreshToken.length > 0 && this.identitySecret.length > 0
      && this.deviceId.length > 0 && this.steamid.length > 0;
  }

  /** 是否具备撤销验证器的凭证 */
  canRevoke(): boolean {
    return this.revocationCode.length > 0 && this.refreshToken.length > 0 && this.steamid.length > 0;
  }

  /** 清空内存中的敏感字段（页面退出时调用） */
  clearSecrets(): void {
    this.identitySecret = '';
    this.revocationCode = '';
    this.refreshToken = '';
    this.accessToken = '';
    this.accessTokenExp = 0;
  }

  copy(): SteamAuth {
    const out = new SteamAuth();
    out.accountName = this.accountName;
    out.steamid = this.steamid;
    out.deviceId = this.deviceId;
    out.serialNumber = this.serialNumber;
    out.tokenGid = this.tokenGid;
    out.uri = this.uri;
    out.serverTime = this.serverTime;
    out.steamguardScheme = this.steamguardScheme;
    out.identitySecret = this.identitySecret;
    out.revocationCode = this.revocationCode;
    out.refreshToken = this.refreshToken;
    out.accessToken = this.accessToken;
    out.accessTokenExp = this.accessTokenExp;
    return out;
  }

  /** 剥离敏感字段的副本（手表同步/日志用） */
  withoutSecrets(): SteamAuth {
    const out = this.copy();
    out.clearSecrets();
    return out;
  }

  /** 由旧版 mafile 数据转换（兼容历史令牌） */
  static fromMaFile(file: maFile): SteamAuth {
    const out = new SteamAuth();
    out.accountName = file.account_name;
    out.deviceId = file.device_id;
    out.serialNumber = file.serial_number;
    out.tokenGid = file.token_gid;
    out.uri = file.uri;
    out.serverTime = file.server_time;
    out.identitySecret = file.identity_secret;
    out.revocationCode = file.revocation_code;
    // 旧 mafile 没有 steamid / refresh_token，扫码登录与交易确认不可用
    return out;
  }

  /**
   * 由「裸对象」重建实例。
   *
   * 关键：`JSON.parse` 得到的 SteamAuth 只有数据字段、**没有原型方法**，
   * 直接调用 `auth.hasConfirmationCredentials()` 会抛
   * `TypeError: undefined is not callable` 并导致应用被系统杀掉。
   * 凡是来自 KV / 备份 / 手表同步的 SteamAuth 都必须先经过本方法。
   */
  static fromPlain(raw: SteamAuth | undefined): SteamAuth | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const out = new SteamAuth();
    out.accountName = raw.accountName ?? '';
    out.steamid = raw.steamid ?? '';
    out.deviceId = raw.deviceId ?? '';
    out.serialNumber = raw.serialNumber ?? '';
    out.tokenGid = raw.tokenGid ?? '';
    out.uri = raw.uri ?? '';
    out.serverTime = raw.serverTime ?? 0;
    out.steamguardScheme = raw.steamguardScheme ?? 1;
    out.identitySecret = raw.identitySecret ?? '';
    out.revocationCode = raw.revocationCode ?? '';
    out.refreshToken = raw.refreshToken ?? '';
    out.accessToken = raw.accessToken ?? '';
    out.accessTokenExp = raw.accessTokenExp ?? 0;
    return out;
  }

  /** 转回 mafile 结构（编辑页面复用旧组件时使用） */
  toMaFile(): maFile {
    const out = new maFile();
    out.account_name = this.accountName;
    out.device_id = this.deviceId;
    out.serial_number = this.serialNumber;
    out.token_gid = this.tokenGid;
    out.uri = this.uri;
    out.server_time = this.serverTime;
    out.identity_secret = this.identitySecret;
    out.revocation_code = this.revocationCode;
    return out;
  }
}

/**
 * 能力判定（自由函数版）。
 *
 * 用「字段判断」而不是调用 `auth.hasConfirmationCredentials()`：
 * 即使某条路径漏了 `SteamAuth.fromPlain()`，这里也不会抛异常把应用搞崩
 * （菜单构建期抛异常 = 应用被系统杀掉）。
 */
export function steamAuthHasConfirmationCredentials(auth: SteamAuth | undefined): boolean {
  if (auth === undefined || auth === null) {
    return false;
  }
  return (auth.refreshToken ?? '').length > 0 && (auth.identitySecret ?? '').length > 0
    && (auth.deviceId ?? '').length > 0 && (auth.steamid ?? '').length > 0;
}

/** 是否具备撤销验证器的凭证（自由函数版，理由同上） */
export function steamAuthCanRevoke(auth: SteamAuth | undefined): boolean {
  if (auth === undefined || auth === null) {
    return false;
  }
  return (auth.revocationCode ?? '').length > 0 && (auth.refreshToken ?? '').length > 0
    && (auth.steamid ?? '').length > 0;
}

/** UTF-8 字节长度（用于 ASSET 分片判断） */export function utf8ByteLength(text: string): number {
  let bytes: number = 0;
  for (let i = 0; i < text.length; i++) {
    const code: number = text.charCodeAt(i);
    if (code < 0x80) {
      bytes += 1;
    } else if (code < 0x800) {
      bytes += 2;
    } else if (code >= 0xd800 && code <= 0xdbff) {
      // 代理对（emoji 等）算 4 字节，并跳过低位代理
      bytes += 4;
      i += 1;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

/**
 * 按 UTF-8 字节上限切分字符串。
 *
 * refresh_token 是 JWT，长度可能超过 ASSET 单条 900 字节限制，
 * 切成多条 ASSET 条目按序保存（`..._rt_0`, `..._rt_1`, ...）。
 */
export function splitSecretChunks(value: string, maxBytes: number = STEAM_SECRET_CHUNK_BYTES): string[] {
  if (value.length === 0) {
    return [];
  }
  const chunks: string[] = [];
  let current: string = '';
  let currentBytes: number = 0;
  for (let i = 0; i < value.length; i++) {
    const ch: string = value.charAt(i);
    const chBytes: number = utf8ByteLength(ch);
    if (currentBytes + chBytes > maxBytes && current.length > 0) {
      chunks.push(current);
      current = '';
      currentBytes = 0;
    }
    current += ch;
    currentBytes += chBytes;
  }
  if (current.length > 0) {
    chunks.push(current);
  }
  return chunks;
}

/** 合并分片；缺失分片（中间为空）时返回空串，避免拼出错误的 token */
export function joinSecretChunks(chunks: string[]): string {
  if (chunks.length === 0) {
    return '';
  }
  let out: string = '';
  for (let i = 0; i < chunks.length; i++) {
    if (chunks[i].length === 0) {
      return '';
    }
    out += chunks[i];
  }
  return out;
}
