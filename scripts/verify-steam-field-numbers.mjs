/**
 * Steam 消息字段号交叉校验（离线、只读）。
 *
 * 校验对象：本项目 ArkTS 手写实现（entry/src/main/ets/steam/proto/SteamMessages.ets）
 * 参考来源：
 *   1. `scripts/reference/steam-field-numbers.json` —— 仓库内快照（官方 .proto + protobufjs
 *      生成代码的字段号集合），**始终可用**，干净 clone 也能跑；
 *   2. 可选：参考工程目录（默认 `.ai/Authenticator-main/.../steamapi`，可用
 *      `STEAM_PROTO_REF` 覆盖）—— 存在时额外做「快照是否已过期」的活体校验。
 *
 * 比对「字段号 + wireType」集合（忽略字段名，因为 ArkTS 侧用 camelCase）。
 *
 * 用法：node scripts/verify-steam-field-numbers.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import {
  DEFAULT_REF,
  TARGET_MESSAGES,
  parseProtoFieldSets,
  parseGeneratedFieldSets,
  parseArkTsFieldSets,
  showSet,
} from './lib/steam-field-sources.mjs';

const MESSAGES_ETS = 'entry/src/main/ets/steam/proto/SteamMessages.ets';
const MANIFEST = 'scripts/reference/steam-field-numbers.json';

if (!fs.existsSync(MANIFEST)) {
  console.error(`缺少参考快照 ${MANIFEST}；请运行 node scripts/generate-steam-field-manifest.mjs 生成。`);
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
const manifestProto = new Map(Object.entries(manifest.fromProto).map(([k, v]) => [k, new Set(v)]));
const manifestGenerated = new Map(Object.entries(manifest.fromGeneratedJs).map(([k, v]) => [k, new Set(v)]));

// ---- 可选的活体参考工程 ----
const REF = process.env.STEAM_PROTO_REF ?? DEFAULT_REF;
const liveProtoDir = path.join(REF, 'protobufs');
const hasLiveRef = fs.existsSync(liveProtoDir);
let liveProto = null;
let liveGenerated = null;
if (hasLiveRef) {
  liveProto = parseProtoFieldSets(liveProtoDir);
  liveGenerated = parseGeneratedFieldSets(REF);
}

const arkTs = parseArkTsFieldSets(MESSAGES_ETS, TARGET_MESSAGES);

let failures = 0;
const lines = [];

lines.push(`参考快照 : ${MANIFEST}（${manifestProto.size} 条消息）`);
lines.push(`活体参考 : ${hasLiveRef ? REF : '(未提供，跳过快照过期检查)'}`);
lines.push('');

for (const message of TARGET_MESSAGES) {
  const expected = manifestProto.get(message) ?? null;
  const snapshotGenerated = manifestGenerated.get(message) ?? null;
  const mine = arkTs.get(message) ?? null;

  lines.push(`### ${message}`);
  lines.push(`  snapshot  : ${expected ? showSet(expected) : '(missing in manifest)'}`);
  if (mine) {
    lines.push(`  encode    : ${showSet(mine.encodePairs)}`);
    lines.push(`  decode    : ${showSet(mine.decodePairs)}`);
  } else {
    lines.push('  ArkTS     : (class not found)');
  }

  // 校验 1：快照自洽（proto 与生成代码两个来源必须一致）
  if (expected && snapshotGenerated) {
    const diff = [...expected].filter((p) => !snapshotGenerated.has(p))
      .concat([...snapshotGenerated].filter((p) => !expected.has(p)));
    if (diff.length) {
      lines.push(`  !! 快照内 proto 与 generatedJs 不一致: ${diff.join(' ')}`);
      failures++;
    }
  }

  // 校验 2：ArkTS 实现只用快照中存在的字段号（只比较我实际使用到的字段子集）
  if (expected && mine) {
    const used = mine.encodePairs.size > 0 ? mine.encodePairs : mine.decodePairs;
    const wrong = [...used].filter((p) => !expected.has(p));
    if (wrong.length) {
      lines.push(`  !! ArkTS 字段号/wireType 不在参考定义中: ${wrong.join(' ')}`);
      failures++;
    }
    if (used.size > 0) {
      lines.push(`  ok: ArkTS 使用 ${used.size} 个字段，全部命中参考定义`);
    }
  }
  if (!mine) {
    lines.push('  !! ArkTS 中找不到该消息类');
    failures++;
  }

  // 校验 3（仅在提供参考工程时）：快照是否与上游一致（防止 .proto 更新后快照过期）
  if (hasLiveRef && expected && liveProto) {
    const live = liveProto.get(message);
    if (!live) {
      lines.push('  !! 活体参考中找不到该消息（快照可能来自更早的版本）');
      failures++;
    } else {
      const diff = [...expected].filter((p) => !live.has(p)).concat([...live].filter((p) => !expected.has(p)));
      if (diff.length) {
        lines.push(`  !! 快照与活体 .proto 不一致，请重新生成快照: ${diff.join(' ')}`);
        failures++;
      }
    }
  }
  if (hasLiveRef && snapshotGenerated && liveGenerated) {
    const liveGen = liveGenerated.get(message);
    if (liveGen) {
      const diff = [...snapshotGenerated].filter((p) => !liveGen.has(p))
        .concat([...liveGen].filter((p) => !snapshotGenerated.has(p)));
      if (diff.length) {
        lines.push(`  !! 快照与活体生成代码不一致: ${diff.join(' ')}`);
        failures++;
      }
    }
  }
}

console.log(lines.join('\n'));
console.log(`\n${failures === 0 ? 'PASS' : 'FAIL'} — ${failures} 处不一致`);
if (!hasLiveRef) {
  console.log('提示：设置 STEAM_PROTO_REF 指向参考工程 steamapi 目录后，可额外校验快照是否过期。');
}
process.exit(failures === 0 ? 0 : 1);
