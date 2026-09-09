/**
 * Steam API 客户端（IAuthenticationService / ITwoFactorService / steamcommunity mobileconf）。
 *
 * 覆盖本次需求的全部接口：
 * - 登录：GetPasswordRSAPublicKey → BeginAuthSessionViaCredentials → UpdateAuthSessionWithSteamGuardCode
 *        → PollAuthSessionStatus（按服务端 interval 轮询，修掉参考实现只调一次的缺陷）
 * - 添加：AddAuthenticator → FinalizeAddAuthenticator（want_more 时用新码重试）
 * - 迁移：RemoveAuthenticatorViaChallengeStart → Continue（需已绑定手机号）
 * - 撤销：RemoveAuthenticator(revocation_code)
 * - 令牌：GenerateAccessTokenForApp（读取 JWT exp 做缓存）
 * - 扫码登录：UpdateAuthSessionWithMobileConfirmation（HMAC-SHA256 签名）
 * - 交易确认：mobileconf getlist / multiajaxop（HMAC-SHA1 identity_secret 签名）
 *
 * 所有 URL/字段/签名顺序均与官方客户端一致；签名与 URL 构造做成纯函数，
 * 便于在没有网络的情况下做单测。
 */

import {
  CAuthentication_AllowedConfirmation,
  CAuthentication_BeginAuthSessionViaCredentials_Request,
  CAuthentication_BeginAuthSessionViaCredentials_Response,
  CAuthentication_DeviceDetails,
  CAuthentication_PollAuthSessionStatus_Request,
  CAuthentication_PollAuthSessionStatus_Response,
  CAuthentication_UpdateAuthSessionWithSteamGuardCode_Request,
  CTwoFactor_AddAuthenticator_Request,
  CTwoFactor_AddAuthenticator_Response,
  CTwoFactor_FinalizeAddAuthenticator_Request,
  CTwoFactor_FinalizeAddAuthenticator_Response,
  CTwoFactor_RemoveAuthenticator_Request,
  CTwoFactor_RemoveAuthenticator_Response,
  CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request,
  CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response,
  CTwoFactor_Status_Request,
  CTwoFactor_Status_Response,
  EAuthSessionGuardType,
} from './proto/SteamMessages';
import { ProtoWriter } from 'common';
import {
  base64Encode,
  hmacSha1Base64,
  hmacSha256Base64,
  jwtExpSeconds,
  rsaEncryptPassword,
  uint64ToBytesBE,
  uint64ToBytesLE,
  utf8ToBytes,
} from './SteamCrypto';
import { SteamTransport } from './SteamHttp';
import { SteamApiError } from './SteamError';

export const STEAM_API_BASE: string = 'https://api.steampowered.com';
export const STEAM_COMMUNITY_BASE: string = 'https://steamcommunity.com';

const URL_GET_RSA_KEY: string = `${STEAM_API_BASE}/IAuthenticationService/GetPasswordRSAPublicKey/v1/`;
const URL_BEGIN_AUTH: string = `${STEAM_API_BASE}/IAuthenticationService/BeginAuthSessionViaCredentials/v1/`;
const URL_GUARD_CODE: string = `${STEAM_API_BASE}/IAuthenticationService/UpdateAuthSessionWithSteamGuardCode/v1/`;
const URL_POLL_AUTH: string = `${STEAM_API_BASE}/IAuthenticationService/PollAuthSessionStatus/v1/`;
const URL_ACCESS_TOKEN: string = `${STEAM_API_BASE}/IAuthenticationService/GenerateAccessTokenForApp/v1/`;
const URL_MOBILE_CONFIRM: string = `${STEAM_API_BASE}/IAuthenticationService/UpdateAuthSessionWithMobileConfirmation/v1/`;
const URL_ADD_AUTHENTICATOR: string = `${STEAM_API_BASE}/ITwoFactorService/AddAuthenticator/v1/`;
const URL_FINALIZE_AUTHENTICATOR: string = `${STEAM_API_BASE}/ITwoFactorService/FinalizeAddAuthenticator/v1/`;
const URL_STATUS: string = `${STEAM_API_BASE}/ITwoFactorService/QueryStatus/v1/`;
const URL_REMOVE_AUTHENTICATOR: string = `${STEAM_API_BASE}/ITwoFactorService/RemoveAuthenticator/v1/`;
const URL_TRANSFER_START: string = `${STEAM_API_BASE}/ITwoFactorService/RemoveAuthenticatorViaChallengeStart/v1/`;
const URL_TRANSFER_CONTINUE: string = `${STEAM_API_BASE}/ITwoFactorService/RemoveAuthenticatorViaChallengeContinue/v1/`;
const URL_MOBILECONF_LIST: string = `${STEAM_COMMUNITY_BASE}/mobileconf/getlist`;
const URL_MOBILECONF_OP: string = `${STEAM_COMMUNITY_BASE}/mobileconf/multiajaxop`;

