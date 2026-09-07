import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { util, buffer } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenStore, TokenConfig, copyTokenConfig, otpType, AssetSecretStore, AppPreference, EVENT_NAMES,
  parseOtpAuthUris, TokenBackup, restoreFromBackup, encryptFile, decryptFile, base32Encode, stringToIntArray } from 'common';

/** 真机集成测试：仅操作本次随机 UUID 的令牌，不清库，不按用户发行方匹配删除。 */
export default function tokenBatchTest(): void {
  describe('TokenBatchDeviceTest', () => {
    const store = TokenStore.getInstance();
    let context: common.UIAbilityContext;
    let ownedIds: string[] = [];
    let paths: string[] = [];
    let originalTokens: string[] = [];
    let originalIds: string[] = [];
    let changes = 0;
    let singles = 0;
    const onChanged = (): void => { changes++; };
    const onSingle = (): void => { singles++; };

    const makeTokens = (count: number): TokenConfig[] => {
      const tokens: TokenConfig[] = [];
      for (let i = 0; i < count; i++) {
        const token = new TokenConfig('JBSWY3DPEHPK3PXP', otpType.TOTP, 'BatchDeviceTest', `Generated-${i}`);
        ownedIds.push(token.TokenUUID);
        tokens.push(token);
      }
      return tokens;
    };

    const ownTokens = async (): Promise<TokenConfig[]> => {
      const selected = new Set(ownedIds);
      return (await store.getTokens()).filter(token => selected.has(token.TokenUUID));
    };

    const resetEvents = (): void => {
      changes = 0;
      singles = 0;
    };

    beforeAll(async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const monitor: abilityDelegatorRegistry.AbilityMonitor = { abilityName: 'EntryAbility' };
      await delegator.addAbilityMonitor(monitor);
      await delegator.startAbility({
        bundleName: abilityDelegatorRegistry.getArguments().bundleName,
        abilityName: 'EntryAbility'
      });
      const ability = await delegator.waitAbilityMonitor(monitor, 20000);
      context = ability.context as common.UIAbilityContext;
      await delegator.removeAbilityMonitor(monitor);
      AppStorage.setOrCreate('appContext', context);
      await AppPreference.loadSettings();
      await store.initTokenStore();
      await store.LoadTokenByDataBase();
      const existing = await store.getTokens();
      originalIds = existing.map(token => token.TokenUUID);
      originalTokens = existing.map(token => JSON.stringify(token));
      context.eventHub.on(EVENT_NAMES.TOKEN_CHANGED, onChanged);
      context.eventHub.on(EVENT_NAMES.TOKEN_SINGLE_UPDATED, onSingle);
    });

    beforeEach(() => {
      ownedIds = [];
      paths = [];
      resetEvents();
    });

    afterEach(async () => {
      await store.deleteTokens(ownedIds);
      // 失败的事务也逐 UUID 确认没有遗留 KV；不输出任何真实令牌内容。
      for (const id of ownedIds.filter(id => id.length < 1024)) {
        const persisted = await store.queryToken(id);
        expect(persisted.TokenUUID === id).assertFalse();
      }
      for (const path of paths) {
        if (await fs.access(path)) {
          await fs.unlink(path);
        }
      }
      const current = await store.getTokens();
      expect(current.map(token => token.TokenUUID).join(',') === originalIds.join(',')).assertTrue();
      // 只断言布尔值，失败报告也不打印用户的原始配置/密钥。
      expect(current.map(token => JSON.stringify(token)).join('\n') === originalTokens.join('\n')).assertTrue();
    });

    afterAll(() => {
      context?.eventHub.off(EVENT_NAMES.TOKEN_CHANGED, onChanged);
      context?.eventHub.off(EVENT_NAMES.TOKEN_SINGLE_UPDATED, onSingle);
    });

    it('uri_import_skips_invalid_and_notifies_once', 0, async () => {
      const uri = 'otpauth://totp/BatchDeviceTest:URI?secret=JBSWY3DPEHPK3PXP';
      const tokens = parseOtpAuthUris([uri, 'invalid', uri, 'otpauth://totp/NoSecret']);
      ownedIds.push(...tokens.map(token => token.TokenUUID));
      expect(tokens.length).assertEqual(2);
      expect(tokens[0].TokenUUID === tokens[1].TokenUUID).assertFalse();
      await store.updateTokens(tokens);
      expect((await ownTokens()).length).assertEqual(2);
      expect(changes).assertEqual(1);
      expect(singles).assertEqual(0);
      const saved = await store.queryToken(tokens[0].TokenUUID);
      expect(saved.TokenSecret).assertEqual(tokens[0].TokenSecret);
      expect(await AssetSecretStore.getInstance().querySecret(tokens[0].TokenUUID)).assertEqual(tokens[0].TokenSecret);
    });

    it('batch_257_import_favorite_unfavorite_delete_and_reload', 0, async () => {
      const tokens = makeTokens(257);
      const start = Date.now();
      await store.updateTokens(tokens);
      const importedAt = Date.now();
      expect((await ownTokens()).length).assertEqual(257);
      expect(changes).assertEqual(1);
      resetEvents();
      await store.setTokensFavorite(ownedIds, true);
      const favoriteAt = Date.now();
      expect((await ownTokens()).every(token => token.TokenFavorite)).assertTrue();
      expect(changes).assertEqual(1);
      await store.setTokensFavorite(ownedIds, true);
      expect(changes).assertEqual(1); // no-op 不发事件
      await store.LoadTokenByDataBase();
      expect((await ownTokens()).every(token => token.TokenFavorite)).assertTrue();
      resetEvents();
      await store.setTokensFavorite(ownedIds, false);
      const unfavoriteAt = Date.now();
      expect((await ownTokens()).every(token => !token.TokenFavorite)).assertTrue();
      expect(changes).assertEqual(1);
      resetEvents();
      await store.deleteTokens(ownedIds);
      expect((await ownTokens()).length).assertEqual(0);
      expect(changes).assertEqual(1);
      expect(await AssetSecretStore.getInstance().querySecret(tokens[0].TokenUUID)).assertNull();
      hilog.info(0xFF00, 'TokenBatchPerf',
        `257 tokens: import=${importedAt - start}ms favorite=${favoriteAt - importedAt}ms ` +
        `unfavoriteAndReload=${unfavoriteAt - favoriteAt}ms delete=${Date.now() - unfavoriteAt}ms`);
    });

    it('backup_file_plain_and_encrypted_round_trip_preserves_local_favorite_rank', 0, async () => {
      const tokens = makeTokens(2);
      tokens[0].TokenFavorite = true;
      const backup = new TokenBackup(1, tokens);
      backup.groups = []; // 不写入/合并用户目录
      for (const encrypted of [false, true]) {
        const path = `${context.filesDir}/batch-test-${util.generateRandomUUID()}.${encrypted ? 'bak' : 'json'}`;
        paths.push(path);
        // 确定性构造与导出格式相同的测试文件；等待写入关闭后才执行真实导入。
        const json = JSON.stringify(backup);
        const raw = encrypted ? await encryptFile(json, 'Test-only-password-2026') : stringToIntArray(json);
        const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try {
          await fs.write(file.fd, base32Encode(raw));
        } finally {
          await fs.close(file.fd);
        }
        const restored = await restoreFromBackup(path, encrypted, 'Test-only-password-2026');
        resetEvents();
        await store.updateTokens(restored.configs);
        expect(changes).assertEqual(1);
        expect((await ownTokens()).length).assertEqual(2);
      }
      const before = await store.queryToken(tokens[0].TokenUUID);
      const modified = copyTokenConfig(before);
      modified.TokenName = 'Restored content';
      modified.RankScore = 99999;
      modified.TokenFavorite = false;
      resetEvents();
      await store.updateTokens([modified]);
      const after = await store.queryToken(tokens[0].TokenUUID);
      expect(after.RankScore).assertEqual(before.RankScore);
      expect(after.TokenFavorite).assertTrue();
      expect(after.TokenName).assertEqual('Restored content');
      expect(changes).assertEqual(1);
      expect(singles).assertEqual(0);
    });

    it('sparse_delete_reorders_only_survivors_and_ignores_missing_duplicate_ids', 0, async () => {
      const tokens = makeTokens(5);
      await store.updateTokens(tokens);
      const startRank = (await ownTokens())[0].RankScore;
      resetEvents();
      await store.deleteTokens([tokens[3].TokenUUID, tokens[1].TokenUUID, tokens[1].TokenUUID, 'missing-batch-test']);
      const remaining = await ownTokens();
      expect(remaining.map(token => token.TokenUUID).join(',')).assertEqual(
        [tokens[0].TokenUUID, tokens[2].TokenUUID, tokens[4].TokenUUID].join(','));
      expect(remaining.map(token => token.RankScore).join(',')).assertEqual([startRank, startRank + 1, startRank + 2].join(','));
      expect(changes).assertEqual(1);
      await store.LoadTokenByDataBase();
      expect((await ownTokens()).length).assertEqual(3);
    });

    it('duplicate_uuid_last_content_wins_and_new_backup_favorite_is_retained', 0, async () => {
      const tokens = makeTokens(2);
      tokens[0].TokenFavorite = true;
      const replacement = copyTokenConfig(tokens[0]);
      replacement.TokenName = 'Last duplicate';
      replacement.TokenFavorite = false;
      await store.updateTokens([tokens[0], tokens[1], replacement]);
      expect((await ownTokens()).length).assertEqual(2);
      const saved = await store.queryToken(tokens[0].TokenUUID);
      expect(saved.TokenFavorite).assertTrue();
      expect(saved.TokenName).assertEqual('Last duplicate');
      expect(changes).assertEqual(1);
    });

    it('native_second_chunk_error_rolls_back_first_chunk_without_phantom_tokens', 0, async () => {
      const tokens = makeTokens(129);
      tokens[128].TokenUUID = 'X'.repeat(2048); // 超过 KV 的 key 长度上限，第二块由真实 SDK 拒绝
      const before = (await store.getTokens()).length;
      let rejected = false;
      try {
        await store.updateTokens(tokens);
      } catch (_) {
        rejected = true;
      }
      expect(rejected).assertTrue();
      expect((await store.getTokens()).length).assertEqual(before);
      expect(changes).assertEqual(0);
      for (const token of tokens.slice(0, 128)) {
        expect((await store.queryToken(token.TokenUUID)).TokenUUID === token.TokenUUID).assertFalse();
      }
      expect(await AssetSecretStore.getInstance().querySecret(tokens[0].TokenUUID)).assertNull();
      // 上一次失败不毒化队列，随后写入仍可成功。
      await store.updateTokens([tokens[0]]);
      expect((await ownTokens()).length).assertEqual(1);
    });

    it('queued_import_favorite_delete_and_reload_do_not_lose_updates', 0, async () => {
      const tokens = makeTokens(3);
      const importing = store.updateTokens(tokens);
      const favoriting = store.setTokensFavorite(ownedIds, true);
      const deleting = store.deleteTokens([tokens[1].TokenUUID]);
      const reloading = store.LoadTokenByDataBase();
      await Promise.all([importing, favoriting, deleting, reloading]);
      const remaining = await ownTokens();
      expect(remaining.length).assertEqual(2);
      expect(remaining.every(token => token.TokenFavorite)).assertTrue();
      expect(remaining[1].RankScore).assertEqual(remaining[0].RankScore + 1);
    });

    it('secret_change_clear_and_kv_only_oversize_preserve_recovery', 0, async () => {
      const tokens = makeTokens(2);
      await store.updateTokens(tokens);
      const changed = copyTokenConfig(tokens[0]);
      changed.TokenSecret = 'GEZDGNBVGY3TQOJQ';
      await store.updateTokens([changed]);
      expect(await AssetSecretStore.getInstance().querySecret(changed.TokenUUID)).assertEqual(changed.TokenSecret);
      changed.TokenSecret = '';
      const oversized = copyTokenConfig(tokens[1]);
      oversized.TokenSecret = 'A'.repeat(901);
      await store.updateTokens([changed, oversized]);
      expect(await AssetSecretStore.getInstance().querySecret(changed.TokenUUID)).assertNull();
      expect(await AssetSecretStore.getInstance().querySecret(oversized.TokenUUID)).assertNull();
      expect((await store.queryToken(oversized.TokenUUID)).TokenSecret.length).assertEqual(901);
    });

    it('async_pbkdf2_keeps_current_and_legacy_backup_compatibility', 0, async () => {
      const password = 'Test-only-password';
      const content = '{"test":"generated-only"}';
      const encrypted = await encryptFile(content, password);
      expect(await decryptFile(encrypted, password)).assertEqual(content);
      let wrongPasswordRejected = false;
      try {
        await decryptFile(encrypted, 'wrong-password');
      } catch (_) {
        wrongPasswordRejected = true;
      }
      expect(wrongPasswordRejected).assertTrue();
      const spec: cryptoFramework.PBKDF2Spec = {
        algName: 'PBKDF2', password: password, salt: new Uint8Array(16), iterations: 10000, keySize: 16
      };
      const keyData = await cryptoFramework.createKdf('PBKDF2|SHA256').generateSecret(spec);
      const key = await cryptoFramework.createSymKeyGenerator('AES128').convertKey(keyData);
      const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
      const iv: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec', iv: { data: new Uint8Array(buffer.from('ohtotptokenaesiv').buffer) }
      };
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, iv);
      const legacy = await cipher.doFinal({ data: new util.TextEncoder().encodeInto(content) });
      expect(await decryptFile(legacy.data, password)).assertEqual(content);
    });
  });
}
