import { describe, it, expect } from '@ohos/hypium';
import {
  base64Decode,
  base64Encode,
  bytesToUtf8,
  hmacSha1Base64,
  hmacSha256Base64,
  jwtExpSeconds,
  rsaEncryptPkcs1,
  uint64ToBytesBE,
  uint64ToBytesLE,
  utf8ToBytes,
} from '../main/ets/steam/SteamCrypto';
import { sha1, sha256 } from '../main/ets/crypto/PureHash';
import { STEAM_CODE_PERIOD, steamGuardCode, SteamCodeGenerator } from '../main/ets/steam/SteamCode';

/**
 * Steam 加密/编码层测试。
 *
 * 期望值由 node:crypto 独立实现产出（`.local/golden/gen-golden.mjs`），
 * 用于验证 ArkTS 侧手写 base64/HMAC/动态码与业界实现一致。
 */

const SECRET_B64 = 'MDEyMzQ1Njc4OWFiY2RlZg==';
// node 现场生成的 RSA-1024 测试公钥 + 固定 padding 的确定性密文（见 gen-golden.mjs）
const RSA_MOD_HEX = 'aa5dd6d169710f62693976b509bca4b47545e56ff71df9a014b08214c979b158ecb77dc34b14f4a4ad404c6dd1976f91c5ac07f1567b67d050ecfa5e079dbdef96050859cec02c82bdcfd02647fc29269d26491c7c96118d41ddab9a55549bb19f2ca2f496cc1bafa79c840eb15626f81b08a2d9577db89652836aa1bb680ce9';
const RSA_EXP_HEX = '010001';
const RSA_PASSWORD = 'hunter2';
const RSA_PADDING_HEX = '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f70717273747576';
const RSA_CIPHERTEXT_HEX = '9b33307195ea51a60bdb688cebb96a11cdd06ee4ee622b0208b58c91ad6fdc818b312fe9531e1766748bc6539db271dba7bdeef78026d8cededb222922621cabc425b2a2e67db8abd3a8cb16f39ca9148dc02f8bff35c4e20b86522c1a397182c65b4a37f8bc071c14b102212902edd434156430158f3a21313a68188549000b';

// 2048 位向量（Steam 线上实际使用 2048 位公钥；node:crypto 生成并验证可解出 hunter2）
const RSA2048_MOD_HEX = '8e9eeddcce7135c720e449354bcc72b29d96d749b27a8fac0c38b1f0ec491f0790ebe2d92a543fed433e5a0cd68bd771a0fadee514953d8bec7da9ef99d4307e64fd569106b816a868fd4f4d48de7a906db04912d226c0d8ef72e8a856ff2bcf5d48f6fc6d673330a096c792642b3b0f8897fbcfee83bdf39a69d1967e589a915791c84cfb04d7b4e91cbe5c0e0569074444ac7ebaa052221e53bc51085a29b93e249da2b09fcbc4c92e2bd84ed83a7cfe0cccd44181eb32b3d05f0f6ed66a0edc621314f8c5fcd71ac866900540fd59660754ff9213ba65d7ed37810fad529b04f78edb3b7ab53aaff01fa3da5b48422e95b7812d277f38b7060eda19b28973';
const RSA2048_EXP_HEX = '010001';
const RSA2048_PADDING_HEX = '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6';
const RSA2048_CIPHERTEXT_HEX = '4bed8d963ab9054ffda29127264208fc1e1bb0ef007d9a245c7a3687c2db117945c466b237d77d69bca0da1b0401d690d87d80e4a130756b6387e43a8ae8aa2089865c712fac51358a02df520da8b0ec0a5b05018c1c180b8ad0f41d2d1cb3060d5749f927b0f022d183cb8952e47ac5b317ce577290dc5cf5b200f8f2d5512b9b8bb2b01d62ea3fb49b703cf462619eef32783674f87df443c2ee3195fa6fc266051dc1888f8f59d14c9c43b6663e2182ecca2ff80efd9145fe55a2e162ac780840de8dbfa04050a1c16a1f82f776654a1c0174cf2a4dc8c39183d4803a1ece8fce8c0d23ec03be7788203f63a4f0f25463005bb37f0485cd3559f6d3cd5011';

function bytesOf(values: number[]): Uint8Array {
  const out = new Uint8Array(values.length);
  for (let i = 0; i < values.length; i++) {
    out[i] = values[i];
  }
  return out;
}

function bytesToHex(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, '0');
  }
  return out;
}

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return out;
}

