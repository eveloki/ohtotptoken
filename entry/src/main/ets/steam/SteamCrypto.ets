/**
 * Steam 协议所需的加密与编码工具（ArkTS，纯实现）。
 *
 * 设计取舍：
 * - 哈希/HMAC 走 `PureHash.ets`（纯 ArkTS）而非 `@kit.CryptoArchitectureKit`——
 *   Previewer/LocalUnit 运行时下 cryptoFramework 的 `doFinalSync()` 静默返回空数据，
 *   会让 CI 门禁里的密码学用例失真。
 * - base64/UTF-8/字节序全部手写，避免 `util.TextEncoder`/`util.Base64Helper`
 *   在不同运行时行为不一致（TextEncoder.encodeInto 在 Previewer 下返回空数组）。
 * - RSA 用 BigInt 做模幂（Steam 公钥指数固定 65537，性能足够），
 *   padding 可注入，便于与 node:crypto 做逐字节对照测试。
 */

import { buffer } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hmacSha1, hmacSha256 } from '../crypto/PureHash';

const B64_CHARS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/** UTF-8 编码（用 buffer，Previewer 下已验证可用） */
export function utf8ToBytes(text: string): Uint8Array {
  const encoded: buffer.Buffer = buffer.from(text, 'utf-8');
  const out: Uint8Array = new Uint8Array(encoded.length);
  for (let i = 0; i < encoded.length; i++) {
    out[i] = encoded[i];
  }
  return out;
}

/** UTF-8 解码 */
export function bytesToUtf8(bytes: Uint8Array): string {
  const copy: Uint8Array = new Uint8Array(bytes.length);
  copy.set(bytes);
  return buffer.from(copy.buffer as ArrayBuffer).toString('utf-8');
}

/** 标准 base64 编码（带 '=' 填充） */
export function base64Encode(bytes: Uint8Array): string {
  let out: string = '';
  let i: number = 0;
  while (i < bytes.length) {
    const b0: number = bytes[i];
    const has1: boolean = i + 1 < bytes.length;
    const has2: boolean = i + 2 < bytes.length;
    const b1: number = has1 ? bytes[i + 1] : 0;
    const b2: number = has2 ? bytes[i + 2] : 0;
    out += B64_CHARS.charAt(b0 >> 2);
    out += B64_CHARS.charAt(((b0 & 0x03) << 4) | (b1 >> 4));
    out += has1 ? B64_CHARS.charAt(((b1 & 0x0f) << 2) | (b2 >> 6)) : '=';
    out += has2 ? B64_CHARS.charAt(b2 & 0x3f) : '=';
    i += 3;
  }
  return out;
}

function b64Value(ch: string): number {
  const index: number = B64_CHARS.indexOf(ch);
  if (index >= 0) {
    return index;
  }
  if (ch === '-') {
    return 62;
  }
  if (ch === '_') {
    return 63;
  }
  return -1;
}

/** base64 解码（兼容 base64url 与缺失填充） */
export function base64Decode(text: string): Uint8Array {
  const clean: string = text.replace(/[\r\n\s]/g, '');
  const out: number[] = [];
  let acc: number = 0;
  let bits: number = 0;
  for (let i = 0; i < clean.length; i++) {
    const ch: string = clean.charAt(i);
    if (ch === '=') {
      break;
    }
    const v: number = b64Value(ch);
    if (v < 0) {
      continue;
    }
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((acc >> bits) & 0xff);
    }
  }
  const bytes: Uint8Array = new Uint8Array(out.length);
  for (let i = 0; i < out.length; i++) {
    bytes[i] = out[i];
  }
  return bytes;
}

/** 大端定长整数（Steam Guard 计数器 / 交易确认签名用） */
export function uint64ToBytesBE(value: bigint, count: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(count);
  let v: bigint = value;
  for (let i = count - 1; i >= 0; i--) {
    out[i] = Number(v & 0xffn);
    v = v >> 8n;
  }
  return out;
}

/** 小端定长整数（扫码登录签名用） */
export function uint64ToBytesLE(value: bigint, count: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(count);
  let v: bigint = value;
  for (let i = 0; i < count; i++) {
    out[i] = Number(v & 0xffn);
    v = v >> 8n;
  }
  return out;
}

function concat(chunks: Uint8Array[]): Uint8Array {
  let total: number = 0;
  for (let i = 0; i < chunks.length; i++) {
    total += chunks[i].length;
  }
  const out: Uint8Array = new Uint8Array(total);
  let offset: number = 0;
  for (let i = 0; i < chunks.length; i++) {
    out.set(chunks[i], offset);
    offset += chunks[i].length;
  }
  return out;
}

/** HMAC-SHA1 → base64（Steam 交易确认签名要求 SHA1） */
export function hmacSha1Base64(secretBase64: string, chunks: Uint8Array[]): string {
  return base64Encode(hmacSha1(base64Decode(secretBase64), concat(chunks)));
}

