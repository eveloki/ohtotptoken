/**
 * Steam 消息字段号交叉校验（离线、只读）。
 *
 * 三方对齐：
 *   1. 官方 .proto（.ai/Authenticator-main/.../steamapi/protobufs/*.proto）——权威来源
 *   2. 参考工程生成的 protobufjs 代码（同目录 *.js）——独立第二来源
 *   3. 本项目 ArkTS 手写实现（entry/src/main/ets/steam/proto/SteamMessages.ets）——被校验对象
 *
 * 比对「字段号 + wireType」集合（忽略字段名，因为 ArkTS 侧用 camelCase）。
 *
 * 用法：node scripts/verify-steam-field-numbers.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const REF = '.ai/Authenticator-main/entry/src/main/ets/pages/steamapi';
const PROTO_DIR = path.join(REF, 'protobufs');
const MESSAGES_ETS = 'entry/src/main/ets/steam/proto/SteamMessages.ets';

const PROTO_FILES = [
  'steammessages_auth.steamclient.proto',
  'service_twofactor.proto',
];

/** .proto 标量类型 → protobuf wireType */
function wireTypeOf(protoType) {
  if (protoType === 'string' || protoType === 'bytes') return 2;
  if (protoType === 'fixed64') return 1;
  if (protoType === 'float') return 5;
  if (protoType === 'double') return 1;
  // uint32/uint64/int32/int64/bool/enum(以 . 开头的类型)/嵌套 message(以 . 开头且非枚举)
  if (protoType.startsWith('.')) {
    // 枚举与消息都可能是 varint(0) 或 LEN(2)，需查符号表
    return protoType;
  }
  return 0;
}

// ---------------------------------------------------------------- 1. 解析 .proto

const protoMessages = new Map(); // name -> Map(field -> {id, type})
const enumNames = new Set();

// 枚举可能定义在被解析消息所在文件之外（如 enums.proto），必须全目录扫描
const allProtoFiles = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.proto')) allProtoFiles.push(full);
  }
})(PROTO_DIR);

