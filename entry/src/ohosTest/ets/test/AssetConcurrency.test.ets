import { describe, it, beforeAll, afterEach, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { util } from '@kit.ArkTS';
import { AssetSecretStore } from 'common';

const BENCH_SECRET = 'JBSWY3DPEHPK3PXP';

/** 同一 ArkTS 线程上的有限异步请求，不使用 TaskPool；每个 UUID 只分派一次。 */
async function runAssetJobs(ids: string[], concurrency: number, remove: boolean): Promise<number> {
  const store = AssetSecretStore.getInstance();
  let cursor = 0;
  let failures = 0;
  const worker = async (): Promise<void> => {
    while (cursor < ids.length) {
      const id = ids[cursor++];
      if (remove) {
        await store.removeSecret(id);
      } else if (!await store.upsertSecret(id, BENCH_SECRET)) {
        failures++;
      }
    }
  };
  const workers: Promise<void>[] = [];
  for (let i = 0; i < Math.min(concurrency, ids.length); i++) {
    workers.push(worker());
  }
  await Promise.all(workers);
  return failures;
}

export default function assetConcurrencyTest(): void {
  describe('AssetConcurrencyDeviceTest', () => {
    let ownedIds: string[] = [];
    beforeAll(async () => {
      const warmup = util.generateRandomUUID();
      ownedIds = [warmup];
      expect(await AssetSecretStore.getInstance().upsertSecret(warmup, BENCH_SECRET)).assertTrue();
      await AssetSecretStore.getInstance().removeSecret(warmup);
      ownedIds = [];
    });
    afterEach(async () => {
      await runAssetJobs(ownedIds, 1, true);
      ownedIds = [];
    });
    // 正反各一轮，减少首次初始化、温度和执行顺序对比较结果的影响。
    const limits = [1, 2, 4, 4, 2, 1];
    for (let round = 0; round < limits.length; round++) {
      const concurrency = limits[round];
      it(`asset_concurrency_${concurrency}_round_${round}`, 0, async () => {
        ownedIds = [];
        for (let i = 0; i < 64; i++) {
          ownedIds.push(util.generateRandomUUID());
        }
        const start = Date.now();
        const failures = await runAssetJobs(ownedIds, concurrency, false);
        const writeMs = Date.now() - start;
        expect(failures).assertEqual(0);
        // 全量查回校验，不能以 Promise 完成代替 ASSET 数据完整性。
        for (const id of ownedIds) {
          expect(await AssetSecretStore.getInstance().querySecret(id)).assertEqual(BENCH_SECRET);
        }
        const deleteStart = Date.now();
        await runAssetJobs(ownedIds, concurrency, true);
        const deleteMs = Date.now() - deleteStart;
        for (const id of ownedIds) {
          expect(await AssetSecretStore.getInstance().querySecret(id)).assertNull();
        }
        await abilityDelegatorRegistry.getAbilityDelegator().print(
          `ASSET_BENCH concurrency=${concurrency} round=${round} count=64 writeMs=${writeMs} deleteMs=${deleteMs}\n`);
      });
    }
  });
}