const CONFIRMATION_TAG: string = 'conf';

/** 扫码登录二维码：https://s.team/q/<version>/<clientId> */
export class SteamQrChallenge {
  version: number = 0;
  clientId: bigint = 0n;
}

/** 账号 RSA 公钥（GetPasswordRSAPublicKey 响应） */
export class SteamRsaPublicKey {
  publickeyMod: string = '';
  publickeyExp: string = '';
  timestamp: bigint = 0n;
}

/** 一次登录会话（BeginAuthSessionViaCredentials 的产出 + 后续 poll 结果） */
export class SteamAuthSession {
  clientId: bigint = 0n;
  requestId: Uint8Array = new Uint8Array(0);
  intervalSeconds: number = 5;
  steamid: bigint = 0n;
  allowedConfirmations: CAuthentication_AllowedConfirmation[] = [];
  accountName: string = '';
  refreshToken: string = '';
  accessToken: string = '';

  /** 优先选设备码（3）> 邮箱码（2）> 设备确认（4）> 邮件确认（5） */
  preferredConfirmation(): CAuthentication_AllowedConfirmation | undefined {
    const order: number[] = [
      EAuthSessionGuardType.DEVICE_CODE,
      EAuthSessionGuardType.EMAIL_CODE,
      EAuthSessionGuardType.DEVICE_CONFIRMATION,
      EAuthSessionGuardType.EMAIL_CONFIRMATION,
    ];
    for (let i = 0; i < order.length; i++) {
      for (let j = 0; j < this.allowedConfirmations.length; j++) {
        if (this.allowedConfirmations[j].confirmationType === order[i]) {
          return this.allowedConfirmations[j];
        }
      }
    }
    return undefined;
  }

  /** 该确认类型是否需要用户输入验证码 */
  requiresCode(): boolean {
    const preferred: CAuthentication_AllowedConfirmation | undefined = this.preferredConfirmation();
    if (preferred === undefined) {
      return false;
    }
    const type: number = preferred.confirmationType;
    return type === EAuthSessionGuardType.DEVICE_CODE || type === EAuthSessionGuardType.EMAIL_CODE;
  }
}

/** access_token 及其过期时间 */
export class SteamAccessToken {
  token: string = '';
  expiresAtSeconds: number = 0;

  isValid(nowSeconds: number): boolean {
    return this.token.length > 0 && this.expiresAtSeconds - 120 > nowSeconds;
  }
}

/** 交易确认条目 */
export class SteamConfirmation {
  id: string = '';
  nonce: string = '';
  creatorId: string = '';
  type: number = 0;
  typeName: string = '';
  headline: string = '';
  summary: string[] = [];
  creationTime: number = 0;
  icon: string = '';
}

/** 可注入的等待实现（测试用零延迟） */
export interface Sleeper {
  sleep(ms: number): Promise<void>;
}

export class RealSleeper implements Sleeper {
  async sleep(ms: number): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), ms);
    });
  }
}

interface GenerateAccessTokenPayload {
  access_token: string;
}

interface GenerateAccessTokenResponse {
  response: GenerateAccessTokenPayload;
}

/** mobileconf/getlist 的原始条目（snake_case，与 Steam 返回一致） */
interface MobileConfItem {
  id?: string;
  nonce?: string;
  creator_id?: string;
  type?: number;
  type_name?: string;
  headline?: string;
  summary?: string[];
  creation_time?: number;
  icon?: string;
}

interface MobileConfListResponse {
  success: boolean;
  message: string;
  conf: MobileConfItem[];
}

function toConfirmation(item: MobileConfItem): SteamConfirmation {
  const out = new SteamConfirmation();
  out.id = item.id ?? '';
  out.nonce = item.nonce ?? '';
  out.creatorId = item.creator_id ?? '';
  out.type = item.type ?? 0;
  out.typeName = item.type_name ?? '';
  out.headline = item.headline ?? '';
  out.summary = item.summary ?? [];
  out.creationTime = item.creation_time ?? 0;
  out.icon = item.icon ?? '';
  return out;
}

