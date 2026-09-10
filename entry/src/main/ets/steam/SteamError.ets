/**
 * Steam EResult 错误码与用户可读文案。
 *
 * 取值来源：官方 `EResult` 枚举（参考实现 `.ai/Authenticator-main/.../Steam.ets:49-179`）。
 * 只保留本项目会遇到的码，其余走兜底文案；数值必须与 Steam 端一致。
 */

import { BusinessError } from '@kit.BasicServicesKit';

/** 成功 */
export const ERESULT_OK: number = 1;
/** 账号已有验证器 → 走迁移分支的关键判定 */
export const ERESULT_DUPLICATE_REQUEST: number = 29;
/** 需要人机验证（参考实现完全没处理） */
export const ERESULT_NEED_CAPTCHA: number = 101;
/** 手机号未绑定/未验证 → 迁移不可用 */
export const ERESULT_NO_MOBILE_DEVICE: number = 92;
export const ERESULT_NO_VERIFIED_PHONE: number = 123;

interface EResultEntry {
  code: number;
  name: string;
  message: string;
}

const ERESULT_TABLE: EResultEntry[] = [
  { code: 0, name: 'Invalid', message: 'Steam 返回无效结果' },
  { code: 2, name: 'Fail', message: 'Steam 拒绝了本次请求' },
  { code: 3, name: 'NoConnection', message: '无法连接 Steam，请检查网络' },
  { code: 5, name: 'InvalidPassword', message: '账号或密码错误' },
  { code: 6, name: 'LoggedInElsewhere', message: '该账号已在别处登录' },
  { code: 8, name: 'InvalidParam', message: '请求参数无效' },
  { code: 11, name: 'InvalidState', message: '登录状态已失效，请重新登录' },
  { code: 15, name: 'AccessDenied', message: 'Steam 拒绝访问' },
  { code: 16, name: 'Timeout', message: 'Steam 请求超时，请重试' },
  { code: 18, name: 'AccountNotFound', message: '找不到该 Steam 账号' },
  { code: 20, name: 'ServiceUnavailable', message: 'Steam 服务暂时不可用' },
  { code: 24, name: 'InsufficientPrivilege', message: '账号权限不足' },
  { code: 25, name: 'LimitExceeded', message: '请求过于频繁，请稍后再试' },
  { code: 29, name: 'DuplicateRequest', message: '该账号已绑定身份验证器' },
  { code: 43, name: 'AccountDisabled', message: '账号已被停用' },
  { code: 63, name: 'AccountLogonDenied', message: '登录被拒绝，需要邮箱验证码' },
  { code: 65, name: 'InvalidLoginAuthCode', message: '验证码错误' },
  { code: 84, name: 'RateLimitExceeded', message: '请求过于频繁，请等待几分钟后重试' },
  { code: 85, name: 'AccountLoginDeniedNeedTwoFactor', message: '需要两步验证码' },
  { code: 87, name: 'AccountLoginDeniedThrottle', message: '登录尝试过于频繁，请稍后再试' },
  { code: 88, name: 'TwoFactorCodeMismatch', message: '两步验证码错误' },
  { code: 89, name: 'TwoFactorActivationCodeMismatch', message: '激活码错误' },
  { code: 92, name: 'NoMobileDevice', message: '该账号未绑定手机号，无法迁移验证器' },
  { code: 93, name: 'TimeNotSynced', message: '本地时间与服务器不同步' },
  { code: 94, name: 'SMSCodeFailed', message: '短信验证码校验失败' },
  { code: 101, name: 'NeedCaptcha', message: 'Steam 要求人机验证，请先在浏览器登录一次该账号' },
  { code: 112, name: 'LimitedUserAccount', message: '该账号为受限账号，无法使用验证器' },
  { code: 123, name: 'NoVerifiedPhone', message: '该账号未验证手机号，无法迁移验证器' },
];

/** EResult 数值 → 英文枚举名 */
export function eresultName(code: number): string {
  for (let i = 0; i < ERESULT_TABLE.length; i++) {
    if (ERESULT_TABLE[i].code === code) {
      return ERESULT_TABLE[i].name;
    }
  }
  return `Unknown(${code})`;
}

/** EResult 数值 → 中文提示文案 */
export function eresultMessage(code: number): string {
  for (let i = 0; i < ERESULT_TABLE.length; i++) {
    if (ERESULT_TABLE[i].code === code) {
      return ERESULT_TABLE[i].message;
    }
  }
  return `Steam 返回错误（${code}）`;
}

/** Steam API 错误（携带 EResult 与可选的响应体摘要，便于定位服务端拒绝原因） */
export class SteamApiError extends Error {
  readonly eresult: number;
  readonly context: string;
  readonly detail: string;

  constructor(eresult: number, context: string, detail: string = '') {
    super(detail.length > 0
      ? `${context}: ${eresultMessage(eresult)}（服务端返回：${detail}）`
      : `${context}: ${eresultMessage(eresult)}`);
    this.eresult = eresult;
    this.context = context;
    this.detail = detail;
  }

  /** 账号已有验证器 → 需要走迁移流程 */
  isDuplicateRequest(): boolean {
    return this.eresult === ERESULT_DUPLICATE_REQUEST;
  }

  /** 需要人机验证 */
  isNeedCaptcha(): boolean {
    return this.eresult === ERESULT_NEED_CAPTCHA;
  }

  /** 手机号相关限制 */
  isPhoneRequired(): boolean {
    return this.eresult === ERESULT_NO_MOBILE_DEVICE || this.eresult === ERESULT_NO_VERIFIED_PHONE;
  }
}

/**
 * 网络层错误码 → 用户可读文案。
 *
 * 取值来自 @kit.NetworkKit 的 Http 错误码。国内网络下最常见的是
 * 2300028（超时）与 2300052（连接被中断、服务端无数据）——
 * 典型表现是 TCP 可连但 TLS 握手被阻断。
 */
export function networkErrorMessage(code: number): string {
  switch (code) {
    case 2300003:
      return '请求地址无效';
    case 2300006:
    case 2300998:
      return '无法解析 Steam 域名，请检查网络或 DNS';
    case 2300007:
      return '无法连接到 Steam 服务器';
    case 2300008:
      return 'Steam 返回了异常数据';
    case 2300028:
      return '连接 Steam 超时';
    case 2300052:
      return '与 Steam 的连接被中断（未收到任何数据）';
    default:
      return `网络请求失败（${code}）`;
  }
}

/** 统一的错误文案：SteamApiError → 业务文案；网络错误码 → 网络文案 */
export function describeRequestError(error: Object): string {
  if (error instanceof SteamApiError) {
    return (error as SteamApiError).message;
  }
  if (error instanceof Error) {
    const err = error as Error;
    const business = error as BusinessError;
    if (business.code !== undefined && business.code >= 2300000) {
      return `${networkErrorMessage(business.code)}，请检查网络后重试`;
    }
    return err.message.length > 0 ? err.message : '请求失败，请稍后重试';
  }
  const business = error as BusinessError;
  if (business !== undefined && business.code !== undefined && business.code >= 2300000) {
    return `${networkErrorMessage(business.code)}，请检查网络后重试`;
  }
  if (business !== undefined && business.message !== undefined) {
    return `${business.message}（${business.code}）`;
  }
  return '请求失败，请稍后重试';
}
