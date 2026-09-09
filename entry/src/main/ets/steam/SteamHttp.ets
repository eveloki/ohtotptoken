/**
 * Steam HTTP 传输层。
 *
 * 设计：把「IO」与「协议」分离——
 * - `HttpTransport` 是唯一与 @kit.NetworkKit 耦合的接口，测试可注入假实现
 * - `SteamTransport` 负责 Steam 特有的封装：form-urlencoded 请求体、
 *   `input_protobuf_encoded=<base64>` 编码、`x-eresult` 响应头解析、protobuf 解码
 *
 * 参考实现的错误处理缺口已在此修正：
 * - 只调用一次 poll、忽略服务端返回的 `interval`
 * - 未校验空 refresh_token
 * - 把 access_token 放 URL query（我们沿用官方做法，但集中在一处，便于审计）
 */

import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ProtoWriter } from 'common';
import { base64Encode } from './SteamCrypto';
import { ERESULT_OK, SteamApiError } from './SteamError';

/** 单次请求描述 */
export class HttpRequestSpec {
  url: string = '';
  method: string = 'POST';
  headers: Record<string, string> = {};
  body: string = '';
  /** 响应体按二进制读取（protobuf 接口），否则按文本 */
  expectBinary: boolean = false;
}

/** 单次响应 */
export class HttpResult {
  statusCode: number = 0;
  headers: Record<string, string> = {};
  text: string = '';
  bytes: Uint8Array = new Uint8Array(0);
}

/** 可注入的传输接口（测试用假实现替换真实网络） */
export interface HttpTransport {
  send(spec: HttpRequestSpec): Promise<HttpResult>;
}

function headerValue(headers: Record<string, string>, name: string): string {
  const raw: string | undefined = headers[name];
  if (raw === undefined || raw === null) {
    return '';
  }
  return raw;
}

function normalizeHeaders(raw: Object | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  if (raw === undefined || raw === null) {
    return out;
  }
  const map: Record<string, Object> = raw as Record<string, Object>;
  const keys: string[] = Object.keys(map);
  for (let i = 0; i < keys.length; i++) {
    const key: string = keys[i];
    out[key.toLowerCase()] = String(map[key]);
  }
  return out;
}

/** 基于 @kit.NetworkKit 的真实实现 */
export class NetworkHttpTransport implements HttpTransport {
  private connectTimeout: number = 15000;
  private readTimeout: number = 30000;

  async send(spec: HttpRequestSpec): Promise<HttpResult> {
    const request: http.HttpRequest = http.createHttp();
    const result: HttpResult = new HttpResult();
    try {
      const options: http.HttpRequestOptions = {
        method: spec.method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: spec.headers,
        extraData: spec.body,
        expectDataType: spec.expectBinary ? http.HttpDataType.ARRAY_BUFFER : http.HttpDataType.STRING,
        connectTimeout: this.connectTimeout,
        readTimeout: this.readTimeout,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        usingProxy: false,
      };
      const response: http.HttpResponse = await request.request(spec.url, options);
      result.statusCode = response.responseCode;
      result.headers = normalizeHeaders(response.header);
      if (spec.expectBinary && response.result instanceof ArrayBuffer) {
        result.bytes = new Uint8Array(response.result as ArrayBuffer);
      } else {
        result.text = response.result === undefined || response.result === null ? '' : String(response.result);
      }
      return result;
    } finally {
      request.destroy();
    }
  }
}

/** Steam 协议封装 */
export class SteamTransport {
  private transport: HttpTransport;

  constructor(transport: HttpTransport) {
    this.transport = transport;
  }

  /** 组装 form-urlencoded 请求体（不做 URL 编码，与官方客户端一致） */
  static formBody(pairs: string[]): string {
    return pairs.join('&');
  }

  /** 响应体摘要（用于错误诊断）：文本截断或二进制 hex 预览 */
  private static bodyPreview(result: HttpResult): string {
    if (result.text.length > 0) {
      return result.text.length > 160 ? `${result.text.substring(0, 160)}…` : result.text;
    }
    if (result.bytes.length > 0) {
      let hex: string = '';
      const max: number = Math.min(result.bytes.length, 64);
      for (let i = 0; i < max; i++) {
        hex += result.bytes[i].toString(16).padStart(2, '0');
      }
      return `hex(${result.bytes.length}B): ${hex}${result.bytes.length > max ? '…' : ''}`;
    }
    return '';
  }

