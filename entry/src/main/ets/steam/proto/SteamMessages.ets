/**
 * Steam 消息编解码（ArkTS 手写，基于 ProtoReader/ProtoWriter）。
 *
 * 字段号、类型、wireType 全部逐条抄自官方 .proto
 * （`.ai/Authenticator-main/entry/src/main/ets/pages/steamapi/protobufs/`）：
 * - IAuthenticationService：steammessages_auth.steamclient.proto
 * - ITwoFactorService：service_twofactor.proto
 * 不做任何重命名，避免与官方编码产生歧义。
 *
 * 注意几处容易踩的点：
 * - `steamid` 在不同消息里类型不同：BeginAuthSessionViaCredentials_Response 是
 *   **uint64（varint）**，而 UpdateAuthSessionWithSteamGuardCode / CTwoFactor_* 是
 *   **fixed64（8 字节小端）**，写错会导致签名/查询失败。
 * - `CAuthentication_BeginAuthSessionViaCredentials_Response.interval` 是 float（wireType 5）。
 * - `CAuthentication_DeviceDetails.os_type` 为负数（-500），必须走 int32 的 64 位补码编码。
 */

import { ProtoReader, ProtoWriter } from 'common';

/** EAuthSessionGuardType（enums，值取自官方 proto） */
export enum EAuthSessionGuardType {
  UNKNOWN = 0,
  NONE = 1,
  EMAIL_CODE = 2,
  DEVICE_CODE = 3,
  DEVICE_CONFIRMATION = 4,
  EMAIL_CONFIRMATION = 5,
  MACHINE_TOKEN = 6,
  LEGACY_MACHINE_AUTH = 7,
}

/** EAuthTokenPlatformType */
export enum EAuthTokenPlatformType {
  UNKNOWN = 0,
  STEAM_CLIENT = 1,
  WEB_BROWSER = 2,
  MOBILE_APP = 3,
}

/** ESessionPersistence */
export enum ESessionPersistence {
  INVALID = -1,
  EPHEMERAL = 0,
  PERSISTENT = 1,
}

/** 模拟 Android 客户端的固定取值（与 Steam 官方移动端一致，勿随意更改） */
export const STEAM_OS_TYPE_ANDROID: number = -500;
export const STEAM_GAMING_DEVICE_TYPE_PHONE: number = 528;

/** CTwoFactor_AddAuthenticator_Response.confirm_type */
export const CONFIRM_TYPE_SMS: number = 1;
export const CONFIRM_TYPE_EMAIL: number = 3;

// ---------------------------------------------------------------------------
// IAuthenticationService
// ---------------------------------------------------------------------------

/** CAuthentication_DeviceDetails（field 9 的嵌套消息） */
export class CAuthentication_DeviceDetails {
  deviceFriendlyName: string = 'Authenticator';
  platformType: number = EAuthTokenPlatformType.MOBILE_APP;
  osType: number = STEAM_OS_TYPE_ANDROID;
  gamingDeviceType: number = STEAM_GAMING_DEVICE_TYPE_PHONE;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    if (this.deviceFriendlyName.length > 0) {
      w.writeString(1, this.deviceFriendlyName);
    }
    w.writeInt32(2, this.platformType);
    w.writeInt32(3, this.osType);
    w.writeUint32(4, this.gamingDeviceType);
    return w.finish();
  }
}

/** CAuthentication_AllowedConfirmation */
export class CAuthentication_AllowedConfirmation {
  confirmationType: number = EAuthSessionGuardType.UNKNOWN;
  associatedMessage: string = '';

