/**
 * Steam 登录/迁移流程中的纯逻辑（无 UI、无网络），便于单测。
 *
 * 关键转换：
 * - Steam 返回的 `shared_secret` 是原始字节；本项目令牌的 `TokenSecret` 是 **base32**，
 *   与 mafile/otpauth 导入保持一致（`SteamUtils.SteamTokenFromTOTP` 依赖 base32 解码）
 * - 优先从响应自带的 `uri` 中取 secret（官方即如此），取不到再用字节自行 base32 编码
 */

import { TokenConfig, otpType, SteamAuth, base32Encode } from 'common';
import {
  CTwoFactor_AddAuthenticator_Response,
  CTwoFactor_FinalizeAddAuthenticator_Response,
  CRemoveAuthenticatorViaChallengeContinue_Replacement_Token,
} from './proto/SteamMessages';
import { base64Encode } from './SteamCrypto';
import { SteamApiError } from './SteamError';

/** 从 otpauth:// 链接中取 base32 secret */
export function extractSecretFromUri(uri: string): string {
  const matched: RegExpMatchArray | null = uri.match(/[?&]secret=([A-Za-z2-7]+)/);
  if (matched === null || matched.length < 2) {
    return '';
  }
  return matched[1].toUpperCase();
}

/** shared_secret 字节 → base32（与 otpauth 一致） */
export function secretBytesToBase32(sharedSecret: Uint8Array): string {
  return base32Encode(sharedSecret).replace(/=+$/, '');
}

/** 由「添加验证器」响应构建 SteamAuth */
export function buildAuthFromAdd(response: CTwoFactor_AddAuthenticator_Response, accountName: string,
  steamid: string, deviceId: string, refreshToken: string, accessToken: string): SteamAuth {
  const auth = new SteamAuth();
  auth.accountName = response.accountName.length > 0 ? response.accountName : accountName;
  auth.steamid = steamid;
  auth.deviceId = deviceId;
  auth.serialNumber = response.serialNumber.toString();
  auth.tokenGid = response.tokenGid;
  auth.uri = response.uri;
  auth.serverTime = Number(response.serverTime);
  auth.steamguardScheme = 1;
  auth.identitySecret = base64Encode(response.identitySecret);
  auth.revocationCode = response.revocationCode;
  auth.refreshToken = refreshToken;
  auth.accessToken = accessToken;
  return auth;
}

/** 由「迁移验证器」响应构建 SteamAuth */
export function buildAuthFromTransfer(
  token: CRemoveAuthenticatorViaChallengeContinue_Replacement_Token,
  accountName: string, steamid: string, deviceId: string, refreshToken: string,
  accessToken: string): SteamAuth {
  const auth = new SteamAuth();
  auth.accountName = token.accountName.length > 0 ? token.accountName : accountName;
  auth.steamid = token.steamid !== 0n ? token.steamid.toString() : steamid;
  auth.deviceId = deviceId;
  auth.serialNumber = token.serialNumber.toString();
  auth.tokenGid = token.tokenGid;
  auth.uri = token.uri;
  auth.serverTime = Number(token.serverTime);
  auth.steamguardScheme = token.steamguardScheme > 0 ? token.steamguardScheme : 1;
  auth.identitySecret = base64Encode(token.identitySecret);
  auth.revocationCode = token.revocationCode;
  auth.refreshToken = refreshToken;
  auth.accessToken = accessToken;
  return auth;
}

/**
 * 由 SteamAuth 构建可保存的令牌配置。
 *
 * @param rank 新令牌的排序分值（编辑已有令牌时沿用原值）
 */
export function buildSteamTokenConfig(auth: SteamAuth, secretBase32: string, issuer: string,
  displayName: string, rank: number): TokenConfig {
  // Steam 令牌固定：SHA1 / 30s / digits=10（保留完整 31 位截断值，再由 5 位算法映射）
  const conf = new TokenConfig(secretBase32, otpType.Steam, issuer, displayName, 'SHA1', 30, 10, 0, rank);
  conf.SteamAuth = auth;
  return conf;
}

/** 判定添加验证器失败是否应转入迁移流程 */
export function shouldFallbackToTransfer(eresult: number): boolean {
  return eresult === 29; // DuplicateRequest
}

/** 该确认类型是否需要用户输入验证码（否则等待另一设备/邮件确认） */
export function confirmationNeedsCode(confirmationType: number): boolean {
  return confirmationType === 3 || confirmationType === 2; // DeviceCode / EmailCode
}

/** 激活码来源：1=短信，3=邮件 */
export function activationCodeIsSms(confirmType: number): boolean {
  return confirmType !== 3;
}

/**
 * 完成添加所需的外部依赖（便于单测注入假实现）。
 *
 * 注意：这里用「函数类型属性」而不是方法签名——ArkTS 不允许为带方法签名的
 * interface 写对象字面量（arkts-no-untyped-obj-literals）。
 */
export interface FinalizeContext {
  /** 用给定动态码与服务端时间发起一次 FinalizeAddAuthenticator */
  attempt: (authenticatorCode: string,
    serverTimeSeconds: number) => Promise<CTwoFactor_FinalizeAddAuthenticator_Response>;
  /** 由**服务端时间**计算动态码（不做二次偏移，避免重复校正） */
  codeForServerTime: (serverTimeSeconds: number) => string;
  /** 当前服务端时间（本地时间 + 已同步的偏移） */
  currentServerTimeSeconds: () => number;
  sleep: (ms: number) => Promise<void>;
}

/** 每次重试之间的等待时间 */
export const FINALIZE_RETRY_DELAY_MS: number = 2000;

/**
 * 完成添加验证器，处理 Steam 的 `want_more` 语义。
 *
 * Steam 在「动态码所在时间步与服务端不一致」时返回 `want_more=true`，
 * 要求客户端**用新码重试**（参考实现只是让用户再点一次，体验差且容易卡住）。
 *
 * @returns true=成功；false=重试次数耗尽
 * @throws SteamApiError 服务端明确拒绝（success=false 且 want_more=false）
 */
export async function finalizeUntilSuccess(context: FinalizeContext,
  maxAttempts: number = 5): Promise<boolean> {
  for (let attempt: number = 0; attempt < maxAttempts; attempt++) {
    const serverTime: number = context.currentServerTimeSeconds();
    const code: string = context.codeForServerTime(serverTime);
    const result: CTwoFactor_FinalizeAddAuthenticator_Response =
      await context.attempt(code, serverTime);
    if (result.success) {
      return true;
    }
    if (!result.wantMore) {
      throw new SteamApiError(result.status, 'FinalizeAddAuthenticator');
    }
    if (attempt + 1 < maxAttempts) {
      await context.sleep(FINALIZE_RETRY_DELAY_MS);
    }
  }
  return false;
}
