import { describe, it, expect } from '@ohos/hypium';
import { base32Encode, decodeBase64Url, decodeGoogleAuthMigration, GA_MIGRATION_EMPTY,
  GA_MIGRATION_PARSE_FAILED, GA_MIGRATION_OK, googleAuthAlgorithm, googleAuthDigits,
  googleAuthOtpType, GoogleAuthMigrationResult, otpType, ProtoWriter, resetGoogleAuthBatch,
  TokenConfig } from 'common';

/**
 * Google Authenticator 迁移导入（otpauth-migration://）解析测试。
 *
 * 已知向量：Google Authenticator 官方格式的最小导出包
 *   CiMKCskCjMDVZlPV3OQSD015IFRlc3QgQWNjb3VudCABKAEwAhAB
 *   字节：0a230a0ac9028cc0d56653d5dce4120f4d792054657374204163636f756e742001280130021001
 * 其余用例用 ProtoWriter 现场构造，避免依赖外部生成代码。
 */

const B64_CHARS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/** 测试用 base64url 编码（生产侧只需要解码） */
function encodeBase64Url(bytes: Uint8Array): string {
  let out: string = '';
  let buffer: number = 0;
  let bits: number = 0;
  for (let i = 0; i < bytes.length; i++) {
    buffer = (buffer << 8) | bytes[i];
    bits += 8;
    while (bits >= 6) {
      bits -= 6;
      out += B64_CHARS.charAt((buffer >> bits) & 0x3f);
    }
  }
  if (bits > 0) {
    out += B64_CHARS.charAt((buffer << (6 - bits)) & 0x3f);
  }
  return out.replace(/\+/g, '-').replace(/\//g, '_');
}

function buildOtpParameters(secret: Uint8Array, name: string, issuer: string,
  algorithm: number = -1, digits: number = -1, type: number = -1, counter: number = -1): ProtoWriter {
  const w = new ProtoWriter();
  w.writeBytes(1, secret);
  if (name.length > 0) {
    w.writeString(2, name);
  }
  if (issuer.length > 0) {
    w.writeString(3, issuer);
  }
  if (algorithm >= 0) {
    w.writeInt32(4, algorithm);
  }
  if (digits >= 0) {
    w.writeInt32(5, digits);
  }
  if (type >= 0) {
    w.writeInt32(6, type);
  }
  if (counter >= 0) {
    w.writeUint64(7, BigInt(counter));
  }
  return w;
}

function buildPayload(items: ProtoWriter[], batchSize: number = -1, batchIndex: number = -1,
  batchId: number = -1): string {
  const payload = new ProtoWriter();
  for (let i = 0; i < items.length; i++) {
    payload.writeMessage(1, items[i]);
  }
  if (batchSize >= 0) {
    payload.writeInt32(3, batchSize);
    payload.writeInt32(4, batchIndex);
    payload.writeInt32(5, batchId);
  }
  return encodeBase64Url(payload.finish());
}

const SECRET_BYTES: Uint8Array = Uint8Array.from([0xc9, 0x02, 0x8c, 0xc0, 0xd5, 0x66, 0x53, 0xd5, 0xdc, 0xe4]);

export default function googleAuthMigrationTest() {
  describe('googleAuthMigrationTest', () => {
    it('decodes_known_google_authenticator_payload', 0, () => {
      const result: GoogleAuthMigrationResult =
        decodeGoogleAuthMigration('CiMKCskCjMDVZlPV3OQSD015IFRlc3QgQWNjb3VudCABKAEwAhAB');
      expect(result.errorCode).assertEqual(GA_MIGRATION_OK);
      expect(result.complete).assertTrue();
      expect(result.tokens.length).assertEqual(1);

      const token: TokenConfig = result.tokens[0];
      expect(token.TokenSecret).assertEqual('ZEBIZQGVMZJ5LXHE');
      expect(token.TokenName).assertEqual('My Test Account');
      expect(token.TokenAlgorithm).assertEqual('SHA1');
      expect(token.TokenDigits).assertEqual(6);
      expect(token.TokenType).assertEqual(otpType.TOTP);
      expect(token.TokenPeriod).assertEqual(30);
    });

    it('base64url_alphabet_and_missing_padding', 0, () => {
      // Google 的 data= 使用 URL-safe 字母表且不带 '='，标准 base64 解码器会失败
      const plusSlash: Uint8Array = decodeBase64Url('-_-_');
      expect(plusSlash.length).assertEqual(3);
      expect(plusSlash[0]).assertEqual(0xfb);
      expect(plusSlash[1]).assertEqual(0xff);
      expect(plusSlash[2]).assertEqual(0xbf);

      const longer: Uint8Array = decodeBase64Url('___-');
      expect(longer[0]).assertEqual(0xff);
      expect(longer[1]).assertEqual(0xff);
      expect(longer[2]).assertEqual(0xfe);

      // 空串与非法字符不抛异常
      expect(decodeBase64Url('').length).assertEqual(0);
      expect(decodeBase64Url('!!!!').length).assertEqual(0);
    });

    it('proto3_enum_defaults_fall_back', 0, () => {
      // 缺省（UNSPECIFIED=0）与未知值都必须回退到 SHA1 / 6 位 / TOTP，
      // 否则 digits=0 会让动态码只有 1 位
      const payload: string = buildPayload([buildOtpParameters(SECRET_BYTES, 'no-enums', '')]);
      const result: GoogleAuthMigrationResult = decodeGoogleAuthMigration(payload);
      expect(result.tokens.length).assertEqual(1);
      expect(result.tokens[0].TokenAlgorithm).assertEqual('SHA1');
      expect(result.tokens[0].TokenDigits).assertEqual(6);
      expect(result.tokens[0].TokenType).assertEqual(otpType.TOTP);
      expect(result.tokens[0].TokenIssuer).assertEqual('Unknown');

      expect(googleAuthAlgorithm(2)).assertEqual('SHA256');
      expect(googleAuthAlgorithm(3)).assertEqual('SHA512');
      expect(googleAuthAlgorithm(4)).assertEqual('MD5');
      expect(googleAuthAlgorithm(99)).assertEqual('SHA1');
      expect(googleAuthDigits(1)).assertEqual(6);
      expect(googleAuthDigits(2)).assertEqual(8);
      expect(googleAuthDigits(3)).assertEqual(7);
      expect(googleAuthDigits(99)).assertEqual(6);
      expect(googleAuthOtpType(1)).assertEqual(otpType.HOTP);
      expect(googleAuthOtpType(99)).assertEqual(otpType.TOTP);
    });

    it('hotp_counter_and_steam_issuer', 0, () => {
      const hotp: string = buildPayload([
        buildOtpParameters(SECRET_BYTES, 'hotp', 'Acme', 1, 1, 1, 7)
      ]);
      const hotpResult: GoogleAuthMigrationResult = decodeGoogleAuthMigration(hotp);
      expect(hotpResult.tokens[0].TokenType).assertEqual(otpType.HOTP);
      expect(hotpResult.tokens[0].TokenCounter).assertEqual(7);

      // Steam 条目必须转成 Steam 变体，否则会生成 6 位数字码
      const steam: string = buildPayload([buildOtpParameters(SECRET_BYTES, 'steam-user', 'Steam', 1, 1, 2)]);
      const steamResult: GoogleAuthMigrationResult = decodeGoogleAuthMigration(steam);
      expect(steamResult.tokens[0].TokenType).assertEqual(otpType.Steam);
      expect(steamResult.tokens[0].TokenDigits).assertEqual(10);
      expect(steamResult.tokens[0].TokenAlgorithm).assertEqual('SHA1');
    });

    it('batches_are_merged_in_index_order', 0, () => {
      resetGoogleAuthBatch();
      // Google 把大导出拆成多张二维码：batch_size=2，先扫 index=1 再扫 index=0
      const second: string = buildPayload([buildOtpParameters(SECRET_BYTES, 'second', '', 1, 1, 2)], 2, 1, 42);
      const first: string = buildPayload([buildOtpParameters(SECRET_BYTES, 'first', '', 1, 1, 2)], 2, 0, 42);

      const step1: GoogleAuthMigrationResult = decodeGoogleAuthMigration(second);
      expect(step1.complete).assertFalse();
      expect(step1.batchSize).assertEqual(2);
      expect(step1.batchReceived).assertEqual(1);
      expect(step1.tokens.length).assertEqual(0);

      const step2: GoogleAuthMigrationResult = decodeGoogleAuthMigration(first);
      expect(step2.complete).assertTrue();
      expect(step2.batchReceived).assertEqual(2);
      expect(step2.tokens.length).assertEqual(2);
      // 必须按 batch_index 排序，而不是扫描顺序
      expect(step2.tokens[0].TokenName).assertEqual('first');
      expect(step2.tokens[1].TokenName).assertEqual('second');

      // 收齐后批次被清空，再扫同一张不会串批
      const again: GoogleAuthMigrationResult = decodeGoogleAuthMigration(second);
      expect(again.complete).assertFalse();
      resetGoogleAuthBatch();
    });

    it('empty_and_corrupted_payloads_report_errors', 0, () => {
      // 只有 batch 字段、没有 otp_parameters
      const empty = new ProtoWriter();
      empty.writeInt32(3, 1);
      const emptyResult: GoogleAuthMigrationResult = decodeGoogleAuthMigration(encodeBase64Url(empty.finish()));
      expect(emptyResult.errorCode).assertEqual(GA_MIGRATION_EMPTY);

      // 截断的 length-delimited：长度 0xff 但后面没有数据
      const truncated: GoogleAuthMigrationResult = decodeGoogleAuthMigration('Cv8');
      expect(truncated.errorCode).assertEqual(GA_MIGRATION_PARSE_FAILED);

      const noData: GoogleAuthMigrationResult = decodeGoogleAuthMigration('');
      expect(noData.errorCode).assertEqual(GA_MIGRATION_EMPTY);
    });

    it('secret_is_base32_encoded_like_old_implementation', 0, () => {
      expect(base32Encode(SECRET_BYTES)).assertEqual('ZEBIZQGVMZJ5LXHE');
    });
  });
}
