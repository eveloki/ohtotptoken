import { bundleManager, common } from '@kit.AbilityKit';
import { distributedKVStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppPreference, EVENT_NAMES, PREF_KEYS } from './AppPreference';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { TokenConfig } from './TokenConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo as fs } from "@kit.CoreFileKit";

export class KvManager {
  //单版本分布式键值数据库
  private _kvMgr: distributedKVStore.KVManager | undefined = undefined;
  private _kvStore: distributedKVStore.SingleKVStore | undefined = undefined;
  private _kvStoreNoE: distributedKVStore.SingleKVStore | undefined = undefined;

  private static instance: KvManager;

  private constructor() {

  }

  //#region 基础部分

  public static getInstance(): KvManager {
    if (!KvManager.instance) {
      KvManager.instance = new KvManager();
    }
    return KvManager.instance;
  }

  private async initKvStore(ctx: common.UIAbilityContext): Promise<distributedKVStore.SingleKVStore[]> {
    //初始化键值数据库
    if (!this._kvMgr) {
      let bundleName = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).name;
      const kvManagerConfig: distributedKVStore.KVManagerConfig = {
        context: ctx,
        bundleName: bundleName,
      }
      this._kvMgr = distributedKVStore.createKVManager(kvManagerConfig);
    }
    let dbs =[];
    const options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: true, //no加密
      backup: false, //设置数据库文件是否备份
      autoSync: true, //自动同步
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,//表示单版本数据库。 数据不分设备，设备之间修改相同的Key会覆盖。
      securityLevel: distributedKVStore.SecurityLevel.S4, //表示数据库的安全级别为高级别，数据的泄露、篡改、破坏、销毁可能会给个人或组织导致严峻的不利影响。
    };
    const noEncryptoptions: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: false, //no加密
      backup: false, //设置数据库文件是否备份
      autoSync: true, //自动同步
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,//表示单版本数据库。 数据不分设备，设备之间修改相同的Key会覆盖。
      securityLevel: distributedKVStore.SecurityLevel.S4, //表示数据库的安全级别为高级别，数据的泄露、篡改、破坏、销毁可能会给个人或组织导致严峻的不利影响。
    };
    dbs[0]=await this._kvMgr.getKVStore('main_store', options);
    dbs[1]=await this._kvMgr.getKVStore('main_store_noE', noEncryptoptions);
    return dbs;
  }

  async initKvManager(): Promise<void> {
    let ctx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;
    if (this._kvStore) {
      return;
    }
    await this.initKvStore(ctx).then((store) => {
      this._kvStore = store[0];
      this._kvStoreNoE = store[1];
      //订阅同步完成事件
      this._kvStore.on('syncComplete', (data: [string, number][]) => {
        hilog.info(0, 'KvManager', `syncComplete ${data}`);
        ctx.eventHub.emit(EVENT_NAMES.KV_STORE_SYNC_COMPLETE);
      });

      this._kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_LOCAL, (data: distributedKVStore.ChangeNotification) => {
        hilog.info(0, 'KvManager', `dataChange callback call data: ${data}`);
        //ctx.eventHub.emit(EVENT_NAMES.KV_STORE_SYNC_COMPLETE);
      });
    }).catch((reason: BusinessError) => {
      hilog.error(reason.code, 'KvManager', reason.message);
    });
  }
  /**
   * 备份整个kv数据库到目标文件.
   *
   * @param { backupFile } 目标文件路径 需要保证目标路径是有权限的
   */
  BuckupToFile(backupFile:string)
  {
    try {
      if (fs.accessSync(backupFile)) {//如果文件存在需要删除然后重新备份
        let files = [backupFile];
        try {
          this._kvStore?.deleteBackup(files).then((data) => {
            hilog.info(0,"BuckUP",`Succeed in deleting Backup. Data:filename is ${data[0]},result is ${data[1]}.`);
          }).catch((err: BusinessError) => {
            hilog.error(err.code,"BuckUP",`Fail to delete Backup. Code:${err.code},message:${err.message}`);
          })
        } catch (e) {
          let error = e as BusinessError;
          hilog.error(error.code,"BuckUP",`An unexpected error occurred. Code:${error.code},message:${error.message}`);
        }
      }
      this._kvStore?.backup(backupFile, (err) => {
        if (err) {
          hilog.error(err.code,"BuckUP",`Fail to backup data.code:${err.code},message:${err.message}`);
        } else {
          hilog.info(0,"BuckUP",'Succeeded in backupping data.');
        }
      });
    } catch (e) {
      let error = e as BusinessError;
      hilog.error(error.code,"BuckUP",`An unexpected error occurred. Code:${error.code},message:${error.message}`);
    }
  }
  /**
   * 从备份文件中还原整个数据库.
   *
   * @param { backupFile } 目标文件路径 需要保证目标路径是有权限的
   */
  RestoreByFile(backupFile:string)
  {
    try {
      if (fs.accessSync(backupFile)) { 
        this._kvStore?.restore(backupFile, (err) => {
          if (err) {
            hilog.error(err.code,"Restore",`Fail to restore data. Code:${err.code},message:${err.message}`);
          } else {
            hilog.info(0,"Restore",'Succeeded in restoring data.');
          }
        });
      }

    } catch (e) {
      let error = e as BusinessError;
      hilog.error(error.code,"Restore",`An unexpected error occurred. Code:${error.code},message:${error.message}`);
    }
  }

  async setValue<T>(key: string, value: T): Promise<void> {
    if (this._kvStore) {
      await this._kvStore.put(key, JSON.stringify(value));
    }
  }


  async getValue<T>(key: string): Promise<T | null> {
    if (this._kvStore) {
      return this._kvStore.get(key).then((data: boolean | string | number | Uint8Array) => {
        let value: T | null = null;
        if (data) {
          value = JSON.parse(data as string) as T;
        }
        return value;
      }).catch(() => {
        return null;
      });
    }
    return null;
  }

  // 使用getEntries模拟一个可以兼容的数组 这样可以规避多设备覆盖的问题
  async getTokenArray(prefix: string): Promise<TokenConfig[]> {
    let token_array: TokenConfig[] = [];
    if (this._kvStore) {
      try {
        // load from old version
        const old_prefixKey = "$.SA_token_uuids_";
        const old_entries = await this._kvStore.getEntries(old_prefixKey);
        for (let i = 0; i < old_entries.length; i++) {
          const old_key = old_entries[i].key;
          // remove old prefix list
          this.deleteValue(old_key);
          // convert old to new token store format
          const old_token_uuid = old_key.substring(old_prefixKey.length);
          const old_token_key = "token_" + old_token_uuid;
          const old_token_value = await this.getString(old_token_key);
          const new_token_key = prefix + old_token_uuid;
          await this.setString(new_token_key, old_token_value??'');
          await this.deleteValue(old_token_key);
        }

        const entries = await this._kvStore.getEntries(prefix);
        entries.forEach((item) => {
          const json = item.value.value as string;
          if (json.length > 0) {
            token_array.push(JSON.parse(item.value.value as string) as TokenConfig);
          }
        });
      } catch (e) {
        let error = e as BusinessError;
        hilog.error(error.code, 'KvManager', `duplicated calls should be ok. code is ${error.code}, message is ${error.message}`);
      }
    }
    return token_array;
  }

  async setString(key: string, value: string): Promise<void> {
    if (this._kvStore) {
     this._kvStore.put(key, value, (err) => {
          if (err != undefined) {
          hilog.error(err.code, 'KvManager', `Failed to put.code is ${err.code},message is ${err.message}`);
           return;
         }
         hilog.info(0, 'KvManager', "Succeeded in putting");
     });
    }
  }

  async getString(key: string): Promise<string|null> {
    if (this._kvStore) {
      return this._kvStore.get(key).then((data: boolean | string | number | Uint8Array) => {
        let value: string | null = null;
        if (data) {
          value = data as string;
        }
        return value;
      }).catch(() => {
        return null;
      });
    }
    return null;
  }

  async setStringNoE(key: string, value: string): Promise<void> {
    if (this._kvStoreNoE) {
      this._kvStoreNoE.put(key, value, (err) => {
        if (err != undefined) {
          hilog.error(err.code, 'KvManager', `Failed to put.code is ${err.code},message is ${err.message}`);
          return;
        }
        hilog.info(0, 'KvManager', "Succeeded in putting");
      });
    }
  }

  async getStringNoE(key: string): Promise<string|null> {
    if (this._kvStoreNoE) {
      return this._kvStoreNoE.get(key).then((data: boolean | string | number | Uint8Array) => {
        let value: string | null = null;
        if (data) {
          value = data as string;
        }
        return value;
      }).catch(() => {
        return null;
      });
    }
    return null;
  }
  async deleteValue(key: string): Promise<void> {
    if (this._kvStore) {
      await this._kvStore.delete(key);
    }
  }

  //#endregion
  //手动同步
  async DataSync(): Promise<void> {
    if (AppPreference.getPreference(PREF_KEYS.DB_RDS_SYNC_ENABLE)) {
      try {
        let bundleInfo = AppStorage.get<bundleManager.BundleInfo>("BundleInfo");
        let dmInstance = distributedDeviceManager.createDeviceManager(bundleInfo?.name);
        let deviceInfoList: Array<distributedDeviceManager.DeviceBasicInfo> = dmInstance.getAvailableDeviceListSync();
        if (deviceInfoList.length > 0) {
          let deviceNetWorkIDList:string[] = [];
          for (let i = 0; i < deviceInfoList.length; i++) {
            deviceNetWorkIDList[i] = deviceInfoList[i].networkId as string;
          }
          // deviceInfoList.forEach(dev => {
          //   //目前仅同步
          //   // -14: PHONE。
          //   // -17: PAD。
          //   // -2607: 2in1。
          //   if (dev.deviceType === "PHONE" ||dev.deviceType === "PAD"||dev.deviceType === "2in1") {
          //     if (dev.networkId!=null) {
          //       deviceNetWorkIDList.push(dev.networkId as string );
          //     }
          //   }
          // });
          if (deviceNetWorkIDList.length > 0) {
            let formattedDate: string = Date.now().toString();
            this._kvStore?.put("LastSyncTime", formattedDate)
            const query = new distributedKVStore.Query();
            query.prefixKey("_token_uuid_");
            this._kvStore?.sync(deviceNetWorkIDList, query, distributedKVStore.SyncMode.PUSH_PULL, 1000*10);
            this._kvStoreNoE?.sync(deviceNetWorkIDList, query, distributedKVStore.SyncMode.PUSH_PULL, 1000*10);
          }
        }
      } catch (err) {
        let e: BusinessError = err as BusinessError;
        hilog.error(e.code, 'KvManager', 'getAvailableDeviceListSync errCode:' + e.code + ', errMessage:' + e.message);
      }

    }
  }
}