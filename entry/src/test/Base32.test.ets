import { describe, it, expect } from '@ohos/hypium';
import { base32Encode, base32Decode, counterToBytes64 } from 'common';

function bytesToString(bytes: Uint8Array): string {
  return Array.from(bytes).join(',');
}

function utf8(text: string): Uint8Array {
  let out = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) {
    out[i] = text.charCodeAt(i);
  }
  return out;
}

/**
 * Verifies base32Encode / base32Decode from common/utils/TokenUtils.ets
 * against the vectors of RFC 4648 section 10 (test vectors 7-15).
 */
export default function base32Test() {
  describe('base32Test', () => {
    it('rfc4648_encode_vectors', 0, () => {
      expect(base32Encode(utf8(''))).assertEqual('');
      expect(base32Encode(utf8('f'))).assertEqual('MY======');
      expect(base32Encode(utf8('fo'))).assertEqual('MZXQ====');
      expect(base32Encode(utf8('foo'))).assertEqual('MZXW6===');
      expect(base32Encode(utf8('foob'))).assertEqual('MZXW6YQ=');
      expect(base32Encode(utf8('fooba'))).assertEqual('MZXW6YTB');
      expect(base32Encode(utf8('foobar'))).assertEqual('MZXW6YTBOI======');
    });

    it('rfc4648_decode_vector_foo', 0, () => {
      expect(bytesToString(base32Decode('MZXW6==='))).assertEqual('102,111,111');
      expect(bytesToString(base32Decode('MZXW6YTBOI======'))).assertEqual('102,111,111,98,97,114');
    });

    it('encode_null_and_undefined_return_empty', 0, () => {
      expect(base32Encode(null)).assertEqual('');
      expect(base32Encode(undefined)).assertEqual('');
    });

    it('hex_variant_encode_foobar', 0, () => {
      expect(base32Encode(utf8('foobar'), 'RFC4648-HEX')).assertEqual('CPNMUOJ1E8======');
    });

    it('hex_variant_roundtrip', 0, () => {
      expect(bytesToString(base32Decode('CPNMUOJ1E8======', 'RFC4648-HEX')))
        .assertEqual('102,111,111,98,97,114');
    });

    it('crockford_encode_f_is_CR', 0, () => {
      expect(base32Encode(utf8('f'), 'Crockford')).assertEqual('CR');
    });

    it('crockford_decode_normalizes_OIL', 0, () => {
      // 'O'->0, 'I'/'L'->1 before decoding
      expect(bytesToString(base32Decode('CR', 'Crockford'))).assertEqual('102');
    });

    it('roundtrip_arbitrary_bytes', 0, () => {
      let raw = new Uint8Array([0, 1, 2, 249, 250, 251, 252, 253, 254, 255, 127]);
      let encoded = base32Encode(raw);
      expect(bytesToString(base32Decode(encoded))).assertEqual(bytesToString(raw));
    });

    it('decode_skips_separators_and_invalid_chars', 0, () => {
      // 与卡片端 CardOTPUtils.base32Decode 保持一致：跳过非法字符并容忍分隔符。
      // 此前这里抛错 → generateOTP 返回 0 → 主界面显示 000000，
      // 而同一 secret 在桌面卡片上仍能出码（两端行为不一致）。
      expect(bytesToString(base32Decode('MZ XW6==='))).assertEqual('102,111,111');
      expect(bytesToString(base32Decode('MZX-W6==='))).assertEqual('102,111,111');
      expect(bytesToString(base32Decode('MZ!XW6==='))).assertEqual('102,111,111');
      expect(bytesToString(base32Decode('MZXW6YTB\n'))).assertEqual('102,111,111,98,97');
    });

    it('counter_to_bytes64_is_big_endian', 0, () => {
      // HOTP 计数器：8 字节大端，>2^31 不再因有符号右移出错
      expect(bytesToString(counterToBytes64(0))).assertEqual('0,0,0,0,0,0,0,0');
      expect(bytesToString(counterToBytes64(1))).assertEqual('0,0,0,0,0,0,0,1');
      expect(bytesToString(counterToBytes64(4294967297))).assertEqual('0,0,0,1,0,0,0,1');
      expect(bytesToString(counterToBytes64(2147483648))).assertEqual('0,0,0,0,128,0,0,0');
      expect(bytesToString(counterToBytes64(9007199254740991)))
        .assertEqual('0,31,255,255,255,255,255,255');
    });
  });
}