for (const file of allProtoFiles) {
  const text = fs.readFileSync(file, 'utf8');
  const enumRe = /^\s*enum\s+([A-Za-z0-9_]+)\s*\{/gm;
  let m;
  while ((m = enumRe.exec(text)) !== null) enumNames.add(m[1]);
}

for (const file of PROTO_FILES) {
  const text = fs.readFileSync(path.join(PROTO_DIR, file), 'utf8');
  const msgRe = /^\s*message\s+([A-Za-z0-9_]+)\s*\{/gm;
  const starts = [];
  let m;
  while ((m = msgRe.exec(text)) !== null) starts.push({ name: m[1], index: m.index });
  for (let i = 0; i < starts.length; i++) {
    const end = i + 1 < starts.length ? starts[i + 1].index : text.length;
    const body = text.slice(starts[i].index, end);
    const fields = new Map();
    const fieldRe = /^\s*(?:optional|required|repeated)?\s*([.\w]+)\s+([A-Za-z0-9_]+)\s*=\s*(\d+)/gm;
    let f;
    while ((f = fieldRe.exec(body)) !== null) {
      fields.set(f[2], { id: Number(f[3]), type: f[1] });
    }
    if (fields.size > 0) protoMessages.set(starts[i].name, fields);
  }
}

function expectedPairs(message) {
  const fields = protoMessages.get(message);
  if (!fields) return null;
  const pairs = new Set();
  for (const [name, info] of fields) {
    let wire = wireTypeOf(info.type);
    if (typeof wire !== 'number') {
      const symbol = info.type.slice(1);
      wire = enumNames.has(symbol) ? 0 : 2; // 枚举=varint，嵌套消息=LEN
    }
    pairs.add(`${info.id}/${wire}`);
  }
  return pairs;
}

// ---------------------------------------------------------------- 2. 解析生成的 JS

const jsFiles = fs.readdirSync(REF).filter((f) => f.endsWith('.js'));
const generated = new Map(); // message -> Set("id/wire")

for (const file of jsFiles) {
  const text = fs.readFileSync(path.join(REF, file), 'utf8');
  const fnRe = /^([A-Za-z0-9_]+)\.encode = function encode\(message, writer\)/gm;
  const starts = [];
  let m;
  while ((m = fnRe.exec(text)) !== null) starts.push({ name: m[1], index: m.index });
  // 生成代码在 IIFE 内缩进，正则需允许行首空白
  const fnReIndented = /^\s*([A-Za-z0-9_]+)\.encode = function encode\(message, writer\)/gm;
  while ((m = fnReIndented.exec(text)) !== null) {
    if (!starts.some((s) => s.index === m.index)) starts.push({ name: m[1], index: m.index });
  }
  starts.sort((a, b) => a.index - b.index);
  for (let i = 0; i < starts.length; i++) {
    const end = i + 1 < starts.length ? starts[i + 1].index : text.length;
    const body = text.slice(starts[i].index, end);
    const pairs = new Set();
    const writeRe = /writer\.uint32\(\/\* id (\d+), wireType (\d+) =\*\/\d+\)/g;
    let w;
    while ((w = writeRe.exec(body)) !== null) pairs.add(`${w[1]}/${w[2]}`);
    if (pairs.size > 0 && !generated.has(starts[i].name)) generated.set(starts[i].name, pairs);
  }
}

// ---------------------------------------------------------------- 3. 解析 ArkTS 实现

const ets = fs.readFileSync(MESSAGES_ETS, 'utf8');

/** 我的 writer/reader 方法 → wireType */
const WRITE_WIRE = {
  writeUint32: 0, writeInt32: 0, writeBool: 0, writeUint64: 0,
  writeFixed64: 1, writeString: 2, writeBytes: 2, writeMessage: 2,
};
const READ_WIRE = {
  readUint32: 0, readInt32: 0, readBool: 0, readUint64: 0,
  readFixed64: 1, readString: 2, readBytes: 2, readMessage: 2, readFloat32: 5,
};

function etsPairs(message) {
  // encode(): class X { ... encode(): Uint8Array { ... } }
  const classRe = new RegExp(`export class ${message}\\b[\\s\\S]*?(?=\\nexport class |$)`);
  const classMatch = ets.match(classRe);
  if (!classMatch) return null;
  const body = classMatch[0];

  const encodePairs = new Set();
  const encodeMatch = body.match(/encode\(\): Uint8Array \{[\s\S]*?\n  \}/);
  if (encodeMatch) {
    const re = /w\.(write[A-Za-z0-9]+)\((\d+),/g;
    let m;
    while ((m = re.exec(encodeMatch[0])) !== null) {
      const wire = WRITE_WIRE[m[1]];
      if (wire !== undefined) encodePairs.add(`${m[2]}/${wire}`);
    }
  }

  const decodePairs = new Set();
  const decodeMatch = body.match(/static decode\([\s\S]*?\n  \}/);
  if (decodeMatch) {
    // 逐个 case 提取：case N: ... r.readXxx(
    const caseRe = /case (\d+):([\s\S]*?)(?=case \d+:|default:|\n\s*\})/g;
    let c;
    while ((c = caseRe.exec(decodeMatch[0])) !== null) {
      const reader = c[2].match(/r\.(read[A-Za-z0-9]+)\(/);
      if (!reader) continue;
      const wire = READ_WIRE[reader[1]];
      if (wire !== undefined) decodePairs.add(`${c[1]}/${wire}`);
    }
  }
  return { encodePairs, decodePairs };
}

// ---------------------------------------------------------------- 4. 比对

const TARGETS = [
  'CAuthentication_DeviceDetails',
  'CAuthentication_AllowedConfirmation',
  'CAuthentication_BeginAuthSessionViaCredentials_Request',
  'CAuthentication_BeginAuthSessionViaCredentials_Response',
  'CAuthentication_UpdateAuthSessionWithSteamGuardCode_Request',
  'CAuthentication_PollAuthSessionStatus_Request',
  'CAuthentication_PollAuthSessionStatus_Response',
  'CTwoFactor_AddAuthenticator_Request',
  'CTwoFactor_AddAuthenticator_Response',
  'CTwoFactor_FinalizeAddAuthenticator_Request',
  'CTwoFactor_FinalizeAddAuthenticator_Response',
  'CTwoFactor_Status_Request',
  'CTwoFactor_Status_Response',
  'CTwoFactor_RemoveAuthenticator_Request',
  'CTwoFactor_RemoveAuthenticator_Response',
  'CTwoFactor_RemoveAuthenticatorViaChallengeStart_Response',
  'CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request',
  'CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response',
  'CRemoveAuthenticatorViaChallengeContinue_Replacement_Token',
];

const show = (set) => [...set].sort((a, b) => Number(a.split('/')[0]) - Number(b.split('/')[0])).join(' ');
let failures = 0;

for (const message of TARGETS) {
  const proto = expectedPairs(message);
  const gen = generated.get(message) ?? null;
  const mine = etsPairs(message);
  const lines = [`### ${message}`];
  lines.push(`  proto     : ${proto ? show(proto) : '(not found)'}`);
  lines.push(`  generated : ${gen ? show(gen) : '(not found)'}`);
  if (mine) {
    lines.push(`  encode    : ${show(mine.encodePairs)}`);
    lines.push(`  decode    : ${show(mine.decodePairs)}`);
  } else {
    lines.push('  ArkTS     : (class not found)');
  }

  // 校验 1：proto vs generated（独立第二来源自洽性）
  if (proto && gen) {
    const missing = [...proto].filter((p) => !gen.has(p));
    if (missing.length) {
      lines.push(`  !! proto 与 generated 不一致: ${missing.join(' ')}`);
      failures++;
    }
  }
  // 校验 2：我的实现 vs proto（只比较我实际使用到的字段子集）
  if (proto && mine) {
    const used = mine.encodePairs.size > 0 ? mine.encodePairs : mine.decodePairs;
    const wrong = [...used].filter((p) => !proto.has(p));
    if (wrong.length) {
      lines.push(`  !! ArkTS 字段号/wireType 不在 proto 中: ${wrong.join(' ')}`);
      failures++;
    }
    if (used.size > 0) {
      lines.push(`  ok: ArkTS 使用 ${used.size} 个字段，全部命中官方定义`);
    }
  }
  console.log(lines.join('\n'));
}

console.log(`\n${failures === 0 ? 'PASS' : 'FAIL'} — ${failures} 处不一致`);
process.exit(failures === 0 ? 0 : 1);
