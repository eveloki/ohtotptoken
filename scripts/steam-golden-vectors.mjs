/**
 * Steam 黄金向量生成器（离线交叉验证用）。
 *
 * 作用：用 **真实 protobufjs + node:crypto**（独立实现）对同一批 Steam 消息/签名/加密
 * 产出期望值，用于验证 `entry/src/main/ets/steam/proto/*` 的 ArkTS 手写编解码器
 * 与 `SteamCrypto`/`SteamCode` 的实现是否与业界一致。
 *
 * 依赖：protobufjs 7（仅本脚本需要，未列入工程依赖）
 *   npm i --no-save protobufjs@7.4.0
 *
 * 用法：
 *   node scripts/steam-golden-vectors.mjs
 * 然后把输出中的值同步到：
 *   - entry/src/test/SteamMessages.test.ets 的 GOLDEN 常量（proto 字节）
 *   - entry/src/test/SteamCrypto.test.ets   的 SECRET/签名/RSA 常量
 *   - entry/src/test/SteamClient.test.ets   的签名期望值
 *
 * 注意：RSA 部分每次运行都会新生成密钥对，因此「密文/RSA 公钥」常量必须与
 * 测试文件里的值成对更新，否则 rsa_pkcs1_v15_matches_node_crypto_byte_for_byte 会失败。
 */
import protobuf from 'protobufjs';
import Long from 'long';

const proto = `
syntax = "proto2";
message DeviceDetails {
  optional string device_friendly_name = 1;
  optional int32 platform_type = 2;
  optional int32 os_type = 3;
  optional uint32 gaming_device_type = 4;
}
message BeginAuth {
  optional string device_friendly_name = 1;
  optional string account_name = 2;
  optional string encrypted_password = 3;
  optional uint64 encryption_timestamp = 4;
  optional bool remember_login = 5;
  optional int32 platform_type = 6;
  optional int32 persistence = 7;
  optional string website_id = 8;
  optional DeviceDetails device_details = 9;
  optional string guard_data = 10;
  optional uint32 language = 11;
  optional int32 qos_level = 12;
}
message UpdateGuardCode {
  optional uint64 client_id = 1;
  optional fixed64 steamid = 2;
  optional string code = 3;
  optional int32 code_type = 4;
}
message PollStatus {
  optional uint64 client_id = 1;
  optional bytes request_id = 2;
  optional fixed64 token_to_revoke = 3;
}
message AddAuthenticator {
  optional fixed64 steamid = 1;
  optional uint64 authenticator_time = 2;
  optional fixed64 serial_number = 3;
  optional uint32 authenticator_type = 4;
  optional string device_identifier = 5;
  optional string sms_phone_id = 6;
  repeated string http_headers = 7;
  optional uint32 version = 8;
}
message FinalizeAddAuthenticator {
  optional fixed64 steamid = 1;
  optional string authenticator_code = 2;
  optional uint64 authenticator_time = 3;
  optional string activation_code = 4;
  repeated string http_headers = 5;
  optional bool validate_sms_code = 6;
}
message RemoveAuthenticator {
  optional string revocation_code = 2;
  optional uint32 revocation_reason = 5;
  optional uint32 steamguard_scheme = 6;
  optional bool remove_all_steamguard_cookies = 7;
}
message ChallengeContinue {
  optional string sms_code = 1;
  optional bool generate_new_token = 2;
  optional uint32 version = 3;
}
message AllowedConfirmation {
  optional int32 confirmation_type = 1;
  optional string associated_message = 2;
}
message BeginAuthResponse {
  optional uint64 client_id = 1;
  optional bytes request_id = 2;
  optional float interval = 3;
  repeated AllowedConfirmation allowed_confirmations = 4;
  optional uint64 steamid = 5;
  optional string weak_token = 6;
  optional string agreement_session_url = 7;
  optional string extended_error_message = 8;
}
message PollResponse {
  optional uint64 new_client_id = 1;
  optional string refresh_token = 3;
  optional string access_token = 4;
  optional bool had_remote_interaction = 5;
  optional string account_name = 6;
  optional string new_guard_data = 7;
}
message AddAuthenticatorResponse {
  optional bytes shared_secret = 1;
  optional fixed64 serial_number = 2;
  optional string revocation_code = 3;
  optional string uri = 4;
  optional uint64 server_time = 5;
  optional string account_name = 6;
  optional string token_gid = 7;
  optional bytes identity_secret = 8;
  optional bytes secret_1 = 9;
  optional int32 status = 10;
  optional string phone_number_hint = 11;
  optional int32 confirm_type = 12;
}
message FinalizeResponse {
  optional bool success = 1;
  optional bool want_more = 2;
  optional uint64 server_time = 3;
  optional int32 status = 4;
}
message ReplacementToken {
  optional bytes shared_secret = 1;
  optional fixed64 serial_number = 2;
  optional string revocation_code = 3;
  optional string uri = 4;
  optional uint64 server_time = 5;
  optional string account_name = 6;
  optional string token_gid = 7;
  optional bytes identity_secret = 8;
  optional bytes secret_1 = 9;
  optional int32 status = 10;
  optional uint32 steamguard_scheme = 11;
  optional fixed64 steamid = 12;
}
message ChallengeContinueResponse {
  optional bool success = 1;
  optional ReplacementToken replacement_token = 2;
}
message RemoveAuthenticatorResponse {
  optional bool success = 1;
  optional uint64 server_time = 3;
  optional uint32 revocation_attempts_remaining = 5;
}
`;

