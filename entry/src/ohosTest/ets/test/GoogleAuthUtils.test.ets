import { describe, it, expect } from '@ohos/hypium';
import { decodeBase64Url, decodeGoogleAuthMigration, GA_MIGRATION_OK, GoogleAuthMigrationResult,
  otpType } from 'common';

/**
 * 真机（ohosTest）覆盖：Google Authenticator 迁移二维码解析。
 *
 * LocalUnit 已覆盖同样逻辑（entry/src/test/GoogleAuthMigration.test.ets），
 * 这里验证设备运行时下 common 的导出与 @kit.ArkTS 依赖行为一致。
 * 历史上这个文件是空壳，原生解码路径没有任何测试覆盖。
 */
export default function GoogleAuthUtilsTest() {
  describe('GoogleAuthUtilsTest', () => {
    it('decodes_migration_payload_on_device', 0, () => {
      const result: GoogleAuthMigrationResult =
        decodeGoogleAuthMigration('CiMKCskCjMDVZlPV3OQSD015IFRlc3QgQWNjb3VudCABKAEwAhAB');
      expect(result.errorCode).assertEqual(GA_MIGRATION_OK);
      expect(result.tokens.length).assertEqual(1);
      expect(result.tokens[0].TokenSecret).assertEqual('ZEBIZQGVMZJ5LXHE');
      expect(result.tokens[0].TokenName).assertEqual('My Test Account');
      expect(result.tokens[0].TokenType).assertEqual(otpType.TOTP);
    });

    it('base64url_decoding', 0, () => {
      const bytes: Uint8Array = decodeBase64Url('-_-_');
      expect(bytes.length).assertEqual(3);
      expect(bytes[0]).assertEqual(0xfb);
      expect(bytes[2]).assertEqual(0xbf);
    });
  });
}
