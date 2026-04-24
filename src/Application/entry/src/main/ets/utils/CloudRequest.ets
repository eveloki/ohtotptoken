import cloud, { FunctionResult } from '@hw-agconnect/cloud';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'CloudRequest';
const MAX_RETRIES = 3;

class CloudRequest {
  async performRequest(trigger: string, params?: Object, times?: number): Promise<Object> {
    return new Promise((resolve, reject) => {
      hilog.info(0, TAG, `call: ${trigger}, params: ${JSON.stringify(params)}`);

      connection.hasDefaultNet((error: BusinessError, data: Object) => {
        if (!data) {
          hilog.error(0, TAG, `network disconnected: ${JSON.stringify(error)}`);
          reject({ code: -1, message: 'Network disconnected' });
          return;
        }

        cloud.callFunction({
          name: trigger,
          version: '$latest',
          timeout: 5000,
          params: params
        }).then((functionResult: FunctionResult) => {
          hilog.info(0, TAG, `call success: ${trigger}`);
          resolve(functionResult.getValue().data);
        }).catch((error: Error) => {
          if (times && times > 0) {
            hilog.error(0, TAG, `retry ${MAX_RETRIES - times + 1}: ${trigger}`);
            resolve(cloudRequest.performRequest(trigger, params, times - 1));
          } else {
            hilog.error(0, TAG, `call failed: ${JSON.stringify(error)}`);
            reject(error);
          }
        });
      });
    });
  }

  async call(trigger: string, params?: Object): Promise<Object> {
    return await this.performRequest(trigger, params, MAX_RETRIES);
  }
}

let cloudRequest = new CloudRequest();

export default cloudRequest;
