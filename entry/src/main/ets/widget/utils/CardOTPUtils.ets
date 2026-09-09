/**
 * 卡片（FormExtensionAbility 进程）专用 OTP 计算。
 *
 * 该进程**不能依赖 common HAR**（会连带加载 KvManager/RdbManager/AppStorage 等），
 * 因此只 import 同模块内的纯实现 `../crypto/PureHash`（零系统依赖）。
 *
 * 哈希/HMAC 全部来自 PureHash（SHA1/224/256/384/512），本文件只保留：
 * base32 解码、OTP 截断、Steam 变体映射。
 * SM3 / MD5 需要 cryptoFramework，卡片进程不可用 → 返回等长占位符（'-'），
 * **不返回错误的验证码**。
 */

import { hmac, sha1, sha224, sha256, sha384, sha512 } from '../../crypto/PureHash';

const BASE32_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/** 容忍粘贴带来的空格/连字符/换行，并跳过非法字符（与主界面 TokenUtils.base32Decode 保持一致） */
function base32Decode(input: string): Uint8Array {
  let cleaned = input.toUpperCase().replace(/[\s-]/g, '').replace(/=+$/, '');
  let bytes: number[] = [];
  let buffer = 0;
  let bitsLeft = 0;

  for (let i = 0; i < cleaned.length; i++) {
    let val = BASE32_CHARS.indexOf(cleaned.charAt(i));
    if (val < 0) continue;
    buffer = (buffer << 5) | val;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      bitsLeft -= 8;
      bytes.push((buffer >> bitsLeft) & 0xFF);
    }
  }
  return new Uint8Array(bytes);
}

/** HOTP 计数器 → 8 字节大端（与 common/TokenUtils.counterToBytes64 等价，卡片不能 import common） */
function counterToBytes64(counter: number): Uint8Array {
  let value: bigint = BigInt(Math.floor(counter)) & 0xffffffffffffffffn;
  const out = new Uint8Array(8);
  for (let i = 7; i >= 0; i--) {
    out[i] = Number(value & 0xffn);
    value = value >> 8n;
  }
  return out;
}

const STEAM_CHARS = '23456789BCDFGHJKMNPQRTVWXY';
const STEAM_DIGITS = 5;

function steamTokenFromTOTP(totpToken: number): string {
  let intCode = totpToken;
  let steamToken = '';
  for (let i = 0; i < STEAM_DIGITS; i++) {
    steamToken += STEAM_CHARS.charAt(intCode % STEAM_CHARS.length);
    intCode = Math.floor(intCode / STEAM_CHARS.length);
  }
  return steamToken;
}

/** 卡片无法计算的算法（SM3/MD5）返回等长占位符，避免显示一个看似正常却错误的验证码 */
function maskedCode(digits: number, tokenType: string): string {
  const length: number = tokenType === '3' ? STEAM_DIGITS : (digits > 0 ? digits : 6);
  return '-'.repeat(length);
}

export function generateCardOTP(
  secret: string,
  algorithm: string,
  digits: number,
  period: number,
  tokenType: string = '0',
  counter: number = -1,
): string {
  const key = base32Decode(secret);
  const safePeriod: number = period > 0 ? period : 30;
  const safeDigits: number = digits > 0 ? digits : 6;

  let msg: Uint8Array;
  if (tokenType === '2' && counter >= 0) {
    msg = counterToBytes64(counter);
  } else {
    const timestamp = Math.floor(Date.now() / 1000);
    msg = counterToBytes64(Math.floor(timestamp / safePeriod));
  }

  let hash: Uint8Array;
  if (algorithm === '' || algorithm === 'SHA1') {
    hash = hmac((d: Uint8Array): Uint8Array => sha1(d), 64, key, msg);
  } else if (algorithm === 'SHA224') {
    hash = hmac((d: Uint8Array): Uint8Array => sha224(d), 64, key, msg);
  } else if (algorithm === 'SHA256') {
    hash = hmac((d: Uint8Array): Uint8Array => sha256(d), 64, key, msg);
  } else if (algorithm === 'SHA384') {
    hash = hmac((d: Uint8Array): Uint8Array => sha384(d), 128, key, msg);
  } else if (algorithm === 'SHA512') {
    hash = hmac((d: Uint8Array): Uint8Array => sha512(d), 128, key, msg);
  } else {
    return maskedCode(safeDigits, tokenType);
  }

  const offset = hash[hash.length - 1] & 0x0F;
  const binary =
    ((hash[offset] & 0x7F) << 24) |
    ((hash[offset + 1] & 0xFF) << 16) |
    ((hash[offset + 2] & 0xFF) << 8) |
    (hash[offset + 3] & 0xFF);

  const otp = binary % Math.pow(10, safeDigits);

  if (tokenType === '3') {
    return steamTokenFromTOTP(otp);
  }
  return otp.toString().padStart(safeDigits, '0');
}
