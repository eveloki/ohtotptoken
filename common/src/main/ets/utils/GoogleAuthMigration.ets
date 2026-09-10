/**
 * Google Authenticator 迁移导入（`otpauth-migration://offline?data=...`）。
 *
 * 协议：Google 导出的是 base64url 编码的 `MigrationPayload`（proto3）。
 * 字段号与 `entry/src/main/cpp/proto/google_auth.proto` 完全一致，
 * 解码复用与 Steam 相同的手写 protobuf codec（`ProtoReader`），
 * 因此不再需要 protobufjs 生成代码或 nanopb 原生库。
 *
 * 与旧实现（protobufjs + libotpcutils.so 兜底）相比修正：
 * - `data=` 是 **base64url**（`-_`，常无 padding），旧实现按标准 base64 解码会失败
 * - `batch_size/batch_index/batch_id` 会被真正合并（大导出会拆成多张二维码，旧实现直接丢令牌）
 * - proto3 枚举缺省值回退到 SHA1 / 6 位 / TOTP，不再出现 `digits=0` 算出 1 位码
 */

import { HMACAlgorithm, base32Encode } from './TokenUtils';
import { otpType, TokenConfig } from './TokenConfig';
import { ProtoReader } from './proto/ProtoReader';

// ------------------------------------------------------------ schema

/** MigrationPayload.Algorithm */
export const GA_ALGORITHM_UNSPECIFIED: number = 0;
export const GA_ALGORITHM_SHA1: number = 1;
export const GA_ALGORITHM_SHA256: number = 2;
export const GA_ALGORITHM_SHA512: number = 3;
export const GA_ALGORITHM_MD5: number = 4;

/** MigrationPayload.DigitCount */
export const GA_DIGITS_UNSPECIFIED: number = 0;
export const GA_DIGITS_SIX: number = 1;
export const GA_DIGITS_EIGHT: number = 2;
export const GA_DIGITS_SEVEN: number = 3;

/** MigrationPayload.OtpType */
export const GA_TYPE_UNSPECIFIED: number = 0;
export const GA_TYPE_HOTP: number = 1;
export const GA_TYPE_TOTP: number = 2;

/** 单条 OtpParameters */
export class GoogleAuthOtpParameters {
  secret: Uint8Array = new Uint8Array(0);
  name: string = '';
  issuer: string = '';
  algorithm: number = GA_ALGORITHM_UNSPECIFIED;
  digits: number = GA_DIGITS_UNSPECIFIED;
  type: number = GA_TYPE_UNSPECIFIED;
  counter: bigint = 0n;
  uniqueId: string = '';
}

/** MigrationPayload */
export class GoogleAuthMigrationPayload {
  otpParameters: GoogleAuthOtpParameters[] = [];
  version: number = 0;
  /** >1 表示该导出被拆成多张二维码 */
  batchSize: number = 0;
  batchIndex: number = 0;
  batchId: number = 0;
}

// ------------------------------------------------------------ 解码

function parseOtpParameters(reader: ProtoReader): GoogleAuthOtpParameters {
  const item = new GoogleAuthOtpParameters();
  while (reader.next()) {
    switch (reader.field()) {
      case 1:
        item.secret = reader.readBytes();
        break;
      case 2:
        item.name = reader.readString();
        break;
      case 3:
        item.issuer = reader.readString();
        break;
      case 4:
        item.algorithm = reader.readInt32();
        break;
      case 5:
        item.digits = reader.readInt32();
        break;
      case 6:
        item.type = reader.readInt32();
        break;
      case 7:
        // int64：负数按 64 位补码解释
        item.counter = BigInt.asIntN(64, reader.readVarint());
        break;
      case 8:
        item.uniqueId = reader.readString();
        break;
      default:
        reader.skip();
        break;
    }
  }
  return item;
}

/** 解析 MigrationPayload 字节流（不含 base64 解码） */
export function parseMigrationPayload(bytes: Uint8Array): GoogleAuthMigrationPayload {
  const payload = new GoogleAuthMigrationPayload();
  const reader = new ProtoReader(bytes);
  while (reader.next()) {
    switch (reader.field()) {
      case 1:
        payload.otpParameters.push(parseOtpParameters(reader.readMessage()));
        break;
      case 2:
        payload.version = reader.readInt32();
        break;
      case 3:
        payload.batchSize = reader.readInt32();
        break;
      case 4:
        payload.batchIndex = reader.readInt32();
        break;
      case 5:
        payload.batchId = reader.readInt32();
        break;
      default:
        reader.skip();
        break;
    }
  }
  return payload;
}

const BASE64_CHARS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/**
 * base64url → 字节。
 *
 * Google 的 `data=` 使用 URL-safe 字母表（`-` `_`）且通常不带 `=` 补位，
 * 标准 base64 解码器（`util.Base64Helper` 默认 BASIC）会直接失败。
 */
export function decodeBase64Url(input: string): Uint8Array {
  const normalized: string = input.trim().replace(/-/g, '+').replace(/_/g, '/').replace(/[\s]/g, '');
  const out: number[] = [];
  let buffer: number = 0;
  let bits: number = 0;
  for (let i = 0; i < normalized.length; i++) {
    const ch: string = normalized.charAt(i);
    if (ch === '=') {
      break;
    }
    const value: number = BASE64_CHARS.indexOf(ch);
    if (value < 0) {
      continue;
    }
    buffer = (buffer << 6) | value;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((buffer >> bits) & 0xff);
    }
  }
  return new Uint8Array(out);
}

// ------------------------------------------------------------ 映射

