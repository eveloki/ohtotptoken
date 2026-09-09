import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { emptyCardData, TokenCardStore, CardConfig } from 'common';
import { KvManager } from 'common';

const TAG = 'EntryFormAbility';
const DOMAIN = 0xFF00;

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    AppStorage.setOrCreate('appContext', this.context);
    hilog.info(DOMAIN, TAG, `onAddForm, formId: ${want.parameters?.[formInfo.FormParam.IDENTITY_KEY]}`);
    const formId = String(want.parameters?.[formInfo.FormParam.IDENTITY_KEY] ?? '');
    const formName = String(want.parameters?.[formInfo.FormParam.NAME_KEY] ?? '');
    const tempFlag = want.parameters?.[formInfo.FormParam.TEMPORARY_KEY] as boolean;

    if (!tempFlag) {
      const cardStore = TokenCardStore.getInstance();
      // 仅当卡片无已有配置时才写入空配置，避免应用更新时覆盖已保存的 token 选择
      cardStore.getCardConfig(formId).then((existing: CardConfig | null) => {
        if (!existing) {
          cardStore.saveCardConfig({
            formId: formId,
            formName: formName,
            tokenUUIDs: [],
          });
        }
      });
    }

    let formData: Record<string, Object> = emptyCardData(formId, formName);
    return formBindingData.createFormBindingData(formData);
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onCastToNormalForm, formId: ${formId}`);
  }

  onUpdateForm(formId: string): void {
    AppStorage.setOrCreate('appContext', this.context);
    hilog.info(DOMAIN, TAG, `onUpdateForm, formId: ${formId}`);
    // FormAgent 进程中 KV 数据库未初始化，需要先用 ExtensionContext 初始化
    KvManager.getInstance().initKvManagerForBackup(this.context).then(() => {
      const cardStore = TokenCardStore.getInstance();
      cardStore.generateCardData(formId).then((formData: Record<string, Object>) => {
        let formInfoData = formBindingData.createFormBindingData(formData);
        formProvider.updateForm(formId, formInfoData).then(() => {
          hilog.info(DOMAIN, TAG, 'updateForm success.');
        }).catch((error: BusinessError) => {
          hilog.error(DOMAIN, TAG, `updateForm failed. code: ${error.code}, message: ${error.message}`);
        });
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, `generateCardData failed. code: ${err.code}, message: ${err.message}`);
      });
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, `initKvManager failed: ${err.message}`);
    });
  }

  onFormEvent(formId: string, message: string): void {
    AppStorage.setOrCreate('appContext', this.context);
    hilog.info(DOMAIN, TAG, `onFormEvent, formId: ${formId}, message: ${message}`);
    try {
      const msgObj: Record<string, string> = JSON.parse(message) as Record<string, string>;
      if (msgObj.action === 'refresh') {
        this.onUpdateForm(formId);
      } else if (msgObj.action === 'increment_counter') {
        const tokenUUID = msgObj.tokenUUID;
        if (tokenUUID) {
          KvManager.getInstance().initKvManagerForBackup(this.context).then(() => {
            const cardStore = TokenCardStore.getInstance();
            cardStore.incrementTokenCounter(tokenUUID).then(() => {
              this.onUpdateForm(formId);
            }).catch((err: BusinessError) => {
              hilog.error(DOMAIN, TAG, `incrementTokenCounter failed: ${err.message}`);
            });
          }).catch((err: BusinessError) => {
            hilog.error(DOMAIN, TAG, `initKvManager failed: ${err.message}`);
          });
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `onFormEvent parse error: ${(e as BusinessError).message}`);
    }
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onRemoveForm, formId: ${formId}`);
    const cardStore = TokenCardStore.getInstance();
    cardStore.removeCardConfig(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