  /** 校验 `x-eresult`，非 1 抛 SteamApiError（附带响应体摘要） */
  private static assertOk(result: HttpResult, context: string): void {
    const raw: string = headerValue(result.headers, 'x-eresult');
    if (raw === '') {
      // 少数 JSON 接口（如 GetPasswordRSAPublicKey）不返回该头
      if (result.statusCode >= 200 && result.statusCode < 300) {
        return;
      }
      throw new SteamApiError(0, `${context} HTTP ${result.statusCode}`,
        SteamTransport.bodyPreview(result));
    }
    const code: number = Number.parseInt(raw, 10);
    if (code !== ERESULT_OK) {
      throw new SteamApiError(Number.isNaN(code) ? 0 : code, context,
        SteamTransport.bodyPreview(result));
    }
  }

  /** GET JSON（GetPasswordRSAPublicKey 等 WebAPI） */
  async getJson(url: string, context: string): Promise<string> {
    const spec = new HttpRequestSpec();
    spec.url = url;
    spec.method = 'GET';
    spec.expectBinary = false;
    const result: HttpResult = await this.transport.send(spec);
    SteamTransport.assertOk(result, context);
    return result.text;
  }

  /** POST form（GenerateAccessTokenForApp 等 WebAPI） */
  async postForm(url: string, pairs: string[], accessToken: string, context: string): Promise<string> {
    const spec = new HttpRequestSpec();
    spec.url = accessToken.length > 0 ? `${url}?access_token=${accessToken}` : url;
    spec.method = 'POST';
    const headers: Record<string, string> = { 'Content-Type': 'application/x-www-form-urlencoded' };
    spec.headers = headers;
    spec.body = SteamTransport.formBody(pairs);
    spec.expectBinary = false;
    const result: HttpResult = await this.transport.send(spec);
    SteamTransport.assertOk(result, context);
    return result.text;
  }

  /** POST protobuf（IAuthenticationService / ITwoFactorService） */
  async postProto(url: string, payload: Uint8Array, accessToken: string, context: string): Promise<Uint8Array> {
    const spec = new HttpRequestSpec();
    spec.url = accessToken.length > 0 ? `${url}?access_token=${accessToken}` : url;
    spec.method = 'POST';
    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept-Type': 'application/json',
    };
    spec.headers = headers;
    // 必须 percent-encode：base64 里的 '+' 在 x-www-form-urlencoded 中会被解析为空格，
    // 导致 Steam 侧 protobuf 解析失败（且只在载荷恰好含 '+' 时复现，极难排查）。
    spec.body = `input_protobuf_encoded=${encodeURIComponent(base64Encode(payload))}`;
    spec.expectBinary = true;
    const result: HttpResult = await this.transport.send(spec);
    SteamTransport.assertOk(result, context);
    return result.bytes;
  }

  /** GET（steamcommunity mobileconf，带 Cookie） */
  async getWithCookie(url: string, cookie: string, context: string): Promise<string> {
    const spec = new HttpRequestSpec();
    spec.url = url;
    spec.method = 'GET';
    const headers: Record<string, string> = {};
    headers['Cookie'] = cookie;
    spec.headers = headers;
    spec.expectBinary = false;
    const result: HttpResult = await this.transport.send(spec);
    SteamTransport.assertOk(result, context);
    return result.text;
  }

  /** POST 表单（mobileconf multiajaxop） */
  async postWithCookie(url: string, pairs: string[], cookie: string, context: string): Promise<string> {
    const spec = new HttpRequestSpec();
    spec.url = url;
    spec.method = 'POST';
    const headers: Record<string, string> = {};
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    headers['Cookie'] = cookie;
    spec.headers = headers;
    spec.body = SteamTransport.formBody(pairs);
    spec.expectBinary = false;
    const result: HttpResult = await this.transport.send(spec);
    SteamTransport.assertOk(result, context);
    return result.text;
  }
}
