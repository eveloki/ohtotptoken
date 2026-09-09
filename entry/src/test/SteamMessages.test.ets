import { describe, it, expect } from '@ohos/hypium';
import {
  CAuthentication_BeginAuthSessionViaCredentials_Request,
  CAuthentication_BeginAuthSessionViaCredentials_Response,
  CAuthentication_UpdateAuthSessionWithSteamGuardCode_Request,
  CAuthentication_PollAuthSessionStatus_Request,
  CAuthentication_PollAuthSessionStatus_Response,
  CTwoFactor_AddAuthenticator_Request,
  CTwoFactor_AddAuthenticator_Response,
  CTwoFactor_FinalizeAddAuthenticator_Request,
  CTwoFactor_FinalizeAddAuthenticator_Response,
  CTwoFactor_RemoveAuthenticator_Request,
  CTwoFactor_RemoveAuthenticator_Response,
  CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request,
  CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response,
  EAuthSessionGuardType,
  ESessionPersistence,
} from '../main/ets/steam/proto/SteamMessages';

/**
 * Steam 消息编解码交叉验证。
 *
 * 期望字节由 protobufjs@7.4.0（独立实现）按官方 .proto 字段号编码产出，
 * 生成脚本见 `.local/golden/gen-golden.mjs`，输出 `.local/golden/vectors.json`。
 * - 请求侧：ArkTS 编码结果必须与 protobufjs **逐字节一致**
 * - 响应侧：ArkTS 解码 protobufjs 产出的字节，字段值必须全部正确
 *
 * 这样可以在没有真机/网络的情况下锁定 wire format 正确性。
 */

const STEAMID = 76561198000000000n;
const CLIENT_ID = 1234567890123456789n;

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return out;
}

function bytesToHex(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, '0');
  }
  return out;
}

// ---- protobufjs 产出的黄金向量（勿手改） ----
interface SteamGoldenVectors {
  beginAuth: string;
  updateGuardCode: string;
  pollStatus: string;
  addAuthenticator: string;
  finalizeAddAuthenticator: string;
  removeAuthenticator: string;
  challengeContinue: string;
  beginAuthResponse: string;
  pollResponse: string;
  addAuthenticatorResponse: string;
  finalizeResponse: string;
  challengeContinueResponse: string;
  removeAuthenticatorResponse: string;
}

const GOLDEN: SteamGoldenVectors = {
  beginAuth: '120b746573746163636f756e741a0c51554a445245564752773d3d20c68a85d50638014a1f0a0d41757468656e74696361746f721003188cfcffffffffffffff0120900458006002',
  updateGuardCode: '089582a6efc79e84911111004c5e02010010011a0541424331322003',
  pollStatus: '089582a6efc79e84911112100102030405060708090a0b0c0d0e0f10',
  addAuthenticator: '09004c5e020100100120012a2c616e64726f69643a31313131313131312d323232322d333333332d343434342d3535353535353535353535353201314001',
  finalizeAddAuthenticator: '09004c5e0201001001120558595a313218c68a85d506220535343332313001',
  removeAuthenticator: '1206523132333435280030013800',
  challengeContinue: '0a05313233343510011801',
  beginAuthResponse: '089582a6efc79e8491111208deadbeef001122331d0000a040220408031200221508041211612a2a2a7a406578616d706c652e636f6d288098f992908080880132107765616b2d746f6b656e2d76616c75653a004200',
  pollResponse: '089582a6efc79e8491111a2465794a68624763694f694a49557a49314e694a392e726566726573682e7061796c6f6164222365794a68624763694f694a49557a49314e694a392e6163636573732e7061796c6f61642801320b746573746163636f756e743a0a67756172642d64617461',
  addAuthenticatorResponse: '0a080123456789abcdef111581e97df41022111a0652313233343522456f7470617574683a2f2f746f74702f537465616d3a746573746163636f756e743f7365637265743d4142434445464748494a4b4c4d4e4f50266973737565723d537465616d28c68a85d506320b746573746163636f756e743a066769643132334204fedcba984a02112250025a072a2a2a313233346001',
  finalizeResponse: '0800100118c68a85d5062058',
  challengeContinueResponse: '08011294010a080123456789abcdef111581e97df41022111a0652393939393922456f7470617574683a2f2f746f74702f537465616d3a746573746163636f756e743f7365637265743d4142434445464748494a4b4c4d4e4f50266973737565723d537465616d288f8b85d506320b746573746163636f756e743a066769643939394204fedcba984a0233445002580261004c5e0201001001',
  removeAuthenticatorResponse: '080118908b85d5062804',
};