/** HMAC-SHA256 → base64（扫码登录确认签名） */
export function hmacSha256Base64(secretBase64: string, chunks: Uint8Array[]): string {
  return base64Encode(hmacSha256(base64Decode(secretBase64), concat(chunks)));
}

/** HMAC-SHA1 原始字节（Steam Guard 动态码） */
export function hmacSha1Raw(keyBytes: Uint8Array, message: Uint8Array): Uint8Array {
  return hmacSha1(keyBytes, message);
}

// ---------------------------------------------------------------------------
// RSA-1024 / PKCS#1 v1.5
// ---------------------------------------------------------------------------

function bytesToBigInt(bytes: Uint8Array): bigint {
  let value: bigint = 0n;
  for (let i = 0; i < bytes.length; i++) {
    value = (value << 8n) | BigInt(bytes[i]);
  }
  return value;
}

function bigIntToBytes(value: bigint, length: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(length);
  let v: bigint = value;
  for (let i = length - 1; i >= 0; i--) {
    out[i] = Number(v & 0xffn);
    v = v >> 8n;
  }
  return out;
}

function modPow(base: bigint, exponent: bigint, modulus: bigint): bigint {
  let result: bigint = 1n;
  let b: bigint = base % modulus;
  let e: bigint = exponent;
  while (e > 0n) {
    if ((e & 1n) === 1n) {
      result = (result * b) % modulus;
    }
    b = (b * b) % modulus;
    e = e >> 1n;
  }
  return result;
}

/** 生成 PKCS#1 v1.5 所需的非零随机字节；优先用系统 CSPRNG，不可用时降级 */
function randomNonZeroBytes(count: number): Uint8Array {
  let seed: Uint8Array | undefined = undefined;
  try {
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    const blob: cryptoFramework.DataBlob = random.generateRandomSync(count);
    const data: Uint8Array | ArrayBuffer = blob.data;
    seed = data instanceof Uint8Array ? data : new Uint8Array(data);
  } catch (e) {
    seed = undefined;
  }
  const out: Uint8Array = new Uint8Array(count);
  for (let i = 0; i < count; i++) {
    let byte: number = 0;
    if (seed !== undefined && seed.length === count) {
      byte = seed[i];
    }
    if (byte === 0) {
      byte = 1 + Math.floor(Math.random() * 255);
    }
    out[i] = byte;
  }
  return out;
}

function modulusByteLength(modulus: bigint): number {
  let length: number = 0;
  let v: bigint = modulus;
  while (v > 0n) {
    v = v >> 8n;
    length += 1;
  }
  return length;
}

/**
 * RSA PKCS#1 v1.5 加密（EM = 0x00 0x02 PS 0x00 M）。
 *
 * 注意块类型必须是 **0x02**（加密），0x01 是签名用的块类型——
 * 写错会导致 Steam 端解密失败（本地用 node:crypto 对照时也会暴露）。
 *
 * @param padding 长度必须等于 k-3-messageLen；传 undefined 时使用随机非零填充。
 */
export function rsaEncryptPkcs1(password: string, modHex: string, expHex: string,
  padding: Uint8Array | undefined): Uint8Array {
  const modulus: bigint = BigInt('0x' + modHex);
  const exponent: bigint = BigInt('0x' + expHex);
  const k: number = modulusByteLength(modulus);
  const message: Uint8Array = utf8ToBytes(password);
  if (message.length > k - 11) {
    throw new Error(`密码过长: ${message.length} > ${k - 11}`);
  }
  const psLen: number = k - 3 - message.length;
  const ps: Uint8Array = padding !== undefined ? padding : randomNonZeroBytes(psLen);
  if (ps.length !== psLen) {
    throw new Error(`padding 长度错误: ${ps.length} != ${psLen}`);
  }
  const em: Uint8Array = new Uint8Array(k);
  em[0] = 0x00;
  em[1] = 0x02;
  em.set(ps, 2);
  em[2 + psLen] = 0x00;
  em.set(message, 3 + psLen);
  return bigIntToBytes(modPow(bytesToBigInt(em), exponent, modulus), k);
}

/** 便捷封装：返回标准 base64（Steam 请求体需要） */
export function rsaEncryptPassword(password: string, modHex: string, expHex: string): string {
  return base64Encode(rsaEncryptPkcs1(password, modHex, expHex, undefined));
}

/** 解析 JWT 的 payload（用于读取 access_token 的 exp 等声明） */
export function decodeJwtPayload(token: string): Record<string, Object> {
  const parts: string[] = token.split('.');
  if (parts.length < 2) {
    return {};
  }
  const json: string = bytesToUtf8(base64Decode(parts[1]));
  return JSON.parse(json) as Record<string, Object>;
}

/** 读取 JWT 的 exp（Unix 秒）；解析失败返回 0 */
export function jwtExpSeconds(token: string): number {
  const claims: Record<string, Object> = decodeJwtPayload(token);
  const exp: Object | undefined = claims['exp'];
  if (typeof exp === 'number') {
    return exp;
  }
  if (typeof exp === 'string') {
    const parsed: number = Number.parseInt(exp, 10);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}
