import { describe, it, expect } from '@ohos/hypium';
import { otpType } from 'common';
import {
  activationCodeIsSms,
  buildAuthFromAdd,
  buildAuthFromTransfer,
  buildSteamTokenConfig,
  confirmationNeedsCode,
  extractSecretFromUri,
  FINALIZE_RETRY_DELAY_MS,
  FinalizeContext,
  finalizeUntilSuccess,
  secretBytesToBase32,
  shouldFallbackToTransfer,
} from '../main/ets/steam/SteamFlow';
import {
  CTwoFactor_AddAuthenticator_Response,
  CTwoFactor_FinalizeAddAuthenticator_Response,
  CRemoveAuthenticatorViaChallengeContinue_Replacement_Token,
} from '../main/ets/steam/proto/SteamMessages';
import { SteamApiError } from '../main/ets/steam/SteamError';

/** 假 Finalize 上下文：按脚本返回 success/want_more，并记录调用轨迹 */
class FakeFinalizeContext implements FinalizeContext {
  responses: CTwoFactor_FinalizeAddAuthenticator_Response[] = [];
  codes: string[] = [];
  serverTimes: number[] = [];
  sleeps: number[] = [];
  serverTime: number = 1788953926;

  push(success: boolean, wantMore: boolean, status: number = 0): void {
    const response = new CTwoFactor_FinalizeAddAuthenticator_Response();
    response.success = success;
    response.wantMore = wantMore;
    response.status = status;
    this.responses.push(response);
  }

  attempt = (authenticatorCode: string, serverTimeSeconds: number):
    Promise<CTwoFactor_FinalizeAddAuthenticator_Response> => {
    this.codes.push(authenticatorCode);
    this.serverTimes.push(serverTimeSeconds);
    const next: CTwoFactor_FinalizeAddAuthenticator_Response | undefined = this.responses.shift();
    return Promise.resolve(next ?? new CTwoFactor_FinalizeAddAuthenticator_Response());
  };

  codeForServerTime = (serverTimeSeconds: number): string => {
    return `CODE${this.codes.length + 1}`;
  };

  currentServerTimeSeconds = (): number => {
    return this.serverTime;
  };

  sleep = (ms: number): Promise<void> => {
    this.sleeps.push(ms);
    return Promise.resolve();
  };
}

/**
 * Steam 登录/迁移流程纯逻辑测试。
 *
 * 这些转换决定了「写入令牌的 secret 是否正确」以及「添加失败是否转迁移」，
 * 是真机联调前必须锁死的部分。
 */

function bytesOf(values: number[]): Uint8Array {
  const out = new Uint8Array(values.length);
  for (let i = 0; i < values.length; i++) {
    out[i] = values[i];
  }
  return out;
}

function sampleAddResponse(): CTwoFactor_AddAuthenticator_Response {
  const response = new CTwoFactor_AddAuthenticator_Response();
  response.sharedSecret = bytesOf([0x66, 0x6f, 0x6f, 0x62, 0x61, 0x72]); // "foobar"
  response.serialNumber = 1234567890n;
  response.revocationCode = 'R12345';
  response.uri = 'otpauth://totp/Steam:testuser?secret=MZXW6YTBOI&issuer=Steam';
  response.serverTime = 1788953926n;
  response.accountName = 'testuser';
  response.tokenGid = 'gid123';
  response.identitySecret = bytesOf([0xfe, 0xdc, 0xba, 0x98]);
  response.status = 2;
  response.confirmType = 1;
  return response;
}