const root = protobuf.parse(proto, { keepCase: true }).root;
const T = (name) => root.lookupType(name);
const hex = (u8) => Array.from(u8).map((b) => b.toString(16).padStart(2, '0')).join('');

const STEAMID = '76561198000000000';
const CLIENT_ID = '1234567890123456789';

const out = {};

// 与 ArkTS CAuthentication_BeginAuthSessionViaCredentials_Request.encode() 同字段集：2,3,4,7,9,11,12
out.beginAuth = hex(T('BeginAuth').encode({
  account_name: 'testaccount',
  encrypted_password: 'QUJDREVGRw==',
  encryption_timestamp: Long.fromString('1788953926'),
  persistence: 1,
  device_details: {
    device_friendly_name: 'Authenticator',
    platform_type: 3,
    os_type: -500,
    gaming_device_type: 528,
  },
  language: 0,
  qos_level: 2,
}).finish());

out.updateGuardCode = hex(T('UpdateGuardCode').encode({
  client_id: Long.fromString(CLIENT_ID),
  steamid: Long.fromString(STEAMID),
  code: 'ABC12',
  code_type: 3,
}).finish());

out.pollStatus = hex(T('PollStatus').encode({
  client_id: Long.fromString(CLIENT_ID),
  request_id: Uint8Array.from([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
}).finish());

out.addAuthenticator = hex(T('AddAuthenticator').encode({
  steamid: Long.fromString(STEAMID),
  authenticator_type: 1,
  device_identifier: 'android:11111111-2222-3333-4444-555555555555',
  sms_phone_id: '1',
  version: 1,
}).finish());

out.finalizeAddAuthenticator = hex(T('FinalizeAddAuthenticator').encode({
  steamid: Long.fromString(STEAMID),
  authenticator_code: 'XYZ12',
  authenticator_time: Long.fromString('1788953926'),
  activation_code: '54321',
  validate_sms_code: true,
}).finish());

out.removeAuthenticator = hex(T('RemoveAuthenticator').encode({
  revocation_code: 'R12345',
  revocation_reason: 0,
  steamguard_scheme: 1,
  remove_all_steamguard_cookies: false,
}).finish());

out.challengeContinue = hex(T('ChallengeContinue').encode({
  sms_code: '12345',
  generate_new_token: true,
  version: 1,
}).finish());

// ---- 响应侧：由 protobufjs 编码，交给 ArkTS 解码器验证 ----
const SECRET = Uint8Array.from([0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]);
const IDENTITY = Uint8Array.from([0xfe, 0xdc, 0xba, 0x98]);

out.beginAuthResponse = hex(T('BeginAuthResponse').encode({
  client_id: Long.fromString(CLIENT_ID),
  request_id: Uint8Array.from([0xde, 0xad, 0xbe, 0xef, 0x00, 0x11, 0x22, 0x33]),
  interval: 5.0,
  allowed_confirmations: [
    { confirmation_type: 3, associated_message: '' },
    { confirmation_type: 4, associated_message: 'a***z@example.com' },
  ],
  steamid: Long.fromString(STEAMID),
  weak_token: 'weak-token-value',
  agreement_session_url: '',
  extended_error_message: '',
}).finish());

out.pollResponse = hex(T('PollResponse').encode({
  new_client_id: Long.fromString(CLIENT_ID),
  refresh_token: 'eyJhbGciOiJIUzI1NiJ9.refresh.payload',
  access_token: 'eyJhbGciOiJIUzI1NiJ9.access.payload',
  had_remote_interaction: true,
  account_name: 'testaccount',
  new_guard_data: 'guard-data',
}).finish());

out.addAuthenticatorResponse = hex(T('AddAuthenticatorResponse').encode({
  shared_secret: SECRET,
  serial_number: Long.fromString(CLIENT_ID),
  revocation_code: 'R12345',
  uri: 'otpauth://totp/Steam:testaccount?secret=ABCDEFGHIJKLMNOP&issuer=Steam',
  server_time: Long.fromString('1788953926'),
  account_name: 'testaccount',
  token_gid: 'gid123',
  identity_secret: IDENTITY,
  secret_1: Uint8Array.from([0x11, 0x22]),
  status: 2,
  phone_number_hint: '***1234',
  confirm_type: 1,
}).finish());

out.finalizeResponse = hex(T('FinalizeResponse').encode({
  success: false,
  want_more: true,
  server_time: Long.fromString('1788953926'),
  status: 88,
}).finish());

out.challengeContinueResponse = hex(T('ChallengeContinueResponse').encode({
  success: true,
  replacement_token: {
    shared_secret: SECRET,
    serial_number: Long.fromString(CLIENT_ID),
    revocation_code: 'R99999',
    uri: 'otpauth://totp/Steam:testaccount?secret=ABCDEFGHIJKLMNOP&issuer=Steam',
    server_time: Long.fromString('1788953999'),
    account_name: 'testaccount',
    token_gid: 'gid999',
    identity_secret: IDENTITY,
    secret_1: Uint8Array.from([0x33, 0x44]),
    status: 2,
    steamguard_scheme: 2,
    steamid: Long.fromString(STEAMID),
  },
}).finish());

out.removeAuthenticatorResponse = hex(T('RemoveAuthenticatorResponse').encode({
  success: true,
  server_time: Long.fromString('1788954000'),
  revocation_attempts_remaining: 4,
}).finish());

console.log(JSON.stringify(out, null, 2));

// ---- 加密/编码向量：用 node:crypto 独立实现产出 ----
import crypto from 'node:crypto';

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const STEAM_ALPHABET = '23456789BCDFGHJKMNPQRTVWXY';

function steamCode(secretB64, unix) {
  const key = Buffer.from(secretB64, 'base64');
  const counter = Math.floor(unix / 30);
  const msg = Buffer.alloc(8);
  msg.writeBigUInt64BE(BigInt(counter));
  const mac = crypto.createHmac('sha1', key).update(msg).digest();
  const off = mac[mac.length - 1] & 0x0f;
  const value = ((mac[off] & 0x7f) << 24) | (mac[off + 1] << 16) | (mac[off + 2] << 8) | mac[off + 3];
  let v = value;
  let code = '';
  for (let i = 0; i < 5; i++) {
    code += STEAM_ALPHABET[v % 26];
    v = Math.floor(v / 26);
  }
  return code;
}

const SECRET_B64 = 'MDEyMzQ1Njc4OWFiY2RlZg=='; // bytes: 0123456789abcdef
const cryptoVectors = {
  base64: {
    empty: Buffer.from('').toString('base64'),
    f: Buffer.from('f').toString('base64'),
    fo: Buffer.from('fo').toString('base64'),
    foo: Buffer.from('foo').toString('base64'),
    foob: Buffer.from('foob').toString('base64'),
    fooba: Buffer.from('fooba').toString('base64'),
    foobar: Buffer.from('foobar').toString('base64'),
    binary: Buffer.from([0x00, 0xff, 0x10, 0x80, 0x7f]).toString('base64'),
  },
  hmacSha1: crypto.createHmac('sha1', Buffer.from(SECRET_B64, 'base64')).update(Buffer.from('conf')).digest('base64'),
  hmacSha256: crypto.createHmac('sha256', Buffer.from(SECRET_B64, 'base64')).update(Buffer.from('payload')).digest('base64'),
  steamCodes: {
    t1788953926: steamCode(SECRET_B64, 1788953926),
    t0: steamCode(SECRET_B64, 0),
    t30: steamCode(SECRET_B64, 30),
    t59: steamCode(SECRET_B64, 59),
    t1234567890: steamCode(SECRET_B64, 1234567890),
  },
  // RSA-1024 测试公钥（node 现场生成，仅用于验证加密路径可跑通）
  rsaModHex: '',
  rsaExpHex: '',
};

const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 1024 });
const jwk = publicKey.export({ format: 'jwk' });
cryptoVectors.rsaModHex = Buffer.from(jwk.n, 'base64url').toString('hex');
cryptoVectors.rsaExpHex = Buffer.from(jwk.e, 'base64url').toString('hex');

