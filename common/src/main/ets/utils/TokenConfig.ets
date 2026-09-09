import { HMACAlgorithm } from './TokenUtils';
import { util } from '@kit.ArkTS';
import { maFile } from './SteamUtils';
import { SteamAuth } from './SteamAuth';
export enum otpType {
  TOTP,
  Forti,
  HOTP,
  Steam,
  /** 外部OATH设备（NFC读取）令牌：仅当前会话显示，静态验证码 */
  NFC_external = 4
}
export class TokenConfig {
  TokenUUID: string;
  TokenType: otpType;
  TokenSecret: string;
  TokenIssuer: string;
  TokenName: string;
  TokenAlgorithm: HMACAlgorithm;
  TokenPeriod: number;
  TokenDigits: number;
  TokenCounter: number;
  FortiToken: string;
  FortiDevID: string;
  RankScore: number;
  /** 空值或旧数据缺失字段表示未分组。 */
  TokenGroupId: string = '';
  TokenFavorite: boolean = false;
  SteamMaFile: maFile | undefined = undefined;
  /**
   * Steam 账号授权数据（登录/迁移得到）。
   *
   * 注意：`identitySecret` / `revocationCode` / `refreshToken` **不持久化到这里**，
   * 由 SteamSecretStore 单独写入 ASSET；本字段只保存可随 KV/手表同步的非敏感部分。
   */
  SteamAuth: SteamAuth | undefined = undefined;
  TokenIconPath: string | undefined = undefined;
  /** 外部OATH设备（NFC）令牌的静态验证码缓存：仅会话显示，不持久化 */
  TokenExternalCode: string = '';

  /**
   * 云备份用的副本。
   *
   * 与手表同步采用同一剥离策略：**保留 TokenSecret**（恢复后仍能显示动态码），
   * 但不把 `identity_secret` / `refresh_token` / `revocation_code` 等
   * 高权限凭证写进备份载荷（它们只留在本机 ASSET，换机后重新登录即可恢复）。
   *
   * 实现委托给自由函数 `sanitizedTokenForBackup()`：KV/备份/手表同步来的
   * TokenConfig 是 JSON 裸对象，**没有原型方法**，生产代码请直接调用自由函数。
   */
  sanitizedForBackup(): TokenConfig {
    return sanitizedTokenForBackup(this);
  }

  /**
   * 手表同步用的副本：剥离 Steam 高权限凭证与 mafile 密钥。
   *
   * 手表只需要 TokenSecret（= shared_secret）就能显示 5 位动态码；
   * `identity_secret` / `refresh_token` / `revocation_code` 在手表上无法使用
   * （无网络、无交易确认/撤销 UI），而 BLE 传输用的是从固定常量派生的密钥，
   * 因此绝不下发。
   *
   * 实现委托给自由函数 `sanitizedTokenForTransfer()`，理由同上。
   */
  sanitizedForTransfer(): TokenConfig {
    return sanitizedTokenForTransfer(this);
  }

  constructor(
    secret: string = '',
    type: otpType = 0,
    issuer: string = 'Issuer',
    name: string = 'Name',
    algorithm: HMACAlgorithm = 'SHA1',
    period: number = 30,
    digits: number = 6,
    counter: number = 0,
    rank: number = 0
  ) {
    this.TokenSecret = secret;
    this.TokenType = type;
    this.TokenIssuer = issuer;
    this.TokenName = name;
    this.TokenAlgorithm = algorithm;
    this.TokenPeriod = period;
    this.TokenDigits = digits;
    this.TokenCounter = counter;
    this.FortiToken = '';
    this.FortiDevID = '';
    this.TokenUUID = util.generateRandomUUID();
    this.RankScore = rank;
  }
}

/** 创建独立的配置快照；ArkTS 不支持对象展开，且不能在事务提交前修改共享实例。 */export function copyTokenConfig(token: TokenConfig): TokenConfig {
  const copy = new TokenConfig(token.TokenSecret, token.TokenType, token.TokenIssuer, token.TokenName,
    token.TokenAlgorithm, token.TokenPeriod, token.TokenDigits, token.TokenCounter, token.RankScore);
  copy.TokenUUID = token.TokenUUID;
  copy.TokenSecret = token.TokenSecret;
  copy.FortiToken = token.FortiToken;
  copy.FortiDevID = token.FortiDevID;
  copy.TokenGroupId = token.TokenGroupId;
  copy.TokenFavorite = token.TokenFavorite;
  copy.SteamMaFile = token.SteamMaFile;
  // 用 fromPlain 而不是 token.SteamAuth.copy()：KV/备份/手表同步来的 SteamAuth
  // 是 JSON 裸对象，没有原型方法，直接调 copy() 会抛 undefined is not callable
  copy.SteamAuth = SteamAuth.fromPlain(token.SteamAuth);
  copy.TokenIconPath = token.TokenIconPath;
  copy.TokenExternalCode = token.TokenExternalCode;
  return copy;
}

/**
 * 剥离 Steam 高权限凭证与 mafile 密钥（手表同步用）。
 *
 * **自由函数**：入参可能是 JSON 裸对象（KV/备份/手表同步），
 * 不能依赖实例方法存在。
 */
export function sanitizedTokenForTransfer(token: TokenConfig): TokenConfig {
  const copy = copyTokenConfig(token);
  const auth: SteamAuth | undefined = SteamAuth.fromPlain(copy.SteamAuth);
  if (auth !== undefined) {
    auth.clearSecrets();
    copy.SteamAuth = auth;
  }
  if (copy.SteamMaFile !== undefined) {
    const source = copy.SteamMaFile;
    const sanitized = new maFile();
    sanitized.serial_number = source.serial_number;
    sanitized.uri = source.uri;
    sanitized.server_time = source.server_time;
    sanitized.account_name = source.account_name;
    sanitized.token_gid = source.token_gid;
    sanitized.device_id = source.device_id;
    sanitized.status = source.status;
    sanitized.fully_enrolled = source.fully_enrolled;
    // shared_secret / identity_secret / revocation_code / secret_1 / Session 不下发
    copy.SteamMaFile = sanitized;
  }
  return copy;
}

/** 云备份用副本（自由函数版，策略与手表同步一致） */
export function sanitizedTokenForBackup(token: TokenConfig): TokenConfig {
  return sanitizedTokenForTransfer(token);
}

/**
 * LazyForEach ViewModel 包装层。
 *
 * ArkUI LazyForEach 通过 key (keyGenerator 返回值) 标识组件实例。
 * 当 key 不变时组件被复用，key 变化时销毁旧实例并创建新实例
 * （触发 aboutToAppear 重新初始化 OTP 计算等状态）。
 *
 * objid 作为 LazyForEach key，初始等于 TokenUUID。
 * 当单条 Token 被编辑或 HOTP 计数器自增后，调用 refreshObjId()
 * 生成新的随机 UUID 作为 key，迫使 LazyForEach 销毁并重建该行组件，
 * 从而保证 UI 与最新数据一致——无需依赖 @Observed/@Trace 等深度观测机制。
 */
export class TokenConfigVM {
  /** LazyForEach key —— 变更即触发组件重建 */
  objid: string;
  /** 实际数据，引用与 TokenStore.token_array 中的对象共享 */
  config: TokenConfig;

  constructor(config: TokenConfig) {
    this.config = config;
    this.objid = config.TokenUUID;
  }

  /** 生成全新 objid，配合 updateItem() 通知 LazyForEach，使目标行立即重建 */
  refreshObjId(): void {
    this.objid = util.generateRandomUUID();
  }
}