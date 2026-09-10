import { describe, it, expect } from '@ohos/hypium';
import { HttpRequestSpec, HttpResult, HttpTransport, SteamTransport } from '../main/ets/steam/SteamHttp';
import { base64Decode, base64Encode } from '../main/ets/steam/SteamCrypto';
import { SteamApiError } from '../main/ets/steam/SteamError';

/**
 * HTTP 传输层测试（无网络）。
 *
 * 重点锁定 request 的构造细节——这些细节错了只会在真机上表现为「偶发失败」：
 * - protobuf 请求体必须 percent-encode（base64 的 '+' 在表单里会被当成空格）
 * - access_token 放在 query，而非 body
 * - x-eresult != 1 必须抛 SteamApiError
 * - mobileconf 请求要带 steamLoginSecure Cookie
 */

const PROTO_PREFIX = 'input_protobuf_encoded=';

class CapturingTransport implements HttpTransport {
  specs: HttpRequestSpec[] = [];
  private queue: HttpResult[] = [];

  push(result: HttpResult): void {
    this.queue.push(result);
  }

  send(spec: HttpRequestSpec): Promise<HttpResult> {
    this.specs.push(spec);
    const next: HttpResult | undefined = this.queue.shift();
    return Promise.resolve(next === undefined ? okResult(new Uint8Array(0)) : next);
  }
}

function okResult(bytes: Uint8Array): HttpResult {
  const result = new HttpResult();
  result.statusCode = 200;
  result.headers = { 'x-eresult': '1' };
  result.bytes = bytes;
  return result;
}

function errorResult(eresult: number): HttpResult {
  const result = new HttpResult();
  result.statusCode = 200;
  result.headers = { 'x-eresult': `${eresult}` };
  return result;
}

/** 构造一个 base64 里必然含 '+' 和 '/' 的载荷：0xFB 0xFF → "+/8=" */
function plusSlashPayload(): Uint8Array {
  return Uint8Array.from([0xFB, 0xFF]);
}

export default function steamHttpTest() {
  describe('steamHttpTest', () => {
    it('base64_payload_is_percent_encoded', 0, () => {
      // 先确认该载荷确实会命中问题字符（'+' 在表单里会被解析成空格）
      const raw: string = base64Encode(plusSlashPayload());
      expect(raw).assertEqual('+/8=');

      const transport = new CapturingTransport();
      transport.push(okResult(new Uint8Array(0)));
      const steam = new SteamTransport(transport);

      return steam.postProto('https://example.invalid/api', plusSlashPayload(), '', 'ctx')
        .then(() => {
          const body: string = transport.specs[0].body;
          expect(body).assertEqual(`${PROTO_PREFIX}%2B%2F8%3D`);
          // 解码后必须还原成原始字节
          const encoded: string = body.substring(PROTO_PREFIX.length);
          expect(decodeURIComponent(encoded)).assertEqual('+/8=');
          expect(Array.from(base64Decode(decodeURIComponent(encoded))).join(','))
            .assertEqual('251,255');
        });
    });

    it('access_token_goes_into_query_not_body', 0, () => {
      const transport = new CapturingTransport();
      transport.push(okResult(new Uint8Array(0)));
      const steam = new SteamTransport(transport);

      return steam.postProto('https://example.invalid/api', Uint8Array.from([0x08, 0x01]),
        'tok-123', 'ctx').then(() => {
          const spec = transport.specs[0];
          expect(spec.url).assertEqual('https://example.invalid/api?access_token=tok-123');
          expect(spec.body.indexOf('access_token') >= 0).assertFalse();
          expect(spec.headers['Content-Type']).assertEqual('application/x-www-form-urlencoded');
          expect(spec.headers['Accept-Type']).assertEqual('application/json');
          expect(spec.expectBinary).assertTrue();
        });
    });

    it('empty_proto_body_is_still_well_formed', 0, () => {
      // 迁移第一步 RemoveAuthenticatorViaChallengeStart 发的是空 protobuf
      const transport = new CapturingTransport();
      transport.push(okResult(new Uint8Array(0)));
      const steam = new SteamTransport(transport);

      return steam.postProto('https://example.invalid/start', new Uint8Array(0), 'tok', 'ctx')
        .then(() => {
          expect(transport.specs[0].body).assertEqual(`${PROTO_PREFIX}`);
        });
    });

    it('non_ok_eresult_throws_with_code', 0, () => {
      const transport = new CapturingTransport();
      transport.push(errorResult(84));
      const steam = new SteamTransport(transport);

      let eresult = 0;
      let threw = false;
      return steam.postProto('https://example.invalid/api', Uint8Array.from([0x08, 0x01]), '', 'ctx')
        .then(() => {
          expect(threw).assertTrue();
        })
        .catch((e: Object) => {
          threw = true;
          eresult = (e as SteamApiError).eresult;
          expect(eresult).assertEqual(84);
        });
    });

    it('mobileconf_get_sends_cookie_header', 0, () => {
      const transport = new CapturingTransport();
      const result = new HttpResult();
      result.statusCode = 200;
      result.text = '{"success":true,"conf":[]}';
      transport.push(result);
      const steam = new SteamTransport(transport);

      return steam.getWithCookie('https://steamcommunity.com/mobileconf/getlist?p=x',
        'dob=;steamid=1;steamLoginSecure=1||tok', 'ctx').then((text: string) => {
          expect(text.indexOf('"success":true') > 0).assertTrue();
          expect(transport.specs[0].headers['Cookie'])
            .assertEqual('dob=;steamid=1;steamLoginSecure=1||tok');
          expect(transport.specs[0].method).assertEqual('GET');
        });
    });

    it('post_form_joins_pairs_with_ampersand', 0, () => {
      const transport = new CapturingTransport();
      const result = new HttpResult();
      result.statusCode = 200;
      result.text = '{"response":{"access_token":"x"}}';
      transport.push(result);
      const steam = new SteamTransport(transport);

      return steam.postForm('https://example.invalid/token',
        ['refresh_token=abc', 'steamid=1', 'renewal_type=0'], 'access', 'ctx').then(() => {
          const spec = transport.specs[0];
          expect(spec.body).assertEqual('refresh_token=abc&steamid=1&renewal_type=0');
          expect(spec.url).assertEqual('https://example.invalid/token?access_token=access');
          expect(spec.expectBinary).assertFalse();
        });
    });

    it('missing_eresult_header_with_2xx_is_accepted', 0, () => {
      // GetPasswordRSAPublicKey 这类 JSON 接口不返回 x-eresult
      const transport = new CapturingTransport();
      const result = new HttpResult();
      result.statusCode = 200;
      result.text = '{"response":{"publickey_mod":"aa"}}';
      transport.push(result);
      const steam = new SteamTransport(transport);

      return steam.getJson('https://example.invalid/rsa', 'ctx').then((text: string) => {
        expect(text.indexOf('publickey_mod') > 0).assertTrue();
      });
    });
  });
}
