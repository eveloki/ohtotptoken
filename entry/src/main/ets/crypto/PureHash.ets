/**
 * 纯 ArkTS 哈希 / HMAC 实现（不依赖 cryptoFramework，零 import）。
 *
 * 为什么不用 `@kit.CryptoArchitectureKit`：
 * - LocalUnit / Previewer 运行时下 `createMac(...).doFinalSync()` 实测返回**空数据**
 *   （不抛异常，静默失败），会让 CI 门禁里的密码学用例全部失真；
 * - 桌面卡片运行在 FormExtensionAbility 进程，不能依赖 `common` HAR
 *   （会连带加载 KvManager/RdbManager/AppStorage 等）。
 *
 * 覆盖：
 * - SHA-1   → Steam Guard 5 位动态码、交易确认签名（mobileconf 要求 SHA1）
 * - SHA-256 → 扫码登录确认签名
 * - SHA-224 / SHA-384 / SHA-512 → RFC 6238 的其余算法（卡片动态码需要）
 * - HMAC    → 上述签名的 keyed-hash 包装
 *
 * 输出已与 node:crypto 逐字节对齐（见 SteamCrypto.test / CardOTPUtils.test 的 RFC 向量）。
 * 本文件同时被 `entry/steam`（服务层）与 `entry/widget`（卡片）引用，
 * 因此**不得** import 任何模块。
 */

const MSG32: number = 0xffffffff;
const MASK64: bigint = 0xffffffffffffffffn;

function rotr32(value: number, bits: number): number {
  return ((value >>> bits) | (value << (32 - bits))) >>> 0;
}

function rotl32(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0;
}

function rotr64(value: bigint, bits: bigint): bigint {
  return ((value >> bits) | (value << (64n - bits))) & MASK64;
}

/** FIPS 180-4 填充（32 位系列，块 64 字节） */
function padMessage(data: Uint8Array, blockSize: number): Uint8Array {
  const bitLenHi: number = Math.floor(data.length / 536870912); // (len*8) >> 32
  const bitLenLo: number = (data.length << 3) >>> 0;
  const withOne: number = data.length + 1;
  const paddedLen: number = Math.ceil((withOne + 8) / blockSize) * blockSize;
  const padded: Uint8Array = new Uint8Array(paddedLen);
  padded.set(data);
  padded[data.length] = 0x80;
  padded[paddedLen - 8] = (bitLenHi >>> 24) & 0xff;
  padded[paddedLen - 7] = (bitLenHi >>> 16) & 0xff;
  padded[paddedLen - 6] = (bitLenHi >>> 8) & 0xff;
  padded[paddedLen - 5] = bitLenHi & 0xff;
  padded[paddedLen - 4] = (bitLenLo >>> 24) & 0xff;
  padded[paddedLen - 3] = (bitLenLo >>> 16) & 0xff;
  padded[paddedLen - 2] = (bitLenLo >>> 8) & 0xff;
  padded[paddedLen - 1] = bitLenLo & 0xff;
  return padded;
}

function writeWordBE(out: Uint8Array, offset: number, value: number): void {
  out[offset] = (value >>> 24) & 0xff;
  out[offset + 1] = (value >>> 16) & 0xff;
  out[offset + 2] = (value >>> 8) & 0xff;
  out[offset + 3] = value & 0xff;
}

function readWordBE(data: Uint8Array, offset: number): number {
  return ((data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3]) >>> 0;
}

export function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out: Uint8Array = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

export function truncateBytes(bytes: Uint8Array, length: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(length);
  out.set(bytes.subarray(0, length));
  return out;
}

/** HOTP 计数器 → 8 字节大端（精确到 2^53，覆盖 32 位以上取值） */
export function counterToBytes64(counter: number): Uint8Array {
  let value: bigint = BigInt(Math.floor(counter)) & MASK64;
  const out: Uint8Array = new Uint8Array(8);
  for (let i: number = 7; i >= 0; i--) {
    out[i] = Number(value & 0xffn);
    value = value >> 8n;
  }
  return out;
}

// ---------------------------------------------------------------- SHA-1

