import { describe, it, expect } from '@ohos/hypium';
import { BusinessError } from '@kit.BasicServicesKit';
import { otpType, SteamAuth, TokenConfig } from 'common';
import {
  canRevokeSteamAuthenticator,
  canUseSteamAccountFeatures,
  describeSteamError,
  sharedSecretBase64,
} from '../main/ets/utils/SteamActions';
import { SteamApiError } from '../main/ets/steam/SteamError';

/**
 * Steam 右键菜单动作的纯逻辑测试（不触发网络/扫描）。
 *
 * 重点：凭证能力判定决定了菜单项是否出现，判定错误会让用户看到点了就报错的入口。
 */

function steamToken(withSecrets: boolean): TokenConfig {
  const conf = new TokenConfig('MZXW6YTBOI', otpType.Steam, 'Steam', 'testuser', 'SHA1', 30, 10, 0, 0);
  const auth = new SteamAuth();
  auth.accountName = 'testuser';
  auth.steamid = '76561198000000000';
  auth.deviceId = 'android:device-1';
  if (withSecrets) {
    auth.identitySecret = 'ZmVkY2JhOTg=';
    auth.revocationCode = 'R12345';
    auth.refreshToken = 'refresh-token';
  }
  conf.SteamAuth = auth;
  return conf;
}

export default function steamActionsTest() {
  describe('steamActionsTest', () => {
    it('describe_error_prefers_steam_message', 0, () => {
      expect(describeSteamError(new SteamApiError(5, 'BeginAuthSessionViaCredentials')))
        .assertEqual('BeginAuthSessionViaCredentials: 账号或密码错误');
      expect(describeSteamError(new SteamApiError(29, 'AddAuthenticator')))
        .assertEqual('AddAuthenticator: 该账号已绑定身份验证器');
      expect(describeSteamError(new Error('自定义错误'))).assertEqual('自定义错误');
      expect(describeSteamError(new Error(''))).assertEqual('请求失败，请稍后重试');
    });

    it('describe_error_maps_network_codes', 0, () => {
      // 国内网络下最常见的两个：超时与连接被中断（TCP 可连、TLS 被阻断）
      const timeout: BusinessError = { code: 2300028, message: 'Operation timeout', name: 'BusinessError' };
      expect(describeSteamError(timeout)).assertEqual('连接 Steam 超时，请检查网络后重试');

      const noData: BusinessError = {
        code: 2300052,
        message: 'The server returned nothing (no header or data)',
        name: 'BusinessError'
      };
      expect(describeSteamError(noData))
        .assertEqual('与 Steam 的连接被中断（未收到任何数据），请检查网络后重试');

      const dns: BusinessError = {
        code: 2300006,
        message: 'Couldn\'t resolve host',
        name: 'BusinessError'
      };
      expect(describeSteamError(dns))
        .assertEqual('无法解析 Steam 域名，请检查网络或 DNS，请检查网络后重试');
    });

    it('capability_flags_gate_menu_entries', 0, () => {
      const full = steamToken(true);
      expect(canUseSteamAccountFeatures(full)).assertTrue();
      expect(canRevokeSteamAuthenticator(full)).assertTrue();

      const empty = steamToken(false);
      expect(canUseSteamAccountFeatures(empty)).assertFalse();
      expect(canRevokeSteamAuthenticator(empty)).assertFalse();

      const noAuth = new TokenConfig('MZXW6YTBOI', otpType.Steam, 'Steam', 'user', 'SHA1', 30, 10, 0, 0);
      expect(canUseSteamAccountFeatures(noAuth)).assertFalse();
      expect(canRevokeSteamAuthenticator(noAuth)).assertFalse();
    });

    it('shared_secret_base32_to_base64', 0, () => {
      // MZXW6YTBOI 是 "foobar" 的 base32；扫码登录签名需要 base64 形式的 key
      expect(sharedSecretBase64(steamToken(true))).assertEqual('Zm9vYmFy');
    });
  });
}