// 固定 padding 的 RSA PKCS#1 v1.5 加密向量（便于 ArkTS 侧逐字节对照）
const RSA_PASSWORD = 'hunter2';
const k = Buffer.from(jwk.n, 'base64url').length; // 128
const psLen = k - 3 - Buffer.byteLength(RSA_PASSWORD);
const ps = Buffer.alloc(psLen);
for (let i = 0; i < psLen; i++) ps[i] = (i % 255) + 1; // 全非零
const em = Buffer.concat([
  Buffer.from([0x00, 0x02]),
  ps,
  Buffer.from([0x00]),
  Buffer.from(RSA_PASSWORD, 'utf8'),
]);
const mod = BigInt('0x' + cryptoVectors.rsaModHex);
const exp = BigInt('0x' + cryptoVectors.rsaExpHex);
let base = BigInt('0x' + em.toString('hex'));
let acc = 1n;
let e = exp;
while (e > 0n) {
  if (e & 1n) acc = (acc * base) % mod;
  base = (base * base) % mod;
  e >>= 1n;
}
const ctHex = acc.toString(16).padStart(k * 2, '0');
// 用 node 私钥独立验证密文确实能解出原密码
const decrypted = crypto.privateDecrypt(
  { key: privateKey, padding: crypto.constants.RSA_PKCS1_PADDING },
  Buffer.from(ctHex, 'hex'),
);
cryptoVectors.rsa = {
  password: RSA_PASSWORD,
  paddingHex: ps.toString('hex'),
  ciphertextHex: ctHex,
  nodeDecryptOk: decrypted.toString('utf8') === RSA_PASSWORD,
};

