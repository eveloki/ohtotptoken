const BASE32_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function base32Decode(input: string): Uint8Array {
  let cleaned = input.toUpperCase().replace(/=+$/, '');
  let bytes: number[] = [];
  let buffer = 0;
  let bitsLeft = 0;

  for (let i = 0; i < cleaned.length; i++) {
    let val = BASE32_CHARS.indexOf(cleaned.charAt(i));
    if (val < 0) continue;
    buffer = (buffer << 5) | val;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      bitsLeft -= 8;
      bytes.push((buffer >> bitsLeft) & 0xFF);
    }
  }
  return new Uint8Array(bytes);
}

function uint8ArrayToWordArray(u8: Uint8Array): number[] {
  let words: number[] = [];
  for (let i = 0; i < u8.length; i += 4) {
    words.push(
      ((u8[i] ?? 0) << 24) |
      ((u8[i + 1] ?? 0) << 16) |
      ((u8[i + 2] ?? 0) << 8) |
      (u8[i + 3] ?? 0)
    );
  }
  return words;
}

function wordArrayToUint8Array(words: number[], sigBytes: number): Uint8Array {
  let bytes = new Uint8Array(sigBytes);
  for (let i = 0; i < sigBytes; i++) {
    bytes[i] = (words[i >>> 2] >>> (24 - (i % 4) * 8)) & 0xFF;
  }
  return bytes;
}

function sha1(data: Uint8Array): Uint8Array {
  let H0 = 0x67452301;
  let H1 = 0xEFCDAB89;
  let H2 = 0x98BADCFE;
  let H3 = 0x10325476;
  let H4 = 0xC3D2E1F0;

  let msgLen = data.length;
  let bitLen = msgLen * 8;

  let paddedLen = ((msgLen + 8) >> 6) + 1;
  let padded = new Uint8Array(paddedLen * 64);
  padded.set(data);
  padded[msgLen] = 0x80;

  let view = new DataView(padded.buffer);
  view.setUint32(paddedLen * 64 - 4, bitLen, false);

  for (let offset = 0; offset < paddedLen * 64; offset += 64) {
    let W: number[] = new Array(80);
    for (let i = 0; i < 16; i++) {
      W[i] = view.getUint32(offset + i * 4, false);
    }
    for (let i = 16; i < 80; i++) {
      let n = W[i - 3] ^ W[i - 8] ^ W[i - 14] ^ W[i - 16];
      W[i] = ((n << 1) | (n >>> 31)) >>> 0;
    }

    let a = H0, b = H1, c = H2, d = H3, e = H4;

    for (let i = 0; i < 80; i++) {
      let f: number, k: number;
      if (i < 20) {
        f = ((b & c) | ((~b) & d)) >>> 0;
        k = 0x5A827999;
      } else if (i < 40) {
        f = (b ^ c ^ d) >>> 0;
        k = 0x6ED9EBA1;
      } else if (i < 60) {
        f = ((b & c) | (b & d) | (c & d)) >>> 0;
        k = 0x8F1BBCDC;
      } else {
        f = (b ^ c ^ d) >>> 0;
        k = 0xCA62C1D6;
      }

      let temp = ((((a << 5) | (a >>> 27)) >>> 0) + f + e + k + W[i]) >>> 0;
      e = d;
      d = c;
      c = (((b << 30) | (b >>> 2)) >>> 0);
      b = a;
      a = temp;
    }

    H0 = (H0 + a) >>> 0;
    H1 = (H1 + b) >>> 0;
    H2 = (H2 + c) >>> 0;
    H3 = (H3 + d) >>> 0;
    H4 = (H4 + e) >>> 0;
  }

  let result = new Uint8Array(20);
  let rv = new DataView(result.buffer);
  rv.setUint32(0, H0, false);
  rv.setUint32(4, H1, false);
  rv.setUint32(8, H2, false);
  rv.setUint32(12, H3, false);
  rv.setUint32(16, H4, false);
  return result;
}

function hmacSHA1(key: Uint8Array, message: Uint8Array): Uint8Array {
  const BLOCK_SIZE = 64;

  let keyBlock: Uint8Array;
  if (key.length > BLOCK_SIZE) {
    keyBlock = sha1(key);
    let padded = new Uint8Array(BLOCK_SIZE);
    padded.set(keyBlock);
    keyBlock = padded;
  } else {
    let padded = new Uint8Array(BLOCK_SIZE);
    padded.set(key);
    keyBlock = padded;
  }

  let ipad = new Uint8Array(BLOCK_SIZE);
  let opad = new Uint8Array(BLOCK_SIZE);
  for (let i = 0; i < BLOCK_SIZE; i++) {
    ipad[i] = keyBlock[i] ^ 0x36;
    opad[i] = keyBlock[i] ^ 0x5C;
  }

  let innerData = new Uint8Array(BLOCK_SIZE + message.length);
  innerData.set(ipad);
  innerData.set(message, BLOCK_SIZE);
  let innerHash = sha1(innerData);

  let outerData = new Uint8Array(BLOCK_SIZE + 20);
  outerData.set(opad);
  outerData.set(innerHash, BLOCK_SIZE);
  return sha1(outerData);
}

function stepsToBytes(steps: number): Uint8Array {
  let bytes = new Uint8Array(8);
  let dv = new DataView(bytes.buffer);
  dv.setUint32(4, steps, false);
  return bytes;
}

const STEAM_CHARS = '23456789BCDFGHJKMNPQRTVWXY';
const STEAM_DIGITS = 5;

function steamTokenFromTOTP(totpToken: number): string {
  let intCode = totpToken;
  let steamToken = '';
  for (let i = 0; i < STEAM_DIGITS; i++) {
    steamToken += STEAM_CHARS.charAt(intCode % STEAM_CHARS.length);
    intCode = Math.floor(intCode / STEAM_CHARS.length);
  }
  return steamToken;
}

export function generateCardOTP(
  secret: string,
  algorithm: string,
  digits: number,
  period: number,
  tokenType: string = '0',
  counter: number = -1,
): string {
  let key = base32Decode(secret);
  let msg: Uint8Array;

  if (tokenType === '2' && counter >= 0) {
    msg = stepsToBytes(counter);
  } else {
    let timestamp = Math.floor(Date.now() / 1000);
    let steps = Math.floor(timestamp / period);
    msg = stepsToBytes(steps);
  }

  let hash: Uint8Array;
  if (algorithm === 'SHA256') {
    hash = hmacSHA1(key, msg);
  } else {
    hash = hmacSHA1(key, msg);
  }

  let offset = hash[hash.length - 1] & 0x0F;
  let binary =
    ((hash[offset] & 0x7F) << 24) |
    ((hash[offset + 1] & 0xFF) << 16) |
    ((hash[offset + 2] & 0xFF) << 8) |
    (hash[offset + 3] & 0xFF);

  let otp = binary % Math.pow(10, digits);

  if (tokenType === '3') {
    return steamTokenFromTOTP(otp);
  }
  return otp.toString().padStart(digits, '0');
}