  static decode(r: ProtoReader): CAuthentication_AllowedConfirmation {
    const out = new CAuthentication_AllowedConfirmation();
    while (r.next()) {
      switch (r.field()) {
        case 1: out.confirmationType = r.readInt32(); break;
        case 2: out.associatedMessage = r.readString(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CAuthentication_BeginAuthSessionViaCredentials_Request */
export class CAuthentication_BeginAuthSessionViaCredentials_Request {
  accountName: string = '';
  encryptedPassword: string = '';
  encryptionTimestamp: bigint = 0n;
  persistence: number = ESessionPersistence.PERSISTENT;
  deviceDetails: CAuthentication_DeviceDetails = new CAuthentication_DeviceDetails();
  language: number = 0;
  qosLevel: number = 2;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeString(2, this.accountName);
    w.writeString(3, this.encryptedPassword);
    w.writeUint64(4, this.encryptionTimestamp);
    w.writeInt32(7, this.persistence);
    w.writeBytes(9, this.deviceDetails.encode());
    w.writeUint32(11, this.language);
    w.writeInt32(12, this.qosLevel);
    return w.finish();
  }
}

/** CAuthentication_BeginAuthSessionViaCredentials_Response */
export class CAuthentication_BeginAuthSessionViaCredentials_Response {
  clientId: bigint = 0n;
  requestId: Uint8Array = new Uint8Array(0);
  interval: number = 5;
  allowedConfirmations: CAuthentication_AllowedConfirmation[] = [];
  /** 注意：本字段是 uint64（varint），不是 fixed64 */
  steamid: bigint = 0n;
  weakToken: string = '';
  agreementSessionUrl: string = '';
  extendedErrorMessage: string = '';

  static decode(buf: Uint8Array): CAuthentication_BeginAuthSessionViaCredentials_Response {
    const out = new CAuthentication_BeginAuthSessionViaCredentials_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.clientId = r.readUint64(); break;
        case 2: out.requestId = r.readBytes(); break;
        case 3: out.interval = r.readFloat32(); break;
        case 4: out.allowedConfirmations.push(CAuthentication_AllowedConfirmation.decode(r.readMessage())); break;
        case 5: out.steamid = r.readUint64(); break;
        case 6: out.weakToken = r.readString(); break;
        case 7: out.agreementSessionUrl = r.readString(); break;
        case 8: out.extendedErrorMessage = r.readString(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CAuthentication_UpdateAuthSessionWithSteamGuardCode_Request */
export class CAuthentication_UpdateAuthSessionWithSteamGuardCode_Request {
  clientId: bigint = 0n;
  steamid: bigint = 0n;
  code: string = '';
  codeType: number = EAuthSessionGuardType.UNKNOWN;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeUint64(1, this.clientId);
    w.writeFixed64(2, this.steamid);
    w.writeString(3, this.code);
    w.writeInt32(4, this.codeType);
    return w.finish();
  }
}

/** CAuthentication_PollAuthSessionStatus_Request */
export class CAuthentication_PollAuthSessionStatus_Request {
  clientId: bigint = 0n;
  requestId: Uint8Array = new Uint8Array(0);

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeUint64(1, this.clientId);
    w.writeBytes(2, this.requestId);
    return w.finish();
  }
}

/** CAuthentication_PollAuthSessionStatus_Response */
export class CAuthentication_PollAuthSessionStatus_Response {
  newClientId: bigint = 0n;
  newChallengeUrl: string = '';
  refreshToken: string = '';
  accessToken: string = '';
  hadRemoteInteraction: boolean = false;
  accountName: string = '';
  newGuardData: string = '';
  agreementSessionUrl: string = '';

  static decode(buf: Uint8Array): CAuthentication_PollAuthSessionStatus_Response {
    const out = new CAuthentication_PollAuthSessionStatus_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.newClientId = r.readUint64(); break;
        case 2: out.newChallengeUrl = r.readString(); break;
        case 3: out.refreshToken = r.readString(); break;
        case 4: out.accessToken = r.readString(); break;
        case 5: out.hadRemoteInteraction = r.readBool(); break;
        case 6: out.accountName = r.readString(); break;
        case 7: out.newGuardData = r.readString(); break;
        case 8: out.agreementSessionUrl = r.readString(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// ITwoFactorService
// ---------------------------------------------------------------------------

/** CTwoFactor_AddAuthenticator_Request */
export class CTwoFactor_AddAuthenticator_Request {
  steamid: bigint = 0n;
  authenticatorType: number = 1;
  deviceIdentifier: string = '';
  smsPhoneId: string = '1';
  version: number = 1;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeFixed64(1, this.steamid);
    w.writeUint32(4, this.authenticatorType);
    w.writeString(5, this.deviceIdentifier);
    w.writeString(6, this.smsPhoneId);
    w.writeUint32(8, this.version);
    return w.finish();
  }
}

/** CTwoFactor_AddAuthenticator_Response */
export class CTwoFactor_AddAuthenticator_Response {
  sharedSecret: Uint8Array = new Uint8Array(0);
  serialNumber: bigint = 0n;
  revocationCode: string = '';
  uri: string = '';
  serverTime: bigint = 0n;
  accountName: string = '';
  tokenGid: string = '';
  identitySecret: Uint8Array = new Uint8Array(0);
  secret1: Uint8Array = new Uint8Array(0);
  status: number = 0;
  phoneNumberHint: string = '';
  confirmType: number = 0;

  static decode(buf: Uint8Array): CTwoFactor_AddAuthenticator_Response {
    const out = new CTwoFactor_AddAuthenticator_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.sharedSecret = r.readBytes(); break;
        case 2: out.serialNumber = r.readFixed64(); break;
        case 3: out.revocationCode = r.readString(); break;
        case 4: out.uri = r.readString(); break;
        case 5: out.serverTime = r.readUint64(); break;
        case 6: out.accountName = r.readString(); break;
        case 7: out.tokenGid = r.readString(); break;
        case 8: out.identitySecret = r.readBytes(); break;
        case 9: out.secret1 = r.readBytes(); break;
        case 10: out.status = r.readInt32(); break;
        case 11: out.phoneNumberHint = r.readString(); break;
        case 12: out.confirmType = r.readInt32(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CTwoFactor_FinalizeAddAuthenticator_Request */
export class CTwoFactor_FinalizeAddAuthenticator_Request {
  steamid: bigint = 0n;
  authenticatorCode: string = '';
  authenticatorTime: bigint = 0n;
  activationCode: string = '';
  validateSmsCode: boolean = true;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeFixed64(1, this.steamid);
    w.writeString(2, this.authenticatorCode);
    w.writeUint64(3, this.authenticatorTime);
    w.writeString(4, this.activationCode);
    w.writeBool(6, this.validateSmsCode);
    return w.finish();
  }
}

/** CTwoFactor_FinalizeAddAuthenticator_Response */
export class CTwoFactor_FinalizeAddAuthenticator_Response {
  success: boolean = false;
  wantMore: boolean = false;
  serverTime: bigint = 0n;
  status: number = 0;

  static decode(buf: Uint8Array): CTwoFactor_FinalizeAddAuthenticator_Response {
    const out = new CTwoFactor_FinalizeAddAuthenticator_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.success = r.readBool(); break;
        case 2: out.wantMore = r.readBool(); break;
        case 3: out.serverTime = r.readUint64(); break;
        case 4: out.status = r.readInt32(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CTwoFactor_Status_Request */
export class CTwoFactor_Status_Request {
  steamid: bigint = 0n;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeFixed64(1, this.steamid);
    return w.finish();
  }
}

/** CTwoFactor_Status_Response */
export class CTwoFactor_Status_Response {
  state: number = 0;
  inactivationReason: number = 0;
  authenticatorType: number = 0;
  authenticatorAllowed: boolean = false;
  steamguardScheme: number = 0;
  tokenGid: string = '';
  emailValidated: boolean = false;
  deviceIdentifier: string = '';
  timeCreated: number = 0;
  revocationAttemptsRemaining: number = 0;
  classifiedAgent: string = '';
  allowExternalAuthenticator: boolean = false;
  timeTransferred: number = 0;
  version: number = 0;

  static decode(buf: Uint8Array): CTwoFactor_Status_Response {
    const out = new CTwoFactor_Status_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.state = r.readUint32(); break;
        case 2: out.inactivationReason = r.readUint32(); break;
        case 3: out.authenticatorType = r.readUint32(); break;
        case 4: out.authenticatorAllowed = r.readBool(); break;
        case 5: out.steamguardScheme = r.readUint32(); break;
        case 6: out.tokenGid = r.readString(); break;
        case 7: out.emailValidated = r.readBool(); break;
        case 8: out.deviceIdentifier = r.readString(); break;
        case 9: out.timeCreated = r.readUint32(); break;
        case 10: out.revocationAttemptsRemaining = r.readUint32(); break;
        case 11: out.classifiedAgent = r.readString(); break;
        case 12: out.allowExternalAuthenticator = r.readBool(); break;
        case 13: out.timeTransferred = r.readUint32(); break;
        case 14: out.version = r.readUint32(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CTwoFactor_RemoveAuthenticator_Request（撤销验证器） */
export class CTwoFactor_RemoveAuthenticator_Request {
  revocationCode: string = '';
  revocationReason: number = 0;
  steamguardScheme: number = 1;
  removeAllSteamguardCookies: boolean = false;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeString(2, this.revocationCode);
    w.writeUint32(5, this.revocationReason);
    w.writeUint32(6, this.steamguardScheme);
    w.writeBool(7, this.removeAllSteamguardCookies);
    return w.finish();
  }
}

/** CTwoFactor_RemoveAuthenticator_Response */
export class CTwoFactor_RemoveAuthenticator_Response {
  success: boolean = false;
  serverTime: bigint = 0n;
  revocationAttemptsRemaining: number = 0;

  static decode(buf: Uint8Array): CTwoFactor_RemoveAuthenticator_Response {
    const out = new CTwoFactor_RemoveAuthenticator_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.success = r.readBool(); break;
        case 3: out.serverTime = r.readUint64(); break;
        case 5: out.revocationAttemptsRemaining = r.readUint32(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CTwoFactor_RemoveAuthenticatorViaChallengeStart_Response（请求体为空） */
export class CTwoFactor_RemoveAuthenticatorViaChallengeStart_Response {
  success: boolean = false;

  static decode(buf: Uint8Array): CTwoFactor_RemoveAuthenticatorViaChallengeStart_Response {
    const out = new CTwoFactor_RemoveAuthenticatorViaChallengeStart_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.success = r.readBool(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request */
export class CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request {
  smsCode: string = '';
  generateNewToken: boolean = true;
  version: number = 1;

  encode(): Uint8Array {
    const w = new ProtoWriter();
    w.writeString(1, this.smsCode);
    w.writeBool(2, this.generateNewToken);
    w.writeUint32(3, this.version);
    return w.finish();
  }
}

/** CRemoveAuthenticatorViaChallengeContinue_Replacement_Token（迁移得到的令牌数据） */
export class CRemoveAuthenticatorViaChallengeContinue_Replacement_Token {
  sharedSecret: Uint8Array = new Uint8Array(0);
  serialNumber: bigint = 0n;
  revocationCode: string = '';
  uri: string = '';
  serverTime: bigint = 0n;
  accountName: string = '';
  tokenGid: string = '';
  identitySecret: Uint8Array = new Uint8Array(0);
  secret1: Uint8Array = new Uint8Array(0);
  status: number = 0;
  steamguardScheme: number = 0;
  steamid: bigint = 0n;

  static decode(r: ProtoReader): CRemoveAuthenticatorViaChallengeContinue_Replacement_Token {
    const out = new CRemoveAuthenticatorViaChallengeContinue_Replacement_Token();
    while (r.next()) {
      switch (r.field()) {
        case 1: out.sharedSecret = r.readBytes(); break;
        case 2: out.serialNumber = r.readFixed64(); break;
        case 3: out.revocationCode = r.readString(); break;
        case 4: out.uri = r.readString(); break;
        case 5: out.serverTime = r.readUint64(); break;
        case 6: out.accountName = r.readString(); break;
        case 7: out.tokenGid = r.readString(); break;
        case 8: out.identitySecret = r.readBytes(); break;
        case 9: out.secret1 = r.readBytes(); break;
        case 10: out.status = r.readInt32(); break;
        case 11: out.steamguardScheme = r.readUint32(); break;
        case 12: out.steamid = r.readFixed64(); break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}

/** CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response */
export class CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response {
  success: boolean = false;
  replacementToken: CRemoveAuthenticatorViaChallengeContinue_Replacement_Token | undefined = undefined;

  static decode(buf: Uint8Array): CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response {
    const out = new CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response();
    const r = new ProtoReader(buf);
    while (r.next()) {
      switch (r.field()) {
        case 1: out.success = r.readBool(); break;
        case 2:
          out.replacementToken =
            CRemoveAuthenticatorViaChallengeContinue_Replacement_Token.decode(r.readMessage());
          break;
        default: r.skip(); break;
      }
    }
    return out;
  }
}