export default function steamFlowTest() {
  describe('steamFlowTest', () => {
    it('extract_secret_from_otpauth_uri', 0, () => {
      expect(extractSecretFromUri('otpauth://totp/Steam:user?secret=MZXW6YTBOI&issuer=Steam'))
        .assertEqual('MZXW6YTBOI');
      expect(extractSecretFromUri('otpauth://totp/Steam:user?issuer=Steam&secret=abcdef'))
        .assertEqual('ABCDEF');
      expect(extractSecretFromUri('otpauth://totp/Steam:user?issuer=Steam')).assertEqual('');
      expect(extractSecretFromUri('')).assertEqual('');
    });

    it('shared_secret_bytes_to_base32', 0, () => {
      // "foobar" → RFC4648 base32 = MZXW6YTBOI======（去掉填充）
      expect(secretBytesToBase32(bytesOf([0x66, 0x6f, 0x6f, 0x62, 0x61, 0x72])))
        .assertEqual('MZXW6YTBOI');
    });

    it('build_auth_from_add_response', 0, () => {
      const auth = buildAuthFromAdd(sampleAddResponse(), 'inputname', '76561198000000000',
        'android:device-1', 'refresh-token', 'access-token');
      expect(auth.accountName).assertEqual('testuser');
      expect(auth.steamid).assertEqual('76561198000000000');
      expect(auth.deviceId).assertEqual('android:device-1');
      expect(auth.serialNumber).assertEqual('1234567890');
      expect(auth.tokenGid).assertEqual('gid123');
      expect(auth.serverTime).assertEqual(1788953926);
      // identity_secret 字节 → base64（交易确认签名要求 base64）
      expect(auth.identitySecret).assertEqual('/ty6mA==');
      expect(auth.revocationCode).assertEqual('R12345');
      expect(auth.refreshToken).assertEqual('refresh-token');
      expect(auth.hasConfirmationCredentials()).assertTrue();
      expect(auth.canRevoke()).assertTrue();
    });

    it('build_auth_from_transfer_token_prefers_token_steamid', 0, () => {
      const token = new CRemoveAuthenticatorViaChallengeContinue_Replacement_Token();
      token.sharedSecret = bytesOf([0x01, 0x02]);
      token.serialNumber = 42n;
      token.revocationCode = 'R99999';
      token.uri = 'otpauth://totp/Steam:user?secret=AAAA&issuer=Steam';
      token.serverTime = 1788953999n;
      token.accountName = 'transferuser';
      token.tokenGid = 'gid999';
      token.identitySecret = bytesOf([0x11, 0x22]);
      token.steamguardScheme = 2;
      token.steamid = 76561198000000001n;

      const auth = buildAuthFromTransfer(token, 'fallback', '76561198000000000', 'android:dev',
        'refresh', 'access');
      expect(auth.accountName).assertEqual('transferuser');
      expect(auth.steamid).assertEqual('76561198000000001');
      expect(auth.serialNumber).assertEqual('42');
      expect(auth.steamguardScheme).assertEqual(2);
      expect(auth.identitySecret).assertEqual('ESI=');
    });

    it('build_token_config_uses_steam_parameters', 0, () => {
      const auth = buildAuthFromAdd(sampleAddResponse(), 'testuser', '76561198000000000',
        'android:dev', 'refresh', 'access');
      const conf = buildSteamTokenConfig(auth, 'MZXW6YTBOI', 'Steam', 'testuser', 7);
      expect(conf.TokenType).assertEqual(otpType.Steam);
      expect(conf.TokenSecret).assertEqual('MZXW6YTBOI');
      expect(conf.TokenIssuer).assertEqual('Steam');
      expect(conf.TokenName).assertEqual('testuser');
      expect(conf.TokenAlgorithm).assertEqual('SHA1');
      expect(conf.TokenPeriod).assertEqual(30);
      // digits=10 保留完整 31 位截断值，再由 5 位算法映射
      expect(conf.TokenDigits).assertEqual(10);
      expect(conf.RankScore).assertEqual(7);
      expect(conf.SteamAuth !== undefined).assertTrue();
      expect(conf.SteamAuth!.refreshToken).assertEqual('refresh');
    });

    it('duplicate_request_triggers_transfer_branch', 0, () => {
      expect(shouldFallbackToTransfer(29)).assertTrue();
      expect(shouldFallbackToTransfer(1)).assertFalse();
      expect(shouldFallbackToTransfer(84)).assertFalse();
    });

    it('confirmation_code_requirement_and_activation_channel', 0, () => {
      expect(confirmationNeedsCode(3)).assertTrue();  // DeviceCode
      expect(confirmationNeedsCode(2)).assertTrue();  // EmailCode
      expect(confirmationNeedsCode(4)).assertFalse(); // DeviceConfirmation
      expect(confirmationNeedsCode(5)).assertFalse(); // EmailConfirmation

      expect(activationCodeIsSms(1)).assertTrue();   // SMS
      expect(activationCodeIsSms(3)).assertFalse();  // Email
    });

    it('finalize_retries_with_fresh_code_on_want_more', 0, async () => {
      const ctx = new FakeFinalizeContext();
      ctx.push(false, true);   // 第一次：时间步未对齐
      ctx.push(false, true);   // 第二次：仍未对齐
      ctx.push(true, false);   // 第三次：成功

      const ok = await finalizeUntilSuccess(ctx, 5);
      expect(ok).assertTrue();
      expect(ctx.codes.length).assertEqual(3);
      // 每次都用「新码」（不是重复同一个）
      expect(ctx.codes[0] !== ctx.codes[1]).assertTrue();
      expect(ctx.codes[1] !== ctx.codes[2]).assertTrue();
      // 重试之间等待 FINALIZE_RETRY_DELAY_MS
      expect(ctx.sleeps.length).assertEqual(2);
      expect(ctx.sleeps[0]).assertEqual(FINALIZE_RETRY_DELAY_MS);
      // authenticator_time 传的是服务端时间
      expect(ctx.serverTimes[0]).assertEqual(ctx.serverTime);
    });

    it('finalize_gives_up_after_max_attempts', 0, async () => {
      const ctx = new FakeFinalizeContext();
      ctx.push(false, true);
      ctx.push(false, true);
      ctx.push(false, true);

      const ok = await finalizeUntilSuccess(ctx, 3);
      expect(ok).assertFalse();
      expect(ctx.codes.length).assertEqual(3);
      expect(ctx.sleeps.length).assertEqual(2); // 最后一次不再等待
    });

    it('finalize_throws_on_hard_rejection', 0, async () => {
      const ctx = new FakeFinalizeContext();
      ctx.push(false, false, 88); // TwoFactorCodeMismatch

      let eresult = 0;
      let threw = false;
      try {
        await finalizeUntilSuccess(ctx, 5);
      } catch (e) {
        threw = true;
        eresult = (e as SteamApiError).eresult;
      }
      expect(threw).assertTrue();
      expect(eresult).assertEqual(88);
      expect(ctx.sleeps.length).assertEqual(0);
    });

    it('finalize_returns_immediately_on_success', 0, async () => {
      const ctx = new FakeFinalizeContext();
      ctx.push(true, false);
      const ok = await finalizeUntilSuccess(ctx, 5);
      expect(ok).assertTrue();
      expect(ctx.codes.length).assertEqual(1);
      expect(ctx.sleeps.length).assertEqual(0);
    });
  });
}
