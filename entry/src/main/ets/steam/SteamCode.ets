/**
 * Steam Guard 5 位动态码（ArkTS）。
 *
 * 算法与项目既有实现一致（`common/src/main/ets/utils/SteamUtils.ets:60-70` +
 * `TokenUtils.generateOTP`）：HMAC-SHA1 对 30 秒计数器做动态截断，
 * 取 31 位整数后用 26 字符表做 5 轮取模映射。
 *
 * 本文件额外提供**服务端时间校正**：Steam 的 AddAuthenticator /
 * FinalizeAddAuthenticator 会返回 `server_time`，参考实现完全忽略它，
 * 这也是 `want_more=true` 反复失败的主因。这里统一用 offset 校正。
 */

import { SteamUtils } from 'common';
import { base64Decode, hmacSha1Raw, uint64ToBytesBE } from './SteamCrypto';

/** Steam 动态码时间步长（秒） */
export const STEAM_CODE_PERIOD: number = 30;

/**
 * 由 shared_secret（base64）与 Unix 时间（秒）计算 5 位 Steam 动态码。
 */
export function steamGuardCode(sharedSecretBase64: string, unixSeconds: number): string {
  const keyBytes: Uint8Array = base64Decode(sharedSecretBase64);
  const counter: number = Math.floor(unixSeconds / STEAM_CODE_PERIOD);
  const mac: Uint8Array = hmacSha1Raw(keyBytes, uint64ToBytesBE(BigInt(counter), 8));

  const offset: number = mac[mac.length - 1] & 0x0f;
  const value: number = ((mac[offset] & 0x7f) << 24)
    | ((mac[offset + 1] & 0xff) << 16)
    | ((mac[offset + 2] & 0xff) << 8)
    | (mac[offset + 3] & 0xff);
  return SteamUtils.SteamTokenFromTOTP(value);
}

/**
 * 带服务端时间偏移的码生成器。
 *
 * 用法：拿到 `AddAuthenticator`/`FinalizeAddAuthenticator` 响应的 server_time 后
 * 调用 `syncServerTime()`，之后 `code()` 会用校正后的时间计算。
 */
export class SteamCodeGenerator {
  /** serverTime - localTime（秒） */
  private offsetSeconds: number = 0;

  /** 用服务端时间与本地时间对齐（两者都是 Unix 秒） */
  syncServerTime(serverTimeUnix: number, localTimeUnix: number): void {
    this.offsetSeconds = serverTimeUnix - localTimeUnix;
  }

  getOffsetSeconds(): number {
    return this.offsetSeconds;
  }

  reset(): void {
    this.offsetSeconds = 0;
  }

  /** 用校正后的时间生成动态码 */
  code(sharedSecretBase64: string, localTimeUnix: number): string {
    return steamGuardCode(sharedSecretBase64, localTimeUnix + this.offsetSeconds);
  }

  /** 距离下一个码的剩余秒数（用于 UI 倒计时） */
  remainingSeconds(localTimeUnix: number): number {
    const now: number = localTimeUnix + this.offsetSeconds;
    return STEAM_CODE_PERIOD - (now % STEAM_CODE_PERIOD);
  }
}
