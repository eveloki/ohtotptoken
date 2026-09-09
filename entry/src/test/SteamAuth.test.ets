import { describe, it, expect } from '@ohos/hypium';
import {
  copyTokenConfig,
  joinSecretChunks,
  maFile,
  otpType,
  sanitizedTokenForTransfer,
  splitSecretChunks,
  SteamAuth,
  steamAuthCanRevoke,
  steamAuthHasConfirmationCredentials,
  TokenConfig,
  utf8ByteLength,
} from 'common';

/**
 * Steam 凭证模型与存储辅助测试（纯逻辑，不依赖 ASSET/KV）。
 *
 * 覆盖：
 * - 旧 mafile → SteamAuth 迁移映射
 * - 手表同步前的密钥剥离（sanitizedForTransfer）
 * - copyTokenConfig 深拷贝新字段（漏拷会导致每次保存丢数据）
 * - refresh_token 分片/合并（ASSET 单条 900 字节限制）
 */

function sampleMaFile(): maFile {
  const file = new maFile();
  file.shared_secret = 'QUJDREVGR0hJSktMTU5PUA==';
  file.serial_number = '1234567890';
  file.revocation_code = 'R12345';
  file.uri = 'otpauth://totp/Steam:testuser?secret=QUJDREVGR0hJSktMTU5PUA==&issuer=Steam';
  file.server_time = 1788953926;
  file.account_name = 'testuser';
  file.token_gid = 'gid123';
  file.identity_secret = 'ZmVkY2JhOTg=';
  file.secret_1 = 'MTIzNA==';
  file.status = 2;
  file.device_id = 'android:11111111-2222-3333-4444-555555555555';
  file.fully_enrolled = true;
  return file;
}