/** 解析扫码登录二维码 URL；非 s.team/q 链接返回 undefined */
export function parseSteamQrChallenge(url: string): SteamQrChallenge | undefined {
  const matched: RegExpMatchArray | null = url.trim().match(/^https:\/\/s\.team\/q\/(\d+)\/(\d+)(\?|$)/);
  if (matched === null || matched.length < 3) {
    return undefined;
  }
  const challenge = new SteamQrChallenge();
  challenge.version = Number.parseInt(matched[1], 10);
  challenge.clientId = BigInt(matched[2]);
  return challenge;
}

/** 扫码登录签名：HMAC-SHA256(shared_secret, version:2LE ‖ clientId:8LE ‖ steamid:8LE) */
export function qrLoginSignature(sharedSecretBase64: string, version: number, clientId: bigint,
  steamid: bigint): string {
  return encodeURIComponent(hmacSha256Base64(sharedSecretBase64, [
    uint64ToBytesLE(BigInt(version), 2),
    uint64ToBytesLE(clientId, 8),
    uint64ToBytesLE(steamid, 8),
  ]));
}

/** 交易确认签名：HMAC-SHA1(identity_secret, seconds:8BE ‖ tag) */
export function confirmationSignature(identitySecretBase64: string, unixSeconds: number,
  tag: string): string {
  return encodeURIComponent(hmacSha1Base64(identitySecretBase64, [
    uint64ToBytesBE(BigInt(unixSeconds), 8),
    utf8ToBytes(tag),
  ]));
}

export class SteamClient {
  private transport: SteamTransport;
  private sleeper: Sleeper;
  /** 按 steamid 缓存 access_token：单例客户端会同时服务多个 Steam 账号，不能只存一份 */
  private tokenCache: Map<string, SteamAccessToken> = new Map<string, SteamAccessToken>();

  constructor(transport: SteamTransport, sleeper: Sleeper = new RealSleeper()) {
    this.transport = transport;
    this.sleeper = sleeper;
  }

  // ---------------------------------------------------------------- 登录

  async getPasswordRsaPublicKey(accountName: string): Promise<SteamRsaPublicKey> {
    const url: string = `${URL_GET_RSA_KEY}?account_name=${encodeURIComponent(accountName)}`;
    const text: string = await this.transport.getJson(url, 'GetPasswordRSAPublicKey');
    const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const response: Record<string, Object> = parsed['response'] as Record<string, Object>;
    const key = new SteamRsaPublicKey();
    key.publickeyMod = String(response['publickey_mod']);
    key.publickeyExp = String(response['publickey_exp']);
    key.timestamp = BigInt(String(response['timestamp']));
    return key;
  }

  async beginAuthSession(accountName: string, password: string,
    deviceFriendlyName: string): Promise<SteamAuthSession> {
    const rsaKey: SteamRsaPublicKey = await this.getPasswordRsaPublicKey(accountName);
    const request = new CAuthentication_BeginAuthSessionViaCredentials_Request();
    request.accountName = accountName;
    request.encryptedPassword = rsaEncryptPassword(password, rsaKey.publickeyMod, rsaKey.publickeyExp);
    request.encryptionTimestamp = rsaKey.timestamp;
    request.deviceDetails.deviceFriendlyName = deviceFriendlyName;
    const bytes: Uint8Array = await this.transport.postProto(URL_BEGIN_AUTH, request.encode(), '',
      'BeginAuthSessionViaCredentials');
    const decoded: CAuthentication_BeginAuthSessionViaCredentials_Response =
      CAuthentication_BeginAuthSessionViaCredentials_Response.decode(bytes);
    const session = new SteamAuthSession();
    session.clientId = decoded.clientId;
    session.requestId = decoded.requestId;
    session.intervalSeconds = decoded.interval > 0 ? decoded.interval : 5;
    session.steamid = decoded.steamid;
    session.allowedConfirmations = decoded.allowedConfirmations;
    return session;
  }

  async submitSteamGuardCode(session: SteamAuthSession, code: string, codeType: number): Promise<void> {
    const request = new CAuthentication_UpdateAuthSessionWithSteamGuardCode_Request();
    request.clientId = session.clientId;
    request.steamid = session.steamid;
    request.code = code;
    request.codeType = codeType;
    await this.transport.postProto(URL_GUARD_CODE, request.encode(), '',
      'UpdateAuthSessionWithSteamGuardCode');
  }

