/**
 * 字符串资源完整性校验（只读）。
 *
 * 检查 `$r('app.string.KEY')` 用到的每个 key：
 *   - 是否存在于 base（缺失 = 编译/运行时错误）
 *   - 是否在 en_US / zh_CN / zh_TW 中齐全（缺失会回退到 base，属警告）
 * 同时反向检查：4 份资源之间的 key 集合差异（避免只加了中文忘了英文）。
 *
 * 用法：node scripts/check-string-keys.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const LOCALES = ['base', 'en_US', 'zh_CN', 'zh_TW'];
const SRC_ROOTS = ['entry/src/main/ets', 'common/src/main/ets', 'uikit/src/main/ets', 'wearable/src/main/ets'];
const EXTRA_SCAN = ['entry/src/main/ets/widget', 'entry/src/main/ets/form'];

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (/\.(ets|ts)$/.test(entry.name)) out.push(full);
  }
  return out;
}

const sources = [];
for (const root of [...SRC_ROOTS, ...EXTRA_SCAN]) walk(root, sources);

const used = new Set();
const usedBy = new Map();
const keyRe = /\$r\(\s*['"]app\.string\.([A-Za-z0-9_]+)['"]/g;
for (const file of sources) {
  const text = fs.readFileSync(file, 'utf8');
  let m;
  while ((m = keyRe.exec(text)) !== null) {
    used.add(m[1]);
    if (!usedBy.has(m[1])) usedBy.set(m[1], file);
  }
}

const locales = new Map();
for (const loc of LOCALES) {
  const file = `common/src/main/resources/${loc}/element/string.json`;
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  locales.set(loc, new Set(json.string.map((e) => e.name)));
}

const base = locales.get('base');
const missingInBase = [...used].filter((k) => !base.has(k)).sort();
const missingPerLocale = new Map();
for (const loc of LOCALES) {
  if (loc === 'base') continue;
  const set = locales.get(loc);
  missingPerLocale.set(loc, [...used].filter((k) => !set.has(k)).sort());
}

// 资源之间：base 有但某语言没有的 key（不一定被代码使用，但应补齐）
const baseOnlyDiff = new Map();
for (const loc of LOCALES) {
  if (loc === 'base') continue;
  const set = locales.get(loc);
  baseOnlyDiff.set(loc, [...base].filter((k) => !set.has(k)).sort());
}

console.log(`扫描源文件: ${sources.length}，引用到的 app.string.* key: ${used.size}`);
for (const loc of LOCALES) console.log(`  ${loc}: ${locales.get(loc).size} 条`);

let failed = false;
if (missingInBase.length > 0) {
  failed = true;
  console.log(`\n[FAIL] base 缺失 ${missingInBase.length} 个被引用的 key:`);
  for (const k of missingInBase) console.log(`  - ${k}  (${usedBy.get(k)})`);
} else {
  console.log('\n[OK] 所有被引用的 key 都存在于 base');
}

for (const [loc, list] of missingPerLocale) {
  if (list.length > 0) {
    console.log(`\n[WARN] ${loc} 缺少 ${list.length} 个被引用的 key（会回退到 base）:`);
    for (const k of list.slice(0, 20)) console.log(`  - ${k}`);
    if (list.length > 20) console.log(`  ... 另有 ${list.length - 20} 个`);
  }
}

const steamKeys = [...base].filter((k) => k.startsWith('steam_')).sort();
console.log(`\nsteam_* 资源: base ${steamKeys.length} 条`);
for (const loc of LOCALES) {
  if (loc === 'base') continue;
  const set = locales.get(loc);
  const miss = steamKeys.filter((k) => !set.has(k));
  console.log(`  ${loc}: ${miss.length === 0 ? '齐全' : '缺 ' + miss.join(', ')}`);
}

process.exit(failed ? 1 : 0);
