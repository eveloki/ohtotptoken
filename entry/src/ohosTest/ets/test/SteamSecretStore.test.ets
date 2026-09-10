import { describe, it, beforeAll, afterEach, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { randomBytes, AppPreference, KvManager, maFile, otpType, SteamAuth, SteamSecretStore,
  TokenConfig, TokenStore } from 'common';

/**
 * Steam 凭证编排的设备测试（TokenStore × SteamSecretStore × KvManager）。
 *
 * 覆盖两条最容易造成「密钥泄漏 / 密钥丢失」的后台路径：
 *   1. 保存：KV 副本必须剥离高权限凭证（手表同步会原样序列化 KV），
 *      同时 ASSET 必须拿到完整凭证；
 *   2. 加载：旧版 maFile（KV 内明文密钥）必须迁移为 SteamAuth 并补写 ASSET。
 *
 * 存储分工（断言即文档）：
 *   - ASSET(`SteamSecretStore`)：identity_secret / revocation_code / refresh_token
 *   - KV(`TokenConfig.SteamAuth`)：steamid / deviceId / accountName 等非敏感元数据 + TokenSecret
 * 这两条依赖 ASSET + Preferences，LocalUnit 无法运行，只能在真机（ohosTest）验证。
 */

const TOKEN_PREFIX = '_token_uuid_';
const SHARED_SECRET = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const IDENTITY_SECRET = 'aWRlbnRpdHktc2VjcmV0LXRlc3Q=';
const REVOCATION_CODE = 'R12345';
const REFRESH_TOKEN = 'refresh-token-for-device-test';
const STEAM_ID = '76561198000000000';

function newSteamToken(uuid: string, name: string): TokenConfig {
  const token = new TokenConfig(SHARED_SECRET, otpType.Steam, 'Steam', name, 'SHA1', 30, 10, 0, 0);
  token.TokenUUID = uuid;
  return token;
}

function fullAuth(deviceId: string): SteamAuth {
  const auth = new SteamAuth();
  auth.accountName = 'device-test';
  auth.steamid = STEAM_ID;
  auth.deviceId = deviceId;
  auth.identitySecret = IDENTITY_SECRET;
  auth.revocationCode = REVOCATION_CODE;
  auth.refreshToken = REFRESH_TOKEN;
  return auth;
}

export default function steamSecretStoreTest(): void {
  describe('SteamSecretStoreDeviceTest', () => {
    const tkStore = TokenStore.getInstance();
    const kv = KvManager.getInstance();
    const secrets = SteamSecretStore.getInstance();
    let ownedUuids: string[] = [];

    beforeAll(async () => {
      // KV / ASSET 需要 UIAbilityContext：与 TokenBatchDeviceTest 相同的启动方式，
      // 单独按 class 过滤运行本套件时也必须能拿到上下文。
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const monitor: abilityDelegatorRegistry.AbilityMonitor = { abilityName: 'EntryAbility' };
      await delegator.addAbilityMonitor(monitor);
      await delegator.startAbility({
        bundleName: abilityDelegatorRegistry.getArguments().bundleName,
        abilityName: 'EntryAbility'
      });
      const ability = await delegator.waitAbilityMonitor(monitor, 20000);
      const context = ability.context as common.UIAbilityContext;
      await delegator.removeAbilityMonitor(monitor);
      AppStorage.setOrCreate('appContext', context);
      await AppPreference.loadSettings();
      await tkStore.initTokenStore();
      await tkStore.LoadTokenByDataBase();
    });

    afterEach(async () => {
      for (const uuid of ownedUuids) {
        await tkStore.deleteToken(uuid);
      }
      ownedUuids = [];
    });

    it('kv_write_strips_high_privilege_credentials', 0, async () => {
      const uuid = util.generateRandomUUID();
      ownedUuids.push(uuid);
      const token = newSteamToken(uuid, 'unit-kv');
      token.SteamAuth = fullAuth('android:unit-kv');

      await tkStore.updateToken(token);

      // KV 副本：高权限字段必须被剥离；TokenSecret 与非敏感元数据保留
      const raw = await kv.getValue<TokenConfig>(`${TOKEN_PREFIX}${uuid}`);
      expect(raw !== null).assertTrue();
      const rawAuth = raw!.SteamAuth;
      expect(rawAuth !== undefined).assertTrue();
      expect(rawAuth!.identitySecret ?? '').assertEqual('');
      expect(rawAuth!.revocationCode ?? '').assertEqual('');
      expect(rawAuth!.refreshToken ?? '').assertEqual('');
      expect(raw!.TokenSecret).assertEqual(SHARED_SECRET);
      // 元数据仍应保留，否则交易确认的 p= 参数与扫码登录会失效
      expect(rawAuth!.steamid ?? '').assertEqual(STEAM_ID);
      expect(rawAuth!.deviceId ?? '').assertEqual('android:unit-kv');
      expect(rawAuth!.accountName ?? '').assertEqual('device-test');

      // ASSET 侧：三项高权限凭证（steamid/deviceId 属 KV 元数据，不在 ASSET）
      const restored = new SteamAuth();
      await secrets.load(uuid, restored);
      expect(restored.identitySecret).assertEqual(IDENTITY_SECRET);
      expect(restored.revocationCode).assertEqual(REVOCATION_CODE);
      expect(restored.refreshToken).assertEqual(REFRESH_TOKEN);
      expect(restored.steamid).assertEqual('');

      // 内存对象仍保留明文凭证（UI 需要用它签名）
      const inMemory = (await tkStore.getTokens()).find(t => t.TokenUUID === uuid);
      expect(inMemory !== undefined).assertTrue();
      expect(inMemory!.SteamAuth!.identitySecret).assertEqual(IDENTITY_SECRET);
    });

    it('legacy_mafile_is_migrated_to_asset', 0, async () => {
      const uuid = util.generateRandomUUID();
      ownedUuids.push(uuid);

      // 直接写入未脱敏的旧数据，模拟历史版本留在 KV 里的 mafile
      const legacy = newSteamToken(uuid, 'unit-legacy');
      const file = new maFile();
      file.account_name = 'unit-legacy';
      file.shared_secret = SHARED_SECRET;
      file.identity_secret = IDENTITY_SECRET;
      file.revocation_code = REVOCATION_CODE;
      file.device_id = 'android:legacy';
      file.uri = `otpauth://totp/Steam:unit-legacy?secret=${SHARED_SECRET}&issuer=Steam`;
      legacy.SteamMaFile = file;
      await kv.setValue<TokenConfig>(`${TOKEN_PREFIX}${uuid}`, legacy);

      // 加载触发迁移：SteamMaFile → SteamAuth + 补写 ASSET
      await tkStore.LoadTokenByDataBase();

      const migrated = (await tkStore.getTokens()).find(t => t.TokenUUID === uuid);
      expect(migrated !== undefined).assertTrue();
      expect(migrated!.SteamAuth !== undefined).assertTrue();
      expect(migrated!.SteamAuth!.deviceId).assertEqual('android:legacy');
      expect(migrated!.SteamAuth!.accountName).assertEqual('unit-legacy');

      const restored = new SteamAuth();
      await secrets.load(uuid, restored);
      expect(restored.identitySecret).assertEqual(IDENTITY_SECRET);
      expect(restored.revocationCode).assertEqual(REVOCATION_CODE);

      // 迁移后再次保存：KV 中不得再出现明文密钥
      await tkStore.updateToken(migrated!);
      const raw = await kv.getValue<TokenConfig>(`${TOKEN_PREFIX}${uuid}`);
      expect(raw !== null).assertTrue();
      expect(raw!.SteamAuth?.identitySecret ?? '').assertEqual('');
      expect(raw!.SteamAuth?.revocationCode ?? '').assertEqual('');
      const rawFile = raw!.SteamMaFile;
      if (rawFile !== undefined) {
        expect(rawFile.identity_secret ?? '').assertEqual('');
        expect(rawFile.revocation_code ?? '').assertEqual('');
        expect(rawFile.shared_secret ?? '').assertEqual('');
      }
    });

    it('cloud_backup_random_bytes_are_csprng', 0, () => {
      // P0-3 回归网：云备份 salt/iv 曾用 Math.random()，这里断言随机源可用且不重复
      const first = randomBytes(16);
      const second = randomBytes(16);
      expect(first.length).assertEqual(16);
      expect(second.length).assertEqual(16);
      expect(first.join(',') === second.join(',')).assertFalse();
      expect(first.every((b: number) => b >= 0 && b <= 255)).assertTrue();
    });
  });
}