export default function steamMessagesTest() {
  describe('steamMessagesTest', () => {
    it('begin_auth_request_matches_protobufjs', 0, () => {
      const req = new CAuthentication_BeginAuthSessionViaCredentials_Request();
      req.accountName = 'testaccount';
      req.encryptedPassword = 'QUJDREVGRw==';
      req.encryptionTimestamp = 1788953926n;
      req.persistence = ESessionPersistence.PERSISTENT;
      req.deviceDetails.deviceFriendlyName = 'Authenticator';
      req.deviceDetails.platformType = 3;
      req.deviceDetails.osType = -500;
      req.deviceDetails.gamingDeviceType = 528;
      req.language = 0;
      req.qosLevel = 2;
      expect(bytesToHex(req.encode())).assertEqual(GOLDEN.beginAuth);
    });

    it('update_guard_code_request_matches_protobufjs', 0, () => {
      const req = new CAuthentication_UpdateAuthSessionWithSteamGuardCode_Request();
      req.clientId = CLIENT_ID;
      req.steamid = STEAMID;
      req.code = 'ABC12';
      req.codeType = EAuthSessionGuardType.DEVICE_CODE;
      expect(bytesToHex(req.encode())).assertEqual(GOLDEN.updateGuardCode);
    });

    it('poll_status_request_matches_protobufjs', 0, () => {
      const req = new CAuthentication_PollAuthSessionStatus_Request();
      req.clientId = CLIENT_ID;
      req.requestId = Uint8Array.from([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
      expect(bytesToHex(req.encode())).assertEqual(GOLDEN.pollStatus);
    });

    it('add_authenticator_request_matches_protobufjs', 0, () => {
      const req = new CTwoFactor_AddAuthenticator_Request();
      req.steamid = STEAMID;
      req.authenticatorType = 1;
      req.deviceIdentifier = 'android:11111111-2222-3333-4444-555555555555';
      req.smsPhoneId = '1';
      req.version = 1;
      expect(bytesToHex(req.encode())).assertEqual(GOLDEN.addAuthenticator);
    });

    it('finalize_request_matches_protobufjs', 0, () => {
      const req = new CTwoFactor_FinalizeAddAuthenticator_Request();
      req.steamid = STEAMID;
      req.authenticatorCode = 'XYZ12';
      req.authenticatorTime = 1788953926n;
      req.activationCode = '54321';
      req.validateSmsCode = true;
      expect(bytesToHex(req.encode())).assertEqual(GOLDEN.finalizeAddAuthenticator);
    });

    it('remove_authenticator_request_matches_protobufjs', 0, () => {
      const req = new CTwoFactor_RemoveAuthenticator_Request();
      req.revocationCode = 'R12345';
      req.revocationReason = 0;
      req.steamguardScheme = 1;
      req.removeAllSteamguardCookies = false;
      expect(bytesToHex(req.encode())).assertEqual(GOLDEN.removeAuthenticator);
    });

    it('challenge_continue_request_matches_protobufjs', 0, () => {
      const req = new CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request();
      req.smsCode = '12345';
      req.generateNewToken = true;
      req.version = 1;
      expect(bytesToHex(req.encode())).assertEqual(GOLDEN.challengeContinue);
    });

    it('decode_begin_auth_response', 0, () => {
      const resp = CAuthentication_BeginAuthSessionViaCredentials_Response.decode(
        hexToBytes(GOLDEN.beginAuthResponse));
      expect(resp.clientId.toString()).assertEqual(CLIENT_ID.toString());
      expect(bytesToHex(resp.requestId)).assertEqual('deadbeef00112233');
      expect(resp.interval).assertEqual(5.0);
      expect(resp.allowedConfirmations.length).assertEqual(2);
      expect(resp.allowedConfirmations[0].confirmationType).assertEqual(EAuthSessionGuardType.DEVICE_CODE);
      expect(resp.allowedConfirmations[0].associatedMessage).assertEqual('');
      expect(resp.allowedConfirmations[1].confirmationType)
        .assertEqual(EAuthSessionGuardType.DEVICE_CONFIRMATION);
      expect(resp.allowedConfirmations[1].associatedMessage).assertEqual('a***z@example.com');
      // 该字段是 uint64（varint），不是 fixed64
      expect(resp.steamid.toString()).assertEqual(STEAMID.toString());
      expect(resp.weakToken).assertEqual('weak-token-value');
    });

    it('decode_poll_response', 0, () => {
      const resp = CAuthentication_PollAuthSessionStatus_Response.decode(
        hexToBytes(GOLDEN.pollResponse));
      expect(resp.newClientId.toString()).assertEqual(CLIENT_ID.toString());
      expect(resp.refreshToken).assertEqual('eyJhbGciOiJIUzI1NiJ9.refresh.payload');
      expect(resp.accessToken).assertEqual('eyJhbGciOiJIUzI1NiJ9.access.payload');
      expect(resp.hadRemoteInteraction).assertTrue();
      expect(resp.accountName).assertEqual('testaccount');
      expect(resp.newGuardData).assertEqual('guard-data');
    });

    it('decode_add_authenticator_response', 0, () => {
      const resp = CTwoFactor_AddAuthenticator_Response.decode(
        hexToBytes(GOLDEN.addAuthenticatorResponse));
      expect(bytesToHex(resp.sharedSecret)).assertEqual('0123456789abcdef');
      expect(resp.serialNumber.toString()).assertEqual(CLIENT_ID.toString());
      expect(resp.revocationCode).assertEqual('R12345');
      expect(resp.uri).assertEqual('otpauth://totp/Steam:testaccount?secret=ABCDEFGHIJKLMNOP&issuer=Steam');
      expect(resp.serverTime.toString()).assertEqual('1788953926');
      expect(resp.accountName).assertEqual('testaccount');
      expect(resp.tokenGid).assertEqual('gid123');
      expect(bytesToHex(resp.identitySecret)).assertEqual('fedcba98');
      expect(bytesToHex(resp.secret1)).assertEqual('1122');
      expect(resp.status).assertEqual(2);
      expect(resp.phoneNumberHint).assertEqual('***1234');
      expect(resp.confirmType).assertEqual(1);
    });

    it('decode_finalize_response_want_more', 0, () => {
      const resp = CTwoFactor_FinalizeAddAuthenticator_Response.decode(
        hexToBytes(GOLDEN.finalizeResponse));
      expect(resp.success).assertFalse();
      expect(resp.wantMore).assertTrue();
      expect(resp.serverTime.toString()).assertEqual('1788953926');
      expect(resp.status).assertEqual(88);
    });

    it('decode_challenge_continue_response_replacement_token', 0, () => {
      const resp = CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response.decode(
        hexToBytes(GOLDEN.challengeContinueResponse));
      expect(resp.success).assertTrue();
      const token = resp.replacementToken!;
      expect(bytesToHex(token.sharedSecret)).assertEqual('0123456789abcdef');
      expect(token.serialNumber.toString()).assertEqual(CLIENT_ID.toString());
      expect(token.revocationCode).assertEqual('R99999');
      expect(token.serverTime.toString()).assertEqual('1788953999');
      expect(token.accountName).assertEqual('testaccount');
      expect(token.tokenGid).assertEqual('gid999');
      expect(bytesToHex(token.identitySecret)).assertEqual('fedcba98');
      expect(bytesToHex(token.secret1)).assertEqual('3344');
      expect(token.status).assertEqual(2);
      expect(token.steamguardScheme).assertEqual(2);
      expect(token.steamid.toString()).assertEqual(STEAMID.toString());
    });

    it('decode_remove_authenticator_response', 0, () => {
      const resp = CTwoFactor_RemoveAuthenticator_Response.decode(
        hexToBytes(GOLDEN.removeAuthenticatorResponse));
      expect(resp.success).assertTrue();
      expect(resp.serverTime.toString()).assertEqual('1788954000');
      expect(resp.revocationAttemptsRemaining).assertEqual(4);
    });
  });
}