  /** 轮询一次；返回是否已拿到凭证 */
  async pollAuthSessionStatus(session: SteamAuthSession): Promise<boolean> {
    const request = new CAuthentication_PollAuthSessionStatus_Request();
    request.clientId = session.clientId;
    request.requestId = session.requestId;
    const bytes: Uint8Array = await this.transport.postProto(URL_POLL_AUTH, request.encode(), '',
      'PollAuthSessionStatus');
    const decoded: CAuthentication_PollAuthSessionStatus_Response =
      CAuthentication_PollAuthSessionStatus_Response.decode(bytes);
    if (decoded.refreshToken.length === 0) {
      return false;
    }
    session.refreshToken = decoded.refreshToken;
    session.accessToken = decoded.accessToken;
    session.accountName = decoded.accountName;
    if (decoded.newClientId !== 0n) {
      session.clientId = decoded.newClientId;
    }
    return true;
  }

  /**
   * 按服务端返回的 interval 轮询直到拿到凭证。
   * 修掉参考实现的缺陷：只调一次、忽略 interval、不校验空 token。
   */
  async pollUntilAuthorized(session: SteamAuthSession, maxAttempts: number = 20): Promise<void> {
    const intervalMs: number = Math.max(1, session.intervalSeconds) * 1000;
    for (let attempt: number = 0; attempt < maxAttempts; attempt++) {
      const done: boolean = await this.pollAuthSessionStatus(session);
      if (done) {
        return;
      }
      if (attempt + 1 < maxAttempts) {
        await this.sleeper.sleep(intervalMs);
      }
    }
    throw new SteamApiError(16, 'PollAuthSessionStatus');
  }

  async generateAccessToken(steamid: bigint, refreshToken: string, nowSeconds: number): Promise<string> {
    const cacheKey: string = steamid.toString();
    const cached: SteamAccessToken | undefined = this.tokenCache.get(cacheKey);
    if (cached !== undefined && cached.isValid(nowSeconds)) {
      return cached.token;
    }
    const body: string[] = [
      `refresh_token=${encodeURIComponent(refreshToken)}`,
      `steamid=${cacheKey}`,
      'renewal_type=0',
    ];
    const text: string = await this.transport.postForm(URL_ACCESS_TOKEN, body, '',
      'GenerateAccessTokenForApp');
    const parsed: GenerateAccessTokenResponse = JSON.parse(text) as GenerateAccessTokenResponse;
    const token = new SteamAccessToken();
    token.token = parsed.response.access_token;
    token.expiresAtSeconds = jwtExpSeconds(token.token);
    this.tokenCache.set(cacheKey, token);
    return token.token;
  }

  // ---------------------------------------------------------------- 添加 / 迁移

  async addAuthenticator(steamid: bigint, accessToken: string, deviceId: string):
    Promise<CTwoFactor_AddAuthenticator_Response> {
    const request = new CTwoFactor_AddAuthenticator_Request();
    request.steamid = steamid;
    request.deviceIdentifier = deviceId;
    const bytes: Uint8Array = await this.transport.postProto(URL_ADD_AUTHENTICATOR, request.encode(),
      accessToken, 'AddAuthenticator');
    return CTwoFactor_AddAuthenticator_Response.decode(bytes);
  }

  async finalizeAddAuthenticator(steamid: bigint, accessToken: string, authenticatorCode: string,
    authenticatorTimeSeconds: number, activationCode: string):
    Promise<CTwoFactor_FinalizeAddAuthenticator_Response> {
    const request = new CTwoFactor_FinalizeAddAuthenticator_Request();
    request.steamid = steamid;
    request.authenticatorCode = authenticatorCode;
    // 必须取整：字段是 uint64，参考实现传了浮点秒
    request.authenticatorTime = BigInt(Math.floor(authenticatorTimeSeconds));
    request.activationCode = activationCode;
    request.validateSmsCode = true;
    const bytes: Uint8Array = await this.transport.postProto(URL_FINALIZE_AUTHENTICATOR, request.encode(),
      accessToken, 'FinalizeAddAuthenticator');
    return CTwoFactor_FinalizeAddAuthenticator_Response.decode(bytes);
  }

  /** 迁移第一步：触发短信验证码 */
  async startTransferAuthenticator(steamid: bigint, accessToken: string): Promise<boolean> {
    const empty = new ProtoWriter();
    await this.transport.postProto(URL_TRANSFER_START, empty.finish(), accessToken,
      'RemoveAuthenticatorViaChallengeStart');
    return true;
  }

  /** 迁移第二步：提交短信码，返回新的 replacement_token */
  async submitTransferSmsCode(steamid: bigint, accessToken: string, smsCode: string):
    Promise<CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response> {
    const request = new CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request();
    request.smsCode = smsCode;
    request.generateNewToken = true;
    const bytes: Uint8Array = await this.transport.postProto(URL_TRANSFER_CONTINUE, request.encode(),
      accessToken, 'RemoveAuthenticatorViaChallengeContinue');
    return CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response.decode(bytes);
  }

