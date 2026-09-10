import { describe, it, expect } from '@ohos/hypium';
import { HttpRequestSpec, HttpResult, HttpTransport, SteamTransport } from '../main/ets/steam/SteamHttp';
import {
  confirmationSignature,
  parseSteamQrChallenge,
  qrLoginSignature,
  Sleeper,
  SteamAuthSession,
  SteamClient,
  SteamConfirmation,
} from '../main/ets/steam/SteamClient';
import { eresultMessage, eresultName, SteamApiError } from '../main/ets/steam/SteamError';
import { ProtoWriter } from 'common';
import { EAuthSessionGuardType } from '../main/ets/steam/proto/SteamMessages';
import { base64Encode, utf8ToBytes } from '../main/ets/steam/SteamCrypto';

/**
 * Steam 客户端测试（无网络）。
 *
 * 用假传输层驱动协议逻辑，覆盖：
 * - 纯函数：二维码解析、扫码签名、交易确认签名（期望值与 node:crypto 对齐）
 * - 状态机：按服务端 interval 轮询、DuplicateRequest → 迁移分支判定
 * - 响应解析：交易确认列表、access_token 缓存
 */

const SECRET_B64 = 'MDEyMzQ1Njc4OWFiY2RlZg==';
const STEAMID = 76561198000000000n;
const CLIENT_ID = 1234567890123456789n;

/** 与 node:crypto 对齐的签名期望值（见 .local/golden/gen-golden.mjs） */
const QR_SIGNATURE_GOLDEN = 'OtjbWVrp9cIo7%2BTTpVrz5wLu21NMFLSCrHWKb%2BEWRXc%3D';
const CONFIRM_SIGNATURE_GOLDEN = '9o6d%2Fibq3gvVCFg4J%2Bhr3CMx9QM%3D';

class FakeSleeper implements Sleeper {
  sleeps: number[] = [];

  sleep(ms: number): Promise<void> {
    this.sleeps.push(ms);
    return Promise.resolve();
  }
}

class FakeTransport implements HttpTransport {
  specs: HttpRequestSpec[] = [];
  private queue: HttpResult[] = [];

  push(result: HttpResult): void {
    this.queue.push(result);
  }

  send(spec: HttpRequestSpec): Promise<HttpResult> {
    this.specs.push(spec);
    const next: HttpResult | undefined = this.queue.shift();
    return Promise.resolve(next === undefined ? new HttpResult() : next);
  }
}

function okResult(bytes: Uint8Array): HttpResult {
  const result = new HttpResult();
  result.statusCode = 200;
  result.headers = { 'x-eresult': '1' };
  result.bytes = bytes;
  return result;
}

function okText(text: string): HttpResult {
  const result = new HttpResult();
  result.statusCode = 200;
  result.headers = { 'x-eresult': '1' };
  result.text = text;
  return result;
}

function errorResult(eresult: number): HttpResult {
  const result = new HttpResult();
  result.statusCode = 200;
  result.headers = { 'x-eresult': `${eresult}` };
  result.bytes = new Uint8Array(0);
  return result;
}

/** 构造 PollAuthSessionStatus 响应（字段号与官方一致） */
function pollBytes(refreshToken: string, accessToken: string, accountName: string): Uint8Array {
  const w = new ProtoWriter();
  if (refreshToken.length > 0) {
    w.writeString(3, refreshToken);
  }
  if (accessToken.length > 0) {
    w.writeString(4, accessToken);
  }
  if (accountName.length > 0) {
    w.writeString(6, accountName);
  }
  return w.finish();
}

function jwtWithExp(exp: number): string {
  const payload = base64Encode(utf8ToBytes(`{"exp":${exp}}`))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `header.${payload}.sig`;
}