/** SHA-1（FIPS 180-4），返回 20 字节 */
export function sha1(data: Uint8Array): Uint8Array {
  let h0: number = 0x67452301;
  let h1: number = 0xefcdab89;
  let h2: number = 0x98badcfe;
  let h3: number = 0x10325476;
  let h4: number = 0xc3d2e1f0;

  const padded: Uint8Array = padMessage(data, 64);
  const w: number[] = new Array<number>(80);

  for (let block: number = 0; block < padded.length; block += 64) {
    for (let j: number = 0; j < 16; j++) {
      w[j] = readWordBE(padded, block + j * 4);
    }
    for (let j: number = 16; j < 80; j++) {
      w[j] = rotl32(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1);
    }

    let a: number = h0;
    let b: number = h1;
    let c: number = h2;
    let d: number = h3;
    let e: number = h4;

    for (let j: number = 0; j < 80; j++) {
      let f: number = 0;
      let k: number = 0;
      if (j < 20) {
        f = (b & c) | ((~b) & d);
        k = 0x5a827999;
      } else if (j < 40) {
        f = b ^ c ^ d;
        k = 0x6ed9eba1;
      } else if (j < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8f1bbcdc;
      } else {
        f = b ^ c ^ d;
        k = 0xca62c1d6;
      }
      const temp: number = ((rotl32(a, 5) + f + e + k + w[j]) & MSG32) >>> 0;
      e = d;
      d = c;
      c = rotl32(b, 30);
      b = a;
      a = temp;
    }

    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }

  const out: Uint8Array = new Uint8Array(20);
  writeWordBE(out, 0, h0);
  writeWordBE(out, 4, h1);
  writeWordBE(out, 8, h2);
  writeWordBE(out, 12, h3);
  writeWordBE(out, 16, h4);
  return out;
}

// ---------------------------------------------------------------- SHA-2（32 位）

const K256: number[] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const SHA256_IV: number[] = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

const SHA224_IV: number[] = [
  0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4,
];

/** SHA-224/SHA-256 共用核心，返回 32 字节（SHA-224 由调用方截断到 28 字节） */
function sha2_32(data: Uint8Array, iv: number[]): Uint8Array {
  const h: number[] = new Array<number>(8);
  for (let i: number = 0; i < 8; i++) {
    h[i] = iv[i];
  }

  const padded: Uint8Array = padMessage(data, 64);
  const w: number[] = new Array<number>(64);

  for (let block: number = 0; block < padded.length; block += 64) {
    for (let j: number = 0; j < 16; j++) {
      w[j] = readWordBE(padded, block + j * 4);
    }
    for (let j: number = 16; j < 64; j++) {
      const s0: number = rotr32(w[j - 15], 7) ^ rotr32(w[j - 15], 18) ^ (w[j - 15] >>> 3);
      const s1: number = rotr32(w[j - 2], 17) ^ rotr32(w[j - 2], 19) ^ (w[j - 2] >>> 10);
      w[j] = ((w[j - 16] + s0 + w[j - 7] + s1) & MSG32) >>> 0;
    }

    let a: number = h[0];
    let b: number = h[1];
    let c: number = h[2];
    let d: number = h[3];
    let e: number = h[4];
    let f: number = h[5];
    let g: number = h[6];
    let hh: number = h[7];

    for (let j: number = 0; j < 64; j++) {
      const bigS1: number = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25);
      const ch: number = (e & f) ^ ((~e) & g);
      const temp1: number = ((hh + bigS1 + ch + K256[j] + w[j]) & MSG32) >>> 0;
      const bigS0: number = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22);
      const maj: number = (a & b) ^ (a & c) ^ (b & c);
      const temp2: number = ((bigS0 + maj) & MSG32) >>> 0;

      hh = g;
      g = f;
      f = e;
      e = ((d + temp1) & MSG32) >>> 0;
      d = c;
      c = b;
      b = a;
      a = ((temp1 + temp2) & MSG32) >>> 0;
    }

    h[0] = (h[0] + a) >>> 0;
    h[1] = (h[1] + b) >>> 0;
    h[2] = (h[2] + c) >>> 0;
    h[3] = (h[3] + d) >>> 0;
    h[4] = (h[4] + e) >>> 0;
    h[5] = (h[5] + f) >>> 0;
    h[6] = (h[6] + g) >>> 0;
    h[7] = (h[7] + hh) >>> 0;
  }

  const out: Uint8Array = new Uint8Array(32);
  for (let i: number = 0; i < 8; i++) {
    writeWordBE(out, i * 4, h[i]);
  }
  return out;
}

/** SHA-256（FIPS 180-4），返回 32 字节 */
export function sha256(data: Uint8Array): Uint8Array {
  return sha2_32(data, SHA256_IV);
}

/** SHA-224，返回 28 字节 */
export function sha224(data: Uint8Array): Uint8Array {
  return truncateBytes(sha2_32(data, SHA224_IV), 28);
}

// ---------------------------------------------------------------- SHA-2（64 位）