  /** 撤销验证器（需要 revocation_code） */
  async revokeAuthenticator(steamid: bigint, accessToken: string, revocationCode: string):
    Promise<CTwoFactor_RemoveAuthenticator_Response> {
    const request = new CTwoFactor_RemoveAuthenticator_Request();
    request.revocationCode = revocationCode;
    request.steamguardScheme = 1;
    request.removeAllSteamguardCookies = false;
    const bytes: Uint8Array = await this.transport.postProto(URL_REMOVE_AUTHENTICATOR, request.encode(),
      accessToken, 'RemoveAuthenticator');
    return CTwoFactor_RemoveAuthenticator_Response.decode(bytes);
  }

  async queryStatus(steamid: bigint, accessToken: string): Promise<CTwoFactor_Status_Response> {
    const request = new CTwoFactor_Status_Request();
    request.steamid = steamid;
    const bytes: Uint8Array = await this.transport.postProto(URL_STATUS, request.encode(),
      accessToken, 'QueryStatus');
    return CTwoFactor_Status_Response.decode(bytes);
  }

  // ---------------------------------------------------------------- 扫码登录

  /** 批准扫码登录（二维码内容为 https://s.team/q/<version>/<clientId>） */
  async approveQrLogin(steamid: bigint, accessToken: string, sharedSecretBase64: string,
    challenge: SteamQrChallenge, persistence: boolean): Promise<void> {
    const signature: string = qrLoginSignature(sharedSecretBase64, challenge.version,
      challenge.clientId, steamid);
    const body: string[] = [
      `steamid=${steamid.toString()}`,
      'confirm=true',
      `persistence=${persistence ? 1 : 0}`,
      `version=${challenge.version}`,
      `client_id=${challenge.clientId.toString()}`,
      `signature=${signature}`,
    ];
    await this.transport.postForm(URL_MOBILE_CONFIRM, body, accessToken, 'UpdateAuthSessionWithMobileConfirmation');
  }

  // ---------------------------------------------------------------- 交易确认

  private static confirmCookie(steamid: bigint, accessToken: string): string {
    return `dob=;steamid=${steamid.toString()};steamLoginSecure=${steamid.toString()}||${accessToken}`;
  }

  async getConfirmations(steamid: bigint, accessToken: string, identitySecretBase64: string,
    deviceId: string, nowSeconds: number): Promise<SteamConfirmation[]> {
    const signature: string = confirmationSignature(identitySecretBase64, nowSeconds, CONFIRMATION_TAG);
    const url: string = `${URL_MOBILECONF_LIST}?p=${encodeURIComponent(deviceId)}`
      + `&a=${steamid.toString()}&t=${nowSeconds}&m=react&tag=${CONFIRMATION_TAG}&k=${signature}`;
    const text: string = await this.transport.getWithCookie(url,
      SteamClient.confirmCookie(steamid, accessToken), 'mobileconf/getlist');
    const parsed: MobileConfListResponse = JSON.parse(text) as MobileConfListResponse;
    if (!parsed.success) {
      throw new Error(`获取交易确认列表失败: ${parsed.message}`);
    }
    const out: SteamConfirmation[] = [];
    const raw: MobileConfItem[] = parsed.conf ?? [];
    for (let i = 0; i < raw.length; i++) {
      out.push(toConfirmation(raw[i]));
    }
    return out;
  }

  /** 批准/拒绝交易确认；op 取 'allow' 或 'cancel' */
  async respondConfirmations(steamid: bigint, accessToken: string, identitySecretBase64: string,
    deviceId: string, confirmations: SteamConfirmation[], op: string, nowSeconds: number): Promise<void> {
    const signature: string = confirmationSignature(identitySecretBase64, nowSeconds, CONFIRMATION_TAG);
    const body: string[] = [
      `p=${encodeURIComponent(deviceId)}`,
      `a=${steamid.toString()}`,
      `t=${nowSeconds}`,
      'm=react',
      `tag=${CONFIRMATION_TAG}`,
      `k=${signature}`,
      `op=${op}`,
    ];
    for (let i = 0; i < confirmations.length; i++) {
      body.push(`cid[]=${encodeURIComponent(confirmations[i].id)}`);
      body.push(`ck[]=${encodeURIComponent(confirmations[i].nonce)}`);
    }
    await this.transport.postWithCookie(URL_MOBILECONF_OP, body,
      SteamClient.confirmCookie(steamid, accessToken), 'mobileconf/multiajaxop');
  }
}