export default function steamCryptoTest() {
  describe('steamCryptoTest', () => {
    it('base64_encode_rfc4648_vectors', 0, () => {
      expect(base64Encode(utf8ToBytes(''))).assertEqual('');
      expect(base64Encode(utf8ToBytes('f'))).assertEqual('Zg==');
      expect(base64Encode(utf8ToBytes('fo'))).assertEqual('Zm8=');
      expect(base64Encode(utf8ToBytes('foo'))).assertEqual('Zm9v');
      expect(base64Encode(utf8ToBytes('foob'))).assertEqual('Zm9vYg==');
      expect(base64Encode(utf8ToBytes('fooba'))).assertEqual('Zm9vYmE=');
      expect(base64Encode(utf8ToBytes('foobar'))).assertEqual('Zm9vYmFy');
      expect(base64Encode(bytesOf([0x00, 0xff, 0x10, 0x80, 0x7f]))).assertEqual('AP8QgH8=');
    });

    it('base64_decode_roundtrip_and_urlsafe', 0, () => {
      expect(bytesToUtf8(base64Decode('Zm9vYmFy'))).assertEqual('foobar');
      expect(bytesToUtf8(base64Decode('Zm9vYmE='))).assertEqual('fooba');
      // base64url 变体（JWT 常见，无填充）
      expect(base64Decode('AP8QgH8').length).assertEqual(5);
      expect(base64Decode('-_8').length).assertEqual(2);
    });

    it('hmac_sha1_matches_node_crypto', 0, () => {
      expect(hmacSha1Base64(SECRET_B64, [utf8ToBytes('conf')]))
        .assertEqual('F/WU0mlfOrS+c2/Hwc1OffF+5HI=');
    });

    it('hmac_sha256_matches_node_crypto', 0, () => {
      expect(hmacSha256Base64(SECRET_B64, [utf8ToBytes('payload')]))
        .assertEqual('Rv8Y/NNLfA0/+QCAJrjVI2w3Hxb4Jlbdq8iLYdURqtU=');
    });

    it('steam_guard_code_matches_node_crypto', 0, () => {
      expect(steamGuardCode(SECRET_B64, 1788953926)).assertEqual('5X5FQ');
      expect(steamGuardCode(SECRET_B64, 0)).assertEqual('G7N96');
      expect(steamGuardCode(SECRET_B64, 30)).assertEqual('5VCGM');
      // 同一时间步内（30~59 秒）码必须相同
      expect(steamGuardCode(SECRET_B64, 59)).assertEqual('5VCGM');
      expect(steamGuardCode(SECRET_B64, 1234567890)).assertEqual('9PT79');
    });

    it('steam_code_generator_applies_server_offset', 0, () => {
      const gen = new SteamCodeGenerator();
      // 本地时间比服务端慢 30 秒：校正后应与服务端时间同码
      gen.syncServerTime(1788953926, 1788953926 - 30);
      expect(gen.getOffsetSeconds()).assertEqual(30);
      expect(gen.code(SECRET_B64, 1788953926 - 30)).assertEqual('5X5FQ');
      expect(gen.remainingSeconds(1788953926 - 30))
        .assertEqual(STEAM_CODE_PERIOD - (1788953926 % STEAM_CODE_PERIOD));
      gen.reset();
      expect(gen.getOffsetSeconds()).assertEqual(0);
    });

    it('uint_bytes_big_and_little_endian', 0, () => {
      expect(Array.from(uint64ToBytesBE(0x0102030405060708n, 8)).join(','))
        .assertEqual('1,2,3,4,5,6,7,8');
      expect(Array.from(uint64ToBytesLE(0x0102030405060708n, 8)).join(','))
        .assertEqual('8,7,6,5,4,3,2,1');
      expect(Array.from(uint64ToBytesBE(1n, 2)).join(',')).assertEqual('0,1');
      expect(Array.from(uint64ToBytesLE(1n, 2)).join(',')).assertEqual('1,0');
    });

    it('sha1_sha256_match_node_crypto', 0, () => {
      const toHex = (u8: Uint8Array): string => {
        let out = '';
        for (let i = 0; i < u8.length; i++) {
          out += u8[i].toString(16).padStart(2, '0');
        }
        return out;
      };
      expect(toHex(sha1(utf8ToBytes('abc')))).assertEqual('a9993e364706816aba3e25717850c26c9cd0d89d');
      expect(toHex(sha256(utf8ToBytes('abc'))))
        .assertEqual('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(toHex(sha1(new Uint8Array(0)))).assertEqual('da39a3ee5e6b4b0d3255bfef95601890afd80709');
      expect(toHex(sha256(new Uint8Array(0))))
        .assertEqual('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    it('rsa_pkcs1_v15_matches_node_crypto_byte_for_byte', 0, () => {
      const padding = hexToBytes(RSA_PADDING_HEX);
      const cipher = rsaEncryptPkcs1(RSA_PASSWORD, RSA_MOD_HEX, RSA_EXP_HEX, padding);
      // 期望密文由 node:crypto 私钥验证可正确解出 hunter2（nodeDecryptOk=true）
      expect(bytesToHex(cipher)).assertEqual(RSA_CIPHERTEXT_HEX);
      expect(cipher.length).assertEqual(128);
    });

    it('rsa_encrypt_rejects_overlong_password', 0, () => {
      const long = 'x'.repeat(200);
      let threw = false;
      try {
        rsaEncryptPkcs1(long, RSA_MOD_HEX, RSA_EXP_HEX, undefined);
      } catch (e) {
        threw = true;
      }
      expect(threw).assertTrue();
    });

    it('rsa_handles_2048_bit_modulus', 0, () => {
      // Steam 线上返回的是 2048 位公钥（实测 modulus 512 hex / 256 字节），
      // 实现必须按模长动态推导 k；写死 1024 位会直接失败。
      const cipher = rsaEncryptPkcs1(RSA_PASSWORD, RSA2048_MOD_HEX, RSA2048_EXP_HEX,
        hexToBytes(RSA2048_PADDING_HEX));
      expect(cipher.length).assertEqual(256);
      expect(bytesToHex(cipher)).assertEqual(RSA2048_CIPHERTEXT_HEX);
    });

    it('decode_jwt_payload_reads_exp', 0, () => {
      // {"exp":1788953926,"sub":"steam"} 的 base64url
      const payload = base64Encode(utf8ToBytes('{"exp":1788953926,"sub":"steam"}'))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      const jwt = `header.${payload}.signature`;
      expect(jwtExpSeconds(jwt)).assertEqual(1788953926);
      expect(jwtExpSeconds('not-a-jwt')).assertEqual(0);
    });
  });
}