/** proto3 零值（UNSPECIFIED）与未知值都回退到 SHA1（RFC 6238 默认） */
export function googleAuthAlgorithm(value: number): HMACAlgorithm {
  switch (value) {
    case GA_ALGORITHM_SHA256:
      return 'SHA256';
    case GA_ALGORITHM_SHA512:
      return 'SHA512';
    case GA_ALGORITHM_MD5:
      return 'MD5';
    default:
      return 'SHA1';
  }
}

/** 缺省 6 位；显式 7/8 位才改变 */
export function googleAuthDigits(value: number): number {
  switch (value) {
    case GA_DIGITS_EIGHT:
      return 8;
    case GA_DIGITS_SEVEN:
      return 7;
    default:
      return 6;
  }
}

export function googleAuthOtpType(value: number): otpType {
  return value === GA_TYPE_HOTP ? otpType.HOTP : otpType.TOTP;
}

/** OtpParameters → TokenConfig */
export function googleAuthOtpToTokenConfig(item: GoogleAuthOtpParameters): TokenConfig {
  const token = new TokenConfig();
  token.TokenSecret = base32Encode(item.secret);
  token.TokenIssuer = item.issuer.length > 0 ? item.issuer : 'Unknown';
  token.TokenName = item.name.length > 0 ? item.name : 'Unknown';
  token.TokenAlgorithm = googleAuthAlgorithm(item.algorithm);
  token.TokenDigits = googleAuthDigits(item.digits);
  token.TokenType = googleAuthOtpType(item.type);
  token.TokenPeriod = 30;
  // TokenCounter 是 number：int64 超过 2^53 时按安全范围截断（HOTP 实际不会这么大）
  const counter: bigint = item.counter > 0n ? item.counter : 0n;
  token.TokenCounter = counter > 9007199254740991n ? Number(9007199254740991n) : Number(counter);

  // Steam 的迁移条目必须按 Steam 变体处理（5 位字母码 / SHA1 / 30s）
  if (token.TokenIssuer.toLowerCase() === 'steam') {
    token.TokenType = otpType.Steam;
    token.TokenAlgorithm = 'SHA1';
    token.TokenPeriod = 30;
    token.TokenDigits = 10;
  }
  return token;
}

// ------------------------------------------------------------ 批次合并

export const GA_MIGRATION_OK: number = 0;
/** 解析成功但没有任何 otp_parameters */
export const GA_MIGRATION_EMPTY: number = 1;
/** base64 或 protobuf 解析失败 */
export const GA_MIGRATION_PARSE_FAILED: number = 2;

export class GoogleAuthMigrationResult {
  /** 本批次（或已合并的整批）令牌；`complete=false` 时为空 */
  tokens: TokenConfig[] = [];
  errorCode: number = GA_MIGRATION_OK;
  /** 1 表示单张二维码 */
  batchSize: number = 1;
  /** 已收集到的分片数 */
  batchReceived: number = 0;
  /** 批次是否已收齐（可以落库） */
  complete: boolean = true;
}

/** batchId → (batchIndex → 条目)，支持用户连续扫描多张二维码时合并 */
const pendingBatches: Map<number, Map<number, GoogleAuthOtpParameters[]>> =
  new Map<number, Map<number, GoogleAuthOtpParameters[]>>();

/** 清空未完成的批次（用户取消导入时调用） */
export function resetGoogleAuthBatch(): void {
  pendingBatches.clear();
}

function collectBatched(payload: GoogleAuthMigrationPayload): GoogleAuthMigrationResult {
  const result = new GoogleAuthMigrationResult();
  result.batchSize = payload.batchSize;
  let batch = pendingBatches.get(payload.batchId);
  if (batch === undefined) {
    batch = new Map<number, GoogleAuthOtpParameters[]>();
    pendingBatches.set(payload.batchId, batch);
  }
  batch.set(payload.batchIndex, payload.otpParameters);
  result.batchReceived = batch.size;

  if (batch.size < payload.batchSize) {
    result.complete = false;
    return result;
  }

  // 按 batch_index 升序拼接，避免用户扫描顺序不同导致令牌顺序错乱
  const indexes: number[] = [];
  batch.forEach((_items: GoogleAuthOtpParameters[], index: number) => {
    indexes.push(index);
  });
  indexes.sort((a: number, b: number) => a - b);
  for (let i = 0; i < indexes.length; i++) {
    const items: GoogleAuthOtpParameters[] | undefined = batch.get(indexes[i]);
    if (items !== undefined) {
      for (let j = 0; j < items.length; j++) {
        result.tokens.push(googleAuthOtpToTokenConfig(items[j]));
      }
    }
  }
  pendingBatches.delete(payload.batchId);
  result.complete = true;
  return result;
}

/**
 * 解析一条 `otpauth-migration://offline?data=...` 的 data 参数。
 *
 * @param data URL 编码后的 base64url 字符串（调用方负责 decodeURIComponent）
 */
export function decodeGoogleAuthMigration(data: string): GoogleAuthMigrationResult {
  const result = new GoogleAuthMigrationResult();
  if (data.length === 0) {
    result.errorCode = GA_MIGRATION_EMPTY;
    return result;
  }

  let payload: GoogleAuthMigrationPayload;
  try {
    payload = parseMigrationPayload(decodeBase64Url(data));
  } catch (error) {
    result.errorCode = GA_MIGRATION_PARSE_FAILED;
    return result;
  }

  if (payload.otpParameters.length === 0) {
    result.errorCode = GA_MIGRATION_EMPTY;
    return result;
  }

  if (payload.batchSize <= 1) {
    result.tokens = payload.otpParameters.map((item: GoogleAuthOtpParameters) =>
      googleAuthOtpToTokenConfig(item));
    return result;
  }

  return collectBatched(payload);
}
