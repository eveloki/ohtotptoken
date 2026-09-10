/**
 * 生成 Steam 字段号参考快照（scripts/reference/steam-field-numbers.json）。
 *
 * 为什么需要快照：参考工程目录 `.ai/` 不进仓库（.gitignore），
 * 若校验脚本直接依赖它，干净 clone 上 `npm run check` 必然 ENOENT。
 * 快照把「官方 .proto + protobufjs 生成代码」的字段号集合固化进仓库，
 * 使校验在任意环境可跑；参考目录存在时 verify 脚本还会校验快照是否过期。
 *
 * 用法（需要参考工程目录）：
 *   node scripts/generate-steam-field-manifest.mjs
 *   STEAM_PROTO_REF=/path/to/steamapi node scripts/generate-steam-field-manifest.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import {
  DEFAULT_REF,
  TARGET_MESSAGES,
  parseProtoFieldSets,
  parseGeneratedFieldSets,
  toSortedArray,
} from './lib/steam-field-sources.mjs';

const REF = process.env.STEAM_PROTO_REF ?? DEFAULT_REF;
const PROTO_DIR = path.join(REF, 'protobufs');
const OUT = 'scripts/reference/steam-field-numbers.json';

if (!fs.existsSync(PROTO_DIR)) {
  console.error(`缺少参考工程目录：${PROTO_DIR}`);
  console.error('请先 clone 参考工程，或用 STEAM_PROTO_REF 指定 steamapi 目录。');
  process.exit(1);
}

const protoSets = parseProtoFieldSets(PROTO_DIR);
const generatedSets = parseGeneratedFieldSets(REF);

const fromProto = {};
const fromGeneratedJs = {};
const missing = [];
for (const message of TARGET_MESSAGES) {
  const proto = protoSets.get(message);
  const gen = generatedSets.get(message);
  if (!proto || !gen) missing.push(`${message}${proto ? '' : ' (proto)'}${gen ? '' : ' (generated)'}`);
  if (proto) fromProto[message] = toSortedArray(proto);
  if (gen) fromGeneratedJs[message] = toSortedArray(gen);
}

if (missing.length > 0) {
  console.error(`以下消息在参考目录中未找到，快照不完整：\n  ${missing.join('\n  ')}`);
  process.exit(1);
}

const manifest = {
  _comment: 'Steam 消息字段号参考快照（字段号/wireType）。由 scripts/generate-steam-field-manifest.mjs 生成，勿手改。',
  _sources: {
    proto: '参考工程内的官方 .proto（steammessages_auth.steamclient.proto / service_twofactor.proto）',
    generatedJs: '参考工程内 protobufjs 生成的 *.js（独立第二来源）',
  },
  fromProto,
  fromGeneratedJs,
};

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(`已写入 ${OUT}：${TARGET_MESSAGES.length} 条消息`);
