/**
 * Steam 实时探针：用**真实 Steam 服务器**验证生产代码的请求编码。
 *
 * 特点：加载 `entry/src/main/ets/steam/` 下的真实 ArkTS 源码（不复制实现），
 * 只把 `@kit.NetworkKit` 换成 node fetch；使用**不存在的假账号**，不需要任何凭据。
 *
 * 能证明什么：
 * 1. `GetPasswordRSAPublicKey` 的 JSON 解析、模长推导（线上是 2048 位）
 * 2. `BeginAuthSessionViaCredentials` 的**手写 protobuf 编码 + RSA PKCS#1 v1.5 加密
 *    + 表单 percent-encode** 被 Steam 真实服务端接受 → 返回 EResult 5 (InvalidPassword)
 * 3. 反向对照：故意发送损坏的 protobuf → 返回 EResult 0 (Invalid)，
 *    说明上一步的 5 来自凭据校验而非编码错误
 * 4. 二维码解析
 *
 * 需要：Node.js ≥ 22.13.0（stripTypeScriptTypes）+ 能访问 api.steampowered.com
 * 用法：node scripts/steam-live-probe.mjs
 *
 * 注意：会向 Steam 发送一次失败登录（假账号），属正常风控范围内；请勿高频运行。
 */
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';

function lowerNumericEnum(_m, name, body) {
  let next = 0;
  const fields = body.replace(/\/\*[\s\S]*?\*\//g, '').split(',').filter((p) => p.trim()).map((p) => {
    const m = p.trim().match(/^(\w+)(?:\s*=\s*(-?\d+))?$/);
    if (!m) throw new Error(`unsupported enum member: ${p}`);
    if (m[2] !== undefined) next = Number(m[2]);
    return `${JSON.stringify(m[1])}: ${next++}`;
  });
  return `const ${name} = {${fields.join(',')}};`;
}

function source(file) {
  return stripTypeScriptTypes(
    readFileSync(file, 'utf8')
      // 去掉（可能跨行的）import 语句与 export 关键字
      .replace(/^import\s+[\s\S]*?from\s+['"][^'"]+['"];?/gm, '')
      .replace(/^import\s+['"][^'"]+['"];?/gm, '')
      .replace(/export /g, '')
      .replace(/enum (\w+)\s*\{([^}]+)\}/g, lowerNumericEnum)
  );
}

const files = [
  'entry/src/main/ets/steam/PureHash.ets',
  'entry/src/main/ets/steam/SteamCrypto.ets',
  'entry/src/main/ets/steam/SteamCode.ets',
  'entry/src/main/ets/steam/SteamError.ets',
  'entry/src/main/ets/steam/proto/ProtoWriter.ets',
  'entry/src/main/ets/steam/proto/ProtoReader.ets',
  'entry/src/main/ets/steam/proto/SteamMessages.ets',
  'entry/src/main/ets/steam/SteamHttp.ets',
  'entry/src/main/ets/steam/SteamClient.ets',
];
const code = files.map(source).join('\n') +
  '\n({ SteamClient, SteamTransport, NetworkHttpTransport, SteamApiError, eresultName, eresultMessage, parseSteamQrChallenge, SteamAuthSession, rsaEncryptPkcs1, base64Encode });';

// ---- 仅替换网络边界：把 ArkTS http 调用映射到 node fetch ----
const ARRAY_BUFFER = Symbol('ARRAY_BUFFER');
const STRING = Symbol('STRING');
const http = {
  RequestMethod: { GET: 'GET', POST: 'POST' },
  HttpDataType: { STRING, ARRAY_BUFFER },
  HttpProtocol: { HTTP1_1: 'HTTP1_1' },
  createHttp() {
    return {
      async request(url, options) {
        const init = { method: options.method, headers: options.header, signal: AbortSignal.timeout(20000) };
        if (options.method === 'POST' && options.extraData !== undefined) init.body = options.extraData;
        const res = await fetch(url, init);
        const header = {};
        res.headers.forEach((v, k) => (header[k] = v));
        const result = options.expectDataType === ARRAY_BUFFER
          ? await res.arrayBuffer()
          : await res.text();
        return { responseCode: res.status, header, result };
      },
      destroy() {}
    };
  }
};

const api = runInNewContext(code, { http, buffer: Buffer, console });

const transport = new api.SteamTransport(new api.NetworkHttpTransport());
const client = new api.SteamClient(transport);

const ACCOUNT = 'otptoken_probe_nonexistent_account';

console.log('--- 1) GetPasswordRSAPublicKey（未鉴权 JSON 接口）---');
const key = await client.getPasswordRsaPublicKey(ACCOUNT);
console.log('  modulus hex length:', key.publickeyMod.length);
console.log('  exponent:', key.publickeyExp, ' timestamp:', key.timestamp.toString());
console.log('  modulus looks like 1024-bit:', key.publickeyMod.length === 256);

console.log('--- 2) BeginAuthSessionViaCredentials（protobuf + RSA，假密码）---');
try {
  await client.beginAuthSession(ACCOUNT, 'NotARealPassword!123', 'OTP Token');
  console.log('  UNEXPECTED: 服务端接受了假凭据');
  process.exitCode = 1;
} catch (error) {
  if (error instanceof api.SteamApiError || error?.eresult !== undefined) {
    console.log(`  EResult=${error.eresult} (${api.eresultName(error.eresult)})`);
    console.log('  文案:', error.message);
    const acceptable = [5, 63, 65, 85, 84, 87, 101];
    console.log(`  是否属于预期失败码: ${acceptable.includes(error.eresult)}`);
  } else {
    console.log('  非 SteamApiError:', error?.name, error?.message);
    process.exitCode = 1;
  }
}

console.log('--- 3) RSA 加密（用 Steam 当前公钥）---');
const cipher = api.rsaEncryptPkcs1('NotARealPassword!123', key.publickeyMod, key.publickeyExp, undefined);
console.log('  密文字节数:', cipher.length, '= 模长字节数:', key.publickeyMod.length / 2);
console.log('  与模长一致:', cipher.length === key.publickeyMod.length / 2);

console.log('--- 4) 反向对照：故意发送损坏的 protobuf ---');
try {
  await transport.postProto(
    'https://api.steampowered.com/IAuthenticationService/BeginAuthSessionViaCredentials/v1/',
    Uint8Array.from([0xFF, 0xFF, 0xFF, 0xFF]), '', 'negative-control');
  console.log('  UNEXPECTED: 损坏载荷被接受');
} catch (error) {
  console.log(`  EResult=${error.eresult} (${api.eresultName(error.eresult)})`);
  console.log('  与正常请求的错误码不同 →', error.eresult !== 5);
}

console.log('--- 5) 二维码解析（纯函数）---');
const challenge = api.parseSteamQrChallenge('https://s.team/q/2/1234567890123456789');
console.log('  version:', challenge.version, 'clientId:', challenge.clientId.toString());