const K512: bigint[] = [
  0x428a2f98d728ae22n, 0x7137449123ef65cdn, 0xb5c0fbcfec4d3b2fn, 0xe9b5dba58189dbbcn,
  0x3956c25bf348b538n, 0x59f111f1b605d019n, 0x923f82a4af194f9bn, 0xab1c5ed5da6d8118n,
  0xd807aa98a3030242n, 0x12835b0145706fben, 0x243185be4ee4b28cn, 0x550c7dc3d5ffb4e2n,
  0x72be5d74f27b896fn, 0x80deb1fe3b1696b1n, 0x9bdc06a725c71235n, 0xc19bf174cf692694n,
  0xe49b69c19ef14ad2n, 0xefbe4786384f25e3n, 0x0fc19dc68b8cd5b5n, 0x240ca1cc77ac9c65n,
  0x2de92c6f592b0275n, 0x4a7484aa6ea6e483n, 0x5cb0a9dcbd41fbd4n, 0x76f988da831153b5n,
  0x983e5152ee66dfabn, 0xa831c66d2db43210n, 0xb00327c898fb213fn, 0xbf597fc7beef0ee4n,
  0xc6e00bf33da88fc2n, 0xd5a79147930aa725n, 0x06ca6351e003826fn, 0x142929670a0e6e70n,
  0x27b70a8546d22ffcn, 0x2e1b21385c26c926n, 0x4d2c6dfc5ac42aedn, 0x53380d139d95b3dfn,
  0x650a73548baf63den, 0x766a0abb3c77b2a8n, 0x81c2c92e47edaee6n, 0x92722c851482353bn,
  0xa2bfe8a14cf10364n, 0xa81a664bbc423001n, 0xc24b8b70d0f89791n, 0xc76c51a30654be30n,
  0xd192e819d6ef5218n, 0xd69906245565a910n, 0xf40e35855771202an, 0x106aa07032bbd1b8n,
  0x19a4c116b8d2d0c8n, 0x1e376c085141ab53n, 0x2748774cdf8eeb99n, 0x34b0bcb5e19b48a8n,
  0x391c0cb3c5c95a63n, 0x4ed8aa4ae3418acbn, 0x5b9cca4f7763e373n, 0x682e6ff3d6b2b8a3n,
  0x748f82ee5defb2fcn, 0x78a5636f43172f60n, 0x84c87814a1f0ab72n, 0x8cc702081a6439ecn,
  0x90befffa23631e28n, 0xa4506cebde82bde9n, 0xbef9a3f7b2c67915n, 0xc67178f2e372532bn,
  0xca273eceea26619cn, 0xd186b8c721c0c207n, 0xeada7dd6cde0eb1en, 0xf57d4f7fee6ed178n,
  0x06f067aa72176fban, 0x0a637dc5a2c898a6n, 0x113f9804bef90daen, 0x1b710b35131c471bn,
  0x28db77f523047d84n, 0x32caab7b40c72493n, 0x3c9ebe0a15c9bebcn, 0x431d67c49c100d4cn,
  0x4cc5d4becb3e42b6n, 0x597f299cfc657e2an, 0x5fcb6fab3ad6faecn, 0x6c44198c4a475817n,
];

const SHA512_IV: bigint[] = [
  0x6a09e667f3bcc908n, 0xbb67ae8584caa73bn, 0x3c6ef372fe94f82bn, 0xa54ff53a5f1d36f1n,
  0x510e527fade682d1n, 0x9b05688c2b3e6c1fn, 0x1f83d9abfb41bd6bn, 0x5be0cd19137e2179n,
];

const SHA384_IV: bigint[] = [
  0xcbbb9d5dc1059ed8n, 0x629a292a367cd507n, 0x9159015a3070dd17n, 0x152fecd8f70e5939n,
  0x67332667ffc00b31n, 0x8eb44a8768581511n, 0xdb0c2e0d64f98fa7n, 0x47b5481dbefa4fa4n,
];