cryptoVectors.sha1abc = crypto.createHash('sha1').update('abc').digest('hex');
cryptoVectors.sha256abc = crypto.createHash('sha256').update('abc').digest('hex');
cryptoVectors.sha1empty = crypto.createHash('sha1').update('').digest('hex');
cryptoVectors.sha256empty = crypto.createHash('sha256').update('').digest('hex');

// ---- Steam 签名向量（扫码登录 HMAC-SHA256 / 交易确认 HMAC-SHA1） ----
const SIG_STEAMID = 76561198000000000n;
const SIG_CLIENT_ID = 1234567890123456789n;
const QR_VERSION = 2;

function leBytes(value, count) {
  const out = Buffer.alloc(count);
  let v = BigInt(value);
  for (let i = 0; i < count; i++) { out[i] = Number(v & 0xffn); v >>= 8n; }
  return out;
}
function beBytes(value, count) {
  const out = Buffer.alloc(count);
  let v = BigInt(value);
  for (let i = count - 1; i >= 0; i--) { out[i] = Number(v & 0xffn); v >>= 8n; }
  return out;
}

const qrMsg = Buffer.concat([leBytes(QR_VERSION, 2), leBytes(SIG_CLIENT_ID, 8), leBytes(SIG_STEAMID, 8)]);
cryptoVectors.qrSignature = encodeURIComponent(
  crypto.createHmac('sha256', Buffer.from(SECRET_B64, 'base64')).update(qrMsg).digest('base64'));

const confMsg = Buffer.concat([beBytes(1788953926, 8), Buffer.from('conf')]);
cryptoVectors.confirmSignature = encodeURIComponent(
  crypto.createHmac('sha1', Buffer.from(SECRET_B64, 'base64')).update(confMsg).digest('base64'));

cryptoVectors.signatureInputs = {
  secret: SECRET_B64,
  steamid: SIG_STEAMID.toString(),
  clientId: SIG_CLIENT_ID.toString(),
  version: QR_VERSION,
  confirmSeconds: 1788953926,
};

console.log(JSON.stringify(cryptoVectors, null, 2));