export default function steamAuthTest() {
  describe('steamAuthTest', () => {
    it('mafile_maps_to_steam_auth', 0, () => {
      const auth = SteamAuth.fromMaFile(sampleMaFile());
      expect(auth.accountName).assertEqual('testuser');
      expect(auth.deviceId).assertEqual('android:11111111-2222-3333-4444-555555555555');
      expect(auth.serialNumber).assertEqual('1234567890');
      expect(auth.tokenGid).assertEqual('gid123');
      expect(auth.identitySecret).assertEqual('ZmVkY2JhOTg=');
      expect(auth.revocationCode).assertEqual('R12345');
      expect(auth.serverTime).assertEqual(1788953926);
      // 旧 mafile 没有 steamid / refresh_token
      expect(auth.steamid).assertEqual('');
      expect(auth.refreshToken).assertEqual('');
      expect(auth.hasConfirmationCredentials()).assertFalse();
      expect(auth.canRevoke()).assertFalse();
    });

    it('steam_auth_roundtrips_to_mafile', 0, () => {
      const auth = SteamAuth.fromMaFile(sampleMaFile());
      const back = auth.toMaFile();
      expect(back.account_name).assertEqual('testuser');
      expect(back.device_id).assertEqual('android:11111111-2222-3333-4444-555555555555');
      expect(back.identity_secret).assertEqual('ZmVkY2JhOTg=');
      expect(back.revocation_code).assertEqual('R12345');
      expect(back.uri).assertEqual(sampleMaFile().uri);
    });

    it('without_secrets_keeps_metadata_only', 0, () => {
      const auth = new SteamAuth();
      auth.accountName = 'testuser';
      auth.steamid = '76561198000000000';
      auth.deviceId = 'android:dev';
      auth.identitySecret = 'identity';
      auth.revocationCode = 'revoke';
      auth.refreshToken = 'refresh';
      auth.accessToken = 'access';

      const stripped = auth.withoutSecrets();
      expect(stripped.accountName).assertEqual('testuser');
      expect(stripped.steamid).assertEqual('76561198000000000');
      expect(stripped.deviceId).assertEqual('android:dev');
      expect(stripped.identitySecret).assertEqual('');
      expect(stripped.revocationCode).assertEqual('');
      expect(stripped.refreshToken).assertEqual('');
      expect(stripped.accessToken).assertEqual('');
      // 原对象不受影响
      expect(auth.refreshToken).assertEqual('refresh');
    });

    it('credential_capability_flags', 0, () => {
      const auth = new SteamAuth();
      auth.steamid = '76561198000000000';
      auth.deviceId = 'android:dev';
      auth.identitySecret = 'identity';
      auth.refreshToken = 'refresh';
      expect(auth.hasConfirmationCredentials()).assertTrue();

      auth.deviceId = '';
      expect(auth.hasConfirmationCredentials()).assertFalse();

      auth.deviceId = 'android:dev';
      auth.revocationCode = 'revoke';
      expect(auth.canRevoke()).assertTrue();
      auth.refreshToken = '';
      expect(auth.canRevoke()).assertFalse();
    });

    it('utf8_byte_length_counts_multibyte', 0, () => {
      expect(utf8ByteLength('abc')).assertEqual(3);
      expect(utf8ByteLength('中文')).assertEqual(6);
      expect(utf8ByteLength('a中')).assertEqual(4);
      expect(utf8ByteLength('')).assertEqual(0);
    });

    it('secret_chunks_split_and_join', 0, () => {
      const token = 'x'.repeat(2000);
      const chunks = splitSecretChunks(token, 800);
      expect(chunks.length).assertEqual(3);
      expect(chunks[0].length).assertEqual(800);
      expect(chunks[1].length).assertEqual(800);
      expect(chunks[2].length).assertEqual(400);
      expect(joinSecretChunks(chunks)).assertEqual(token);
    });

    it('secret_chunks_respect_utf8_byte_budget', 0, () => {
      // 每个汉字 3 字节：maxBytes=9 时每片最多 3 个汉字
      const value = '中'.repeat(10);
      const chunks = splitSecretChunks(value, 9);
      expect(chunks.length).assertEqual(4);
      expect(chunks[0]).assertEqual('中中中');
      expect(utf8ByteLength(chunks[0])).assertEqual(9);
      expect(joinSecretChunks(chunks)).assertEqual(value);
    });

    it('secret_chunks_empty_and_missing_middle', 0, () => {
      expect(splitSecretChunks('', 800).length).assertEqual(0);
      expect(joinSecretChunks([])).assertEqual('');
      // 中间分片缺失时必须整体作废，不能拼出错误 token
      expect(joinSecretChunks(['aaa', '', 'bbb'])).assertEqual('');
    });

    it('copy_token_config_deep_copies_steam_auth', 0, () => {
      const conf = new TokenConfig('SECRET', otpType.Steam, 'Steam', 'testuser', 'SHA1', 30, 10, 0, 0);
      const auth = new SteamAuth();
      auth.accountName = 'testuser';
      auth.refreshToken = 'refresh';
      conf.SteamAuth = auth;

      const copy = copyTokenConfig(conf);
      expect(copy.SteamAuth !== undefined).assertTrue();
      expect(copy.SteamAuth!.accountName).assertEqual('testuser');
      expect(copy.SteamAuth!.refreshToken).assertEqual('refresh');
      // 必须是独立副本：改副本不能影响原对象
      copy.SteamAuth!.accountName = 'changed';
      expect(conf.SteamAuth!.accountName).assertEqual('testuser');
    });

    it('sanitized_for_transfer_strips_secrets_keeps_code_secret', 0, () => {
      const conf = new TokenConfig('JBSWY3DPEHPK3PXP', otpType.Steam, 'Steam', 'testuser', 'SHA1', 30, 10, 0, 0);
      const auth = new SteamAuth();
      auth.accountName = 'testuser';
      auth.steamid = '76561198000000000';
      auth.identitySecret = 'identity-secret';
      auth.revocationCode = 'revoke-code';
      auth.refreshToken = 'refresh-token';
      conf.SteamAuth = auth;
      conf.SteamMaFile = sampleMaFile();

      const sanitized = conf.sanitizedForTransfer();
      // 动态码所需的 TokenSecret 必须保留（手表要显示 5 位码）
      expect(sanitized.TokenSecret).assertEqual('JBSWY3DPEHPK3PXP');
      expect(sanitized.TokenType).assertEqual(otpType.Steam);
      // Steam 凭证剥离
      expect(sanitized.SteamAuth!.identitySecret).assertEqual('');
      expect(sanitized.SteamAuth!.revocationCode).assertEqual('');
      expect(sanitized.SteamAuth!.refreshToken).assertEqual('');
      expect(sanitized.SteamAuth!.steamid).assertEqual('76561198000000000');
      // mafile 密钥剥离
      expect(sanitized.SteamMaFile!.shared_secret).assertEqual('');
      expect(sanitized.SteamMaFile!.identity_secret).assertEqual('');
      expect(sanitized.SteamMaFile!.revocation_code).assertEqual('');
      expect(sanitized.SteamMaFile!.secret_1).assertEqual('');
      expect(sanitized.SteamMaFile!.account_name).assertEqual('testuser');
      // 原对象不受影响
      expect(conf.SteamAuth!.refreshToken).assertEqual('refresh-token');
      expect(conf.SteamMaFile!.identity_secret).assertEqual('ZmVkY2JhOTg=');
    });

    it('json_plain_steam_auth_has_no_methods_but_free_helpers_work', 0, () => {
      // 复现线上闪退：KV 里的 SteamAuth 是 JSON 裸对象，没有原型方法
      const auth = new SteamAuth();
      auth.steamid = '76561198000000000';
      auth.deviceId = 'android:dev';
      auth.identitySecret = 'identity';
      auth.refreshToken = 'refresh';
      auth.revocationCode = 'revoke';

      const plain = JSON.parse(JSON.stringify(auth)) as SteamAuth;
      // 裸对象没有原型方法：调用即抛 TypeError（这正是线上闪退的原因）
      let threw = false;
      try {
        plain.hasConfirmationCredentials();
      } catch (e) {
        threw = true;
      }
      expect(threw).assertTrue();

      // 自由函数走字段判断，菜单构建期调用不会抛异常
      expect(steamAuthHasConfirmationCredentials(plain)).assertTrue();
      expect(steamAuthCanRevoke(plain)).assertTrue();

      // fromPlain 恢复原型，方法可正常调用
      const restored = SteamAuth.fromPlain(plain)!;
      expect(restored.hasConfirmationCredentials()).assertTrue();
      expect(restored.canRevoke()).assertTrue();
      expect(restored.refreshToken).assertEqual('refresh');
      expect(restored.identitySecret).assertEqual('identity');
    });

    it('copy_token_config_accepts_json_parsed_token', 0, () => {
      // 修复前：copyTokenConfig 调 token.SteamAuth.copy() → undefined is not callable
      const conf = new TokenConfig('JBSWY3DPEHPK3PXP', otpType.Steam, 'Steam', 'testuser', 'SHA1', 30, 10, 0, 0);
      const auth = new SteamAuth();
      auth.steamid = '76561198000000000';
      auth.deviceId = 'android:dev';
      auth.identitySecret = 'identity';
      auth.refreshToken = 'refresh';
      conf.SteamAuth = auth;

      const plainConf = JSON.parse(JSON.stringify(conf)) as TokenConfig;
      const copy = copyTokenConfig(plainConf);
      expect(copy.SteamAuth !== undefined).assertTrue();
      expect(copy.SteamAuth!.refreshToken).assertEqual('refresh');
      // 重建后的实例方法可用
      expect(copy.SteamAuth!.hasConfirmationCredentials()).assertTrue();
      expect(copy.SteamAuth!.withoutSecrets().refreshToken).assertEqual('');
      // 剥离后的副本仍可安全使用（自由函数：入参可以是 JSON 裸对象）
      const sanitized = sanitizedTokenForTransfer(plainConf);
      expect(sanitized.SteamAuth!.refreshToken).assertEqual('');
      expect(sanitized.TokenSecret).assertEqual('JBSWY3DPEHPK3PXP');
    });

    it('sanitized_for_backup_matches_transfer_policy', 0, () => {      const conf = new TokenConfig('JBSWY3DPEHPK3PXP', otpType.Steam, 'Steam', 'testuser', 'SHA1', 30, 10, 0, 0);
      const auth = new SteamAuth();
      auth.steamid = '76561198000000000';
      auth.identitySecret = 'identity-secret';
      auth.revocationCode = 'revoke-code';
      auth.refreshToken = 'refresh-token';
      conf.SteamAuth = auth;

      const backup = conf.sanitizedForBackup();
      // 恢复后仍要能显示动态码 → TokenSecret 必须保留
      expect(backup.TokenSecret).assertEqual('JBSWY3DPEHPK3PXP');
      // 高权限凭证不得进入备份载荷
      expect(backup.SteamAuth!.identitySecret).assertEqual('');
      expect(backup.SteamAuth!.revocationCode).assertEqual('');
      expect(backup.SteamAuth!.refreshToken).assertEqual('');
      expect(backup.SteamAuth!.steamid).assertEqual('76561198000000000');
      // 原对象不受影响
      expect(conf.SteamAuth!.refreshToken).assertEqual('refresh-token');
    });

    it('sanitized_for_transfer_leaves_non_steam_tokens_untouched', 0, () => {
      const conf = new TokenConfig('JBSWY3DPEHPK3PXP', otpType.TOTP, 'GitHub', 'user', 'SHA1', 30, 6, 0, 0);
      const sanitized = conf.sanitizedForTransfer();
      expect(sanitized.TokenSecret).assertEqual('JBSWY3DPEHPK3PXP');
      expect(sanitized.TokenIssuer).assertEqual('GitHub');
      expect(sanitized.TokenDigits).assertEqual(6);
      expect(sanitized.SteamAuth === undefined).assertTrue();
    });
  });
}
