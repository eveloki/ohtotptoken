/**
 * Steam 消息字段号「来源解析」共用库。
 *
 * 三个来源：
 *   1. 官方 .proto（参考工程内副本）—— 权威定义
 *   2. 参考工程生成的 protobufjs 代码（独立第二来源）
 *   3. 本项目 ArkTS 手写实现（被校验对象）
 *
 * 参考工程目录（`.ai/`）不进仓库（见 .gitignore），因此：
 *   - `generate-steam-field-manifest.mjs` 在**有参考目录**时用它生成快照 manifest；
 *   - `verify-steam-field-numbers.mjs` 默认只依赖仓库内 manifest，
 *     参考目录存在时再额外做一次「manifest 是否过期」的活体校验。
 *
 * 比对集合为「字段号 + wireType」（忽略字段名：ArkTS 侧用 camelCase）。
 */
import fs from 'node:fs';
import path from 'node:path';

/** 默认参考工程目录（可用环境变量 STEAM_PROTO_REF 覆盖） */
export const DEFAULT_REF = '.ai/Authenticator-main/entry/src/main/ets/pages/steamapi';

/** 需要交叉校验的消息（与 SteamMessages.ets 中实际使用的字段一一对应） */
export const TARGET_MESSAGES = [
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

export const PROTO_FILES = [
  'steammessages_auth.steamclient.proto',
  'service_twofactor.proto',
];

/** .proto 标量类型 → protobuf wireType；符号类型（枚举/嵌套消息）返回原字符串待查表 */
export function wireTypeOf(protoType) {
  if (protoType === 'string' || protoType === 'bytes') return 2;
  if (protoType === 'fixed64' || protoType === 'double') return 1;
  if (protoType === 'float') return 5;
  if (protoType.startsWith('.')) return protoType;
  return 0;
}

/** 排序后的稳定表示：`1/0 2/2 3/2 …` */
export function showSet(set) {
  return [...set].sort((a, b) => Number(a.split('/')[0]) - Number(b.split('/')[0])).join(' ');
}

/**
 * 解析参考工程里的 .proto，得到 message → Set("id/wire")。
 * 枚举可能定义在别的文件（如 enums.proto），因此先全目录收集枚举名。
 */
export function parseProtoFieldSets(protoDir, protoFiles = PROTO_FILES) {
  const enumNames = new Set();
  const allProtoFiles = [];
  (function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith('.proto')) allProtoFiles.push(full);
    }
  })(protoDir);

  for (const file of allProtoFiles) {
    const text = fs.readFileSync(file, 'utf8');
    const enumRe = /^\s*enum\s+([A-Za-z0-9_]+)\s*\{/gm;
    let m;
    while ((m = enumRe.exec(text)) !== null) enumNames.add(m[1]);
  }

  const raw = new Map(); // name -> Map(field -> {id, type})
  for (const file of protoFiles) {
    const text = fs.readFileSync(path.join(protoDir, file), 'utf8');
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
      if (fields.size > 0) raw.set(starts[i].name, fields);
    }
  }

  const out = new Map();
  for (const [name, fields] of raw) {
    const pairs = new Set();
    for (const info of fields.values()) {
      let wire = wireTypeOf(info.type);
      if (typeof wire !== 'number') {
        wire = enumNames.has(info.type.slice(1)) ? 0 : 2; // 枚举=varint，嵌套消息=LEN
      }
      pairs.add(`${info.id}/${wire}`);
    }
    out.set(name, pairs);
  }
  return out;
}

/** 解析参考工程生成的 protobufjs 代码，得到 message → Set("id/wire") */
export function parseGeneratedFieldSets(refDir) {
  const jsFiles = fs.readdirSync(refDir).filter((f) => f.endsWith('.js'));
  const generated = new Map();
  for (const file of jsFiles) {
    const text = fs.readFileSync(path.join(refDir, file), 'utf8');
    // 生成代码在 IIFE 内缩进，正则需允许行首空白
    const fnRe = /^\s*([A-Za-z0-9_]+)\.encode = function encode\(message, writer\)/gm;
    const starts = [];
    let m;
    while ((m = fnRe.exec(text)) !== null) starts.push({ name: m[1], index: m.index });
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
  return generated;
}

/** ArkTS writer/reader 方法 → wireType */
const WRITE_WIRE = {
  writeUint32: 0, writeInt32: 0, writeBool: 0, writeUint64: 0,
  writeFixed64: 1, writeString: 2, writeBytes: 2, writeMessage: 2,
};
const READ_WIRE = {
  readUint32: 0, readInt32: 0, readBool: 0, readUint64: 0,
  readFixed64: 1, readString: 2, readBytes: 2, readMessage: 2, readFloat32: 5,
};

/** 解析本项目 ArkTS 实现（SteamMessages.ets），得到 message → {encodePairs, decodePairs} */
export function parseArkTsFieldSets(etsPath, messages = TARGET_MESSAGES) {
  const ets = fs.readFileSync(etsPath, 'utf8');
  const out = new Map();

  for (const message of messages) {
    const classRe = new RegExp(`export class ${message}\\b[\\s\\S]*?(?=\\nexport class |$)`);
    const classMatch = ets.match(classRe);
    if (!classMatch) {
      out.set(message, null);
      continue;
    }
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
      const caseRe = /case (\d+):([\s\S]*?)(?=case \d+:|default:|\n\s*\})/g;
      let c;
      while ((c = caseRe.exec(decodeMatch[0])) !== null) {
        const reader = c[2].match(/r\.(read[A-Za-z0-9]+)\(/);
        if (!reader) continue;
        const wire = READ_WIRE[reader[1]];
        if (wire !== undefined) decodePairs.add(`${c[1]}/${wire}`);
      }
    }
    out.set(message, { encodePairs, decodePairs });
  }
  return out;
}

/** Set ↔ 数组（manifest 序列化用） */
export function toSortedArray(set) {
  return [...set].sort((a, b) => Number(a.split('/')[0]) - Number(b.split('/')[0]));
}