/** SHA-384/SHA-512 共用核心（BigInt 实现，块 128 字节），返回 64 字节 */
function sha2_64(data: Uint8Array, iv: bigint[]): Uint8Array {
  const blockSize: number = 128;
  const bitLen: bigint = BigInt(data.length) * 8n;
  const paddedLen: number = Math.ceil((data.length + 17) / blockSize) * blockSize;
  const padded: Uint8Array = new Uint8Array(paddedLen);
  padded.set(data);
  padded[data.length] = 0x80;
  // 长度字段 128 位大端；输入 < 2^61 字节时高 64 位恒为 0
  let remaining: bigint = bitLen;
  for (let i: number = 0; i < 16; i++) {
    padded[paddedLen - 1 - i] = Number(remaining & 0xffn);
    remaining = remaining >> 8n;
  }

  const h: bigint[] = new Array<bigint>(8);
  for (let i: number = 0; i < 8; i++) {
    h[i] = iv[i];
  }
  const w: bigint[] = new Array<bigint>(80);

  for (let block: number = 0; block < paddedLen; block += blockSize) {
    for (let j: number = 0; j < 16; j++) {
      let word: bigint = 0n;
      for (let k: number = 0; k < 8; k++) {
        word = (word << 8n) | BigInt(padded[block + j * 8 + k]);
      }
      w[j] = word;
    }
    for (let j: number = 16; j < 80; j++) {
      const s0: bigint = rotr64(w[j - 15], 1n) ^ rotr64(w[j - 15], 8n) ^ (w[j - 15] >> 7n);
      const s1: bigint = rotr64(w[j - 2], 19n) ^ rotr64(w[j - 2], 61n) ^ (w[j - 2] >> 6n);
      w[j] = (w[j - 16] + s0 + w[j - 7] + s1) & MASK64;
    }

    let a: bigint = h[0];
    let b: bigint = h[1];
    let c: bigint = h[2];
    let d: bigint = h[3];
    let e: bigint = h[4];
    let f: bigint = h[5];
    let g: bigint = h[6];
    let hh: bigint = h[7];

    for (let j: number = 0; j < 80; j++) {
      const bigS1: bigint = rotr64(e, 14n) ^ rotr64(e, 18n) ^ rotr64(e, 41n);
      const ch: bigint = (e & f) ^ (~e & g);
      const temp1: bigint = (hh + bigS1 + ch + K512[j] + w[j]) & MASK64;
      const bigS0: bigint = rotr64(a, 28n) ^ rotr64(a, 34n) ^ rotr64(a, 39n);
      const maj: bigint = (a & b) ^ (a & c) ^ (b & c);
      const temp2: bigint = (bigS0 + maj) & MASK64;

      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & MASK64;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & MASK64;
    }

    h[0] = (h[0] + a) & MASK64;
    h[1] = (h[1] + b) & MASK64;
    h[2] = (h[2] + c) & MASK64;
    h[3] = (h[3] + d) & MASK64;
    h[4] = (h[4] + e) & MASK64;
    h[5] = (h[5] + f) & MASK64;
    h[6] = (h[6] + g) & MASK64;
    h[7] = (h[7] + hh) & MASK64;
  }

  const out: Uint8Array = new Uint8Array(64);
  for (let i: number = 0; i < 8; i++) {
    let word: bigint = h[i];
    for (let j: number = 7; j >= 0; j--) {
      out[i * 8 + j] = Number(word & 0xffn);
      word = word >> 8n;
    }
  }
  return out;
}

/** SHA-512，返回 64 字节 */
export function sha512(data: Uint8Array): Uint8Array {
  return sha2_64(data, SHA512_IV);
}

/** SHA-384，返回 48 字节 */
export function sha384(data: Uint8Array): Uint8Array {
  return truncateBytes(sha2_64(data, SHA384_IV), 48);
}

// ---------------------------------------------------------------- HMAC

/** 通用 HMAC（RFC 2104） */
export function hmac(hashFn: (data: Uint8Array) => Uint8Array, blockSize: number,
  key: Uint8Array, message: Uint8Array): Uint8Array {
  const keyBlock: Uint8Array = new Uint8Array(blockSize);
  if (key.length > blockSize) {
    keyBlock.set(hashFn(key));
  } else {
    keyBlock.set(key);
  }

  const ipad: Uint8Array = new Uint8Array(blockSize);
  const opad: Uint8Array = new Uint8Array(blockSize);
  for (let i: number = 0; i < blockSize; i++) {
    ipad[i] = keyBlock[i] ^ 0x36;
    opad[i] = keyBlock[i] ^ 0x5c;
  }

  return hashFn(concatBytes(opad, hashFn(concatBytes(ipad, message))));
}

/** HMAC-SHA1（block size 64） */
export function hmacSha1(key: Uint8Array, message: Uint8Array): Uint8Array {
  return hmac((data: Uint8Array): Uint8Array => sha1(data), 64, key, message);
}

/** HMAC-SHA224（block size 64） */
export function hmacSha224(key: Uint8Array, message: Uint8Array): Uint8Array {
  return hmac((data: Uint8Array): Uint8Array => sha224(data), 64, key, message);
}

/** HMAC-SHA256（block size 64） */
export function hmacSha256(key: Uint8Array, message: Uint8Array): Uint8Array {
  return hmac((data: Uint8Array): Uint8Array => sha256(data), 64, key, message);
}

/** HMAC-SHA384（block size 128） */
export function hmacSha384(key: Uint8Array, message: Uint8Array): Uint8Array {
  return hmac((data: Uint8Array): Uint8Array => sha384(data), 128, key, message);
}

/** HMAC-SHA512（block size 128） */
export function hmacSha512(key: Uint8Array, message: Uint8Array): Uint8Array {
  return hmac((data: Uint8Array): Uint8Array => sha512(data), 128, key, message);
}
