import { describe, it, expect } from '@ohos/hypium';
import { generateCardOTP } from '../main/ets/widget/utils/CardOTPUtils';

/**
 * CardOTPUtils 单元测试。
 *
 * 向量来源:RFC 4226 附录 D(secret = ASCII "12345678901234567890",
 * base32 = GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ)给出的 HOTP 截断二进制值。
 * 六位截断与 RFC 4226 附录 D 一致;counter=1 取 8 位 = 94287082,
 * 与 RFC 6238 SHA-1 @ T=59 官方向量交叉一致。
 * SHA224/256/384/512 使用 RFC 6238 附录 B 的对应长度密钥
 * (32 字节 / 64 字节 ASCII "1234567890..." 循环),
 * 期望值由 node:crypto 的 HMAC 独立算出(见 scripts/README.md 的黄金向量约定)。
 * tokenType='2' 且 counter>=0 走确定性 HOTP 路径,不依赖时钟,可在 LocalUnit 断言。
 */
const RFC_SECRET = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
/** RFC 6238 SHA-256 用 32 字节密钥 */
const RFC_SECRET_256 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
/** RFC 6238 SHA-512 用 64 字节密钥 */
const RFC_SECRET_512 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
  + 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';

export default function cardOTPUtilsTest() {
  describe('cardOTPUtilsTest', () => {
    it('rfc4226_six_digit_vectors', 0, () => {
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 0)).assertEqual('755224');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 1)).assertEqual('287082');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 2)).assertEqual('359152');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 3)).assertEqual('969429');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 4)).assertEqual('338314');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 5)).assertEqual('254676');
    });

    it('rfc6238_eight_digit_cross_check', 0, () => {
      // counter=1 即 RFC 6238 的 T=59 场景
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 8, 30, '2', 1)).assertEqual('94287082');
    });

    it('rfc6238_leading_zero_large_counter', 0, () => {
      // RFC 6238 SHA-1 @ T=1111111109(steps=37037036):8 位结果 07081804,
      // 同时覆盖前导零保留与大 counter 路径
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 8, 30, '2', 37037036)).assertEqual('07081804');
    });

    it('steam_variant_shape', 0, () => {
      // tokenType='3' 走时钟路径(TOTP),无法离线断言具体值;
      // 字符映射逻辑已由 SteamUtils.test.ets 的确定性用例覆盖,这里只断言形状
      let otp = generateCardOTP(RFC_SECRET, 'SHA1', 10, 30, '3', 1);
      expect(otp.length).assertEqual(5);
      expect(/^[23456789BCDFGHJKMNPQRTVWXY]+$/.test(otp)).assertTrue();
    });

    it('rfc6238_sha256_vector', 0, () => {
      // RFC 6238 附录 B：SHA-256 @ T=59（steps=1）→ 46119246
      expect(generateCardOTP(RFC_SECRET_256, 'SHA256', 8, 30, '2', 1)).assertEqual('46119246');
      expect(generateCardOTP(RFC_SECRET_256, 'SHA256', 6, 30, '2', 1)).assertEqual('119246');
    });

    it('rfc6238_sha512_vector', 0, () => {
      // RFC 6238 附录 B：SHA-512 @ T=59（steps=1）→ 90693936
      expect(generateCardOTP(RFC_SECRET_512, 'SHA512', 8, 30, '2', 1)).assertEqual('90693936');
      expect(generateCardOTP(RFC_SECRET_512, 'SHA512', 6, 30, '2', 1)).assertEqual('693936');
    });

    it('sha224_sha384_vectors', 0, () => {
      // SHA-224/SHA-384 不在 RFC 6238 附录 B 中，期望值由 node:crypto HMAC 独立算出
      expect(generateCardOTP(RFC_SECRET_256, 'SHA224', 6, 30, '2', 1)).assertEqual('784232');
      expect(generateCardOTP(RFC_SECRET_512, 'SHA384', 6, 30, '2', 1)).assertEqual('101971');
    });

    it('unsupported_algorithm_returns_placeholder', 0, () => {
      // 卡片进程无 cryptoFramework：SM3/MD5 返回等长占位符，
      // 绝不能再返回一个「看似正常但错误」的验证码
      expect(generateCardOTP(RFC_SECRET, 'MD5', 6, 30, '2', 1)).assertEqual('------');
      expect(generateCardOTP(RFC_SECRET, 'SM3', 8, 30, '2', 1)).assertEqual('--------');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '3', 1).length).assertEqual(5);
      expect(generateCardOTP(RFC_SECRET, 'MD5', 10, 30, '3', 1)).assertEqual('-----');
    });

    it('counter_beyond_uint32_is_not_truncated', 0, () => {
      // 旧实现用 setUint32(4, steps) 只保留低 32 位：2^32+1 与 1 结果相同。
      // 修正后按 8 字节大端编码，两者必须不同（期望值由 node:crypto 独立算出）
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 1)).assertEqual('287082');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 4294967297)).assertEqual('108930');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 8, 30, '2', 4294967297)).assertEqual('39108930');
      // 2^31 旧实现会因有符号右移而算错
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '2', 2147483648)).assertEqual('197202');
    });

    it('invalid_base32_chars_are_skipped', 0, () => {
      // 与主界面 TokenUtils.base32Decode 保持一致：跳过非法字符、
      // 容忍粘贴带入的空格/连字符（此前两侧行为不同：卡片跳过、主界面抛错显示 000000）
      expect(generateCardOTP(RFC_SECRET + '!', 'SHA1', 6, 30, '2', 1)).assertEqual('287082');
      expect(generateCardOTP('GEZD GNBV GY3T QOJQ GEZD GNBV GY3T QOJQ', 'SHA1', 6, 30, '2', 1))
        .assertEqual('287082');
      expect(generateCardOTP('GEZD-GNBV-GY3T-QOJQ-GEZD-GNBV-GY3T-QOJQ=', 'SHA1', 6, 30, '2', 1))
        .assertEqual('287082');
    });

    it('invalid_digits_and_period_fall_back', 0, () => {
      // 导入数据可能带 digits=0 / period=0，此前会算出 1 位码或除零
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 0, 30, '2', 1)).assertEqual('287082');
      expect(generateCardOTP(RFC_SECRET, 'SHA1', 6, 0, '0').length).assertEqual(6);
    });

    it('totp_path_returns_digit_sized_numeric_string', 0, () => {
      // TOTP 路径依赖 Date.now(),只断言形状:定长数字串
      let otp = generateCardOTP(RFC_SECRET, 'SHA1', 6, 30, '0');
      expect(otp.length).assertEqual(6);
      expect(/^\d+$/.test(otp)).assertTrue();
    });
  });
}
