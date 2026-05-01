import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenCardStore } from '../utils/TokenCardStore';

const TAG = 'EntryFormAbility';
const DOMAIN = 0xFF00;

function emptyCardData(formId: string, formName: string): Record<string, Object> {
  const data: Record<string, Object> = {
    'hasToken': 'false',
    'formId': formId,
    'formName': formName,
  };
  for (let i = 0; i < 2; i++) {
    data[`token${i}_issuer`] = '';
    data[`token${i}_name`] = '';
    data[`token${i}_secret`] = '';
    data[`token${i}_algorithm`] = '';
    data[`token${i}_digits`] = '';
    data[`token${i}_period`] = '';
    data[`token${i}_type`] = '';
    data[`token${i}_counter`] = '';
  }
  return data;
}

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, `onAddForm, formId: ${want.parameters?.[formInfo.FormParam.IDENTITY_KEY]}`);
    const formId = String(want.parameters?.[formInfo.FormParam.IDENTITY_KEY] ?? '');
    const formName = String(want.parameters?.[formInfo.FormParam.NAME_KEY] ?? '');
    const tempFlag = want.parameters?.[formInfo.FormParam.TEMPORARY_KEY] as boolean;

    if (!tempFlag) {
      const cardStore = TokenCardStore.getInstance();
      cardStore.saveCardConfig({
        formId: formId,
        formName: formName,
        tokenUUIDs: [],
      });
    }

    let formData: Record<string, Object> = emptyCardData(formId, formName);
    return formBindingData.createFormBindingData(formData);
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onCastToNormalForm, formId: ${formId}`);
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onUpdateForm, formId: ${formId}`);
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
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, `onFormEvent, formId: ${formId}, message: ${message}`);
    try {
      const msgObj: Record<string, string> = JSON.parse(message) as Record<string, string>;
      if (msgObj.action === 'refresh') {
        this.onUpdateForm(formId);
      } else if (msgObj.action === 'increment_counter') {
        const tokenUUID = msgObj.tokenUUID;
        if (tokenUUID) {
          const cardStore = TokenCardStore.getInstance();
          cardStore.incrementTokenCounter(tokenUUID).then(() => {
            this.onUpdateForm(formId);
          }).catch((err: BusinessError) => {
            hilog.error(DOMAIN, TAG, `incrementTokenCounter failed: ${err.message}`);
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