export default function steamClientTest() {
  describe('steamClientTest', () => {
    it('parse_qr_challenge_valid_and_invalid', 0, () => {
      const ok = parseSteamQrChallenge('https://s.team/q/2/1234567890123456789')!;
      expect(ok.version).assertEqual(2);
      expect(ok.clientId.toString()).assertEqual('1234567890123456789');

      const withQuery = parseSteamQrChallenge('https://s.team/q/1/42?foo=bar')!;
      expect(withQuery.version).assertEqual(1);
      expect(withQuery.clientId.toString()).assertEqual('42');

      expect(parseSteamQrChallenge('https://steamcommunity.com/openid') === undefined).assertTrue();
      expect(parseSteamQrChallenge('https://s.team/q/abc/1') === undefined).assertTrue();
    });

    it('qr_login_signature_matches_node_crypto', 0, () => {
      expect(qrLoginSignature(SECRET_B64, 2, CLIENT_ID, STEAMID)).assertEqual(QR_SIGNATURE_GOLDEN);
    });

    it('confirmation_signature_matches_node_crypto', 0, () => {
      expect(confirmationSignature(SECRET_B64, 1788953926, 'conf')).assertEqual(CONFIRM_SIGNATURE_GOLDEN);
    });

    it('eresult_mapping_and_error_flags', 0, () => {
      expect(eresultName(29)).assertEqual('DuplicateRequest');
      expect(eresultMessage(5)).assertEqual('账号或密码错误');
      expect(eresultMessage(101)).assertEqual('Steam 要求人机验证，请先在浏览器登录一次该账号');
      expect(eresultMessage(9999)).assertEqual('Steam 返回错误（9999）');

      const dup = new SteamApiError(29, 'AddAuthenticator');
      expect(dup.isDuplicateRequest()).assertTrue();
      expect(dup.isNeedCaptcha()).assertFalse();

      const captcha = new SteamApiError(101, 'BeginAuthSessionViaCredentials');
      expect(captcha.isNeedCaptcha()).assertTrue();

      const phone = new SteamApiError(123, 'RemoveAuthenticatorViaChallengeStart');
      expect(phone.isPhoneRequired()).assertTrue();
    });

    it('session_prefers_device_code_then_email_code', 0, () => {
      const session = new SteamAuthSession();
      session.allowedConfirmations = [
        { confirmationType: EAuthSessionGuardType.EMAIL_CONFIRMATION, associatedMessage: 'a@b.c' },
        { confirmationType: EAuthSessionGuardType.DEVICE_CODE, associatedMessage: '' },
      ];
      expect(session.preferredConfirmation()!.confirmationType)
        .assertEqual(EAuthSessionGuardType.DEVICE_CODE);
      expect(session.requiresCode()).assertTrue();

      const noCode = new SteamAuthSession();
      noCode.allowedConfirmations = [
        { confirmationType: EAuthSessionGuardType.DEVICE_CONFIRMATION, associatedMessage: '' },
      ];
      expect(noCode.requiresCode()).assertFalse();
    });

    it('poll_loop_honors_server_interval_until_authorized', 0, async () => {
      const transport = new FakeTransport();
      // 前两次未授权，第三次返回凭证
      transport.push(okResult(pollBytes('', '', '')));
      transport.push(okResult(pollBytes('', '', '')));
      transport.push(okResult(pollBytes('refresh-abc', 'access-abc', 'testaccount')));

      const sleeper = new FakeSleeper();
      const client = new SteamClient(new SteamTransport(transport), sleeper);

      const session = new SteamAuthSession();
      session.clientId = CLIENT_ID;
      session.requestId = Uint8Array.from([1, 2, 3, 4]);
      session.intervalSeconds = 3;
      session.steamid = STEAMID;

      await client.pollUntilAuthorized(session, 10);

      expect(transport.specs.length).assertEqual(3);
      expect(sleeper.sleeps.length).assertEqual(2);
      expect(sleeper.sleeps[0]).assertEqual(3000);
      expect(session.refreshToken).assertEqual('refresh-abc');
      expect(session.accessToken).assertEqual('access-abc');
      expect(session.accountName).assertEqual('testaccount');
    });

    it('poll_loop_times_out_when_never_authorized', 0, async () => {
      const transport = new FakeTransport();
      for (let i = 0; i < 4; i++) {
        transport.push(okResult(pollBytes('', '', '')));
      }
      const client = new SteamClient(new SteamTransport(transport), new FakeSleeper());
      const session = new SteamAuthSession();
      session.intervalSeconds = 1;

      let threw = false;
      let eresult = 0;
      try {
        await client.pollUntilAuthorized(session, 4);
      } catch (e) {
        threw = true;
        eresult = (e as SteamApiError).eresult;
      }
      expect(threw).assertTrue();
      expect(eresult).assertEqual(16);
      expect(transport.specs.length).assertEqual(4);
    });

    it('add_authenticator_duplicate_request_maps_to_transfer_branch', 0, async () => {
      const transport = new FakeTransport();
      transport.push(errorResult(29));
      const client = new SteamClient(new SteamTransport(transport), new FakeSleeper());

      let duplicate = false;
      try {
        await client.addAuthenticator(STEAMID, 'access-token', 'android:test-device');
      } catch (e) {
        duplicate = (e as SteamApiError).isDuplicateRequest();
      }
      expect(duplicate).assertTrue();
      // 请求体应为 input_protobuf_encoded=...，且 access_token 在 query
      expect(transport.specs[0].body.startsWith('input_protobuf_encoded=')).assertTrue();
      expect(transport.specs[0].url.indexOf('access_token=access-token') > 0).assertTrue();
    });

    it('access_token_is_cached_until_expiry', 0, async () => {
      const transport = new FakeTransport();
      transport.push(okText(`{"response":{"access_token":"${jwtWithExp(2000000000)}"}}`));
      const client = new SteamClient(new SteamTransport(transport), new FakeSleeper());

      const first = await client.generateAccessToken(STEAMID, 'refresh-token', 1788953926);
      const second = await client.generateAccessToken(STEAMID, 'refresh-token', 1788953926);
      expect(first).assertEqual(second);
      // 命中缓存 → 只发一次请求
      expect(transport.specs.length).assertEqual(1);
      // 过期的 token 会重新请求
      transport.push(okText(`{"response":{"access_token":"${jwtWithExp(3000000000)}"}}`));
      await client.generateAccessToken(STEAMID, 'refresh-token', 2000000000);
      expect(transport.specs.length).assertEqual(2);
    });

    it('access_token_cache_is_per_steam_account', 0, async () => {
      // 单例客户端同时服务多个 Steam 账号时，绝不能把 A 的 token 用在 B 上
      const transport = new FakeTransport();
      const otherSteamId = 76561198000000099n;
      transport.push(okText(`{"response":{"access_token":"${jwtWithExp(2000000000)}"}}`));
      transport.push(okText(`{"response":{"access_token":"${jwtWithExp(2000000000)}"}}`));
      const client = new SteamClient(new SteamTransport(transport), new FakeSleeper());

      const tokenA = await client.generateAccessToken(STEAMID, 'refresh-a', 1788953926);
      const tokenB = await client.generateAccessToken(otherSteamId, 'refresh-b', 1788953926);
      expect(tokenA).assertEqual(tokenB);
      // 两个账号各自请求一次
      expect(transport.specs.length).assertEqual(2);
      expect(transport.specs[0].body.indexOf('steamid=76561198000000000') >= 0).assertTrue();
      expect(transport.specs[1].body.indexOf('steamid=76561198000000099') >= 0).assertTrue();
      // 再次请求 A 仍命中 A 的缓存
      await client.generateAccessToken(STEAMID, 'refresh-a', 1788953926);
      expect(transport.specs.length).assertEqual(2);
    });

    it('get_confirmations_parses_list_and_builds_signature_url', 0, async () => {
      const transport = new FakeTransport();
      transport.push(okText('{"success":true,"message":"","conf":['
        + '{"id":"111","nonce":"222","creator_id":"333","type":2,"type_name":"Trade",'
        + '"headline":"You have a new trade offer","summary":["Item A"],"creation_time":1788953000},'
        + '{"id":"444","nonce":"555","type":3,"type_name":"MarketSell","headline":"Sell","summary":[]}'
        + ']}'));
      const client = new SteamClient(new SteamTransport(transport), new FakeSleeper());

      const list: SteamConfirmation[] = await client.getConfirmations(
        STEAMID, 'access-token', SECRET_B64, 'android:device-1', 1788953926);

      expect(list.length).assertEqual(2);
      expect(list[0].id).assertEqual('111');
      expect(list[0].nonce).assertEqual('222');
      expect(list[0].typeName).assertEqual('Trade');
      expect(list[0].summary.length).assertEqual(1);

      const url = transport.specs[0].url;
      expect(url.indexOf('p=android%3Adevice-1') > 0).assertTrue();
      expect(url.indexOf(`a=${STEAMID.toString()}`) > 0).assertTrue();
      expect(url.indexOf('t=1788953926') > 0).assertTrue();
      expect(url.indexOf('tag=conf') > 0).assertTrue();
      expect(url.indexOf('k=') > 0).assertTrue();
      expect(transport.specs[0].headers['Cookie'])
        .assertEqual(`dob=;steamid=${STEAMID.toString()};steamLoginSecure=${STEAMID.toString()}||access-token`);
    });

    it('respond_confirmations_builds_multiajaxop_body', 0, async () => {
      const transport = new FakeTransport();
      transport.push(okText('{}'));
      const client = new SteamClient(new SteamTransport(transport), new FakeSleeper());

      const items: SteamConfirmation[] = [];
      const a = new SteamConfirmation();
      a.id = '111';
      a.nonce = '222';
      const b = new SteamConfirmation();
      b.id = '333';
      b.nonce = '444';
      items.push(a);
      items.push(b);

      await client.respondConfirmations(STEAMID, 'access-token', SECRET_B64, 'android:device-1',
        items, 'allow', 1788953926);

      const body = transport.specs[0].body;
      expect(body.indexOf('op=allow') > 0).assertTrue();
      expect(body.indexOf('cid[]=111') > 0).assertTrue();
      expect(body.indexOf('ck[]=222') > 0).assertTrue();
      expect(body.indexOf('cid[]=333') > 0).assertTrue();
      expect(body.indexOf('ck[]=444') > 0).assertTrue();
    });

    it('get_confirmations_throws_when_success_false', 0, async () => {
      const transport = new FakeTransport();
      transport.push(okText('{"success":false,"message":"Invalid authenticator","conf":[]}'));
      const client = new SteamClient(new SteamTransport(transport), new FakeSleeper());

      let message = '';
      try {
        await client.getConfirmations(STEAMID, 'access-token', SECRET_B64, 'device', 1788953926);
      } catch (e) {
        message = (e as Error).message;
      }
      expect(message.indexOf('Invalid authenticator') > 0).assertTrue();
    });
  });
}
