import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer, util } from '@kit.ArkTS';
import { base32Decode,stringToIntArray,stringToArray } from '../utils/TokenUtils'
import promptAction from '@ohos.promptAction'

export async function decryptFile(file_buf: Uint8Array, user_key: string): Promise<string> {
  let aes_decoder = cryptoFramework.createCipher('AES128|CBC|PKCS7');
  let aes_iv: cryptoFramework.IvParamsSpec = {
    algName: "IvParamsSpec",
    iv: { data: stringToIntArray('ohtotptokenaesiv') }
  };
  let spec: cryptoFramework.PBKDF2Spec = {
    algName: 'PBKDF2',
    password: user_key,
    salt: new Uint8Array(16),
    iterations: 10000,
    keySize: 16
  };
  let kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
  let symKeyBlob = kdf.generateSecretSync(spec);
  let aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  let aes_key = aesGenerator.convertKeySync(symKeyBlob);
  await aes_decoder.init(cryptoFramework.CryptoMode.DECRYPT_MODE, aes_key, aes_iv)
    .catch((reason: string) => {
      promptAction.showToast({ message: reason });
    });
  return new Promise<string>((resolve) => {
    aes_decoder.doFinal({ data: file_buf }).then((decryptData) => {
      let decoder = new util.TextDecoder()
      resolve(decoder.decodeToString(decryptData.data));
    }).catch((reason: BusinessError) => {
      promptAction.showToast({ message: reason.message });
    });
  });
}

export async function encryptFile(file_str: string, user_key: string): Promise<Uint8Array> {
  let aes_encoder = cryptoFramework.createCipher('AES128|CBC|PKCS7');
  let aes_iv: cryptoFramework.IvParamsSpec = {
    algName: "IvParamsSpec",
    iv: { data: stringToIntArray('ohtotptokenaesiv') }
  };
  let spec: cryptoFramework.PBKDF2Spec = {
    algName: 'PBKDF2',
    password: user_key,
    salt: new Uint8Array(16),
    iterations: 10000,
    keySize: 16
  };
  let kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
  let symKeyBlob = kdf.generateSecretSync(spec);
  let aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  let aes_key = aesGenerator.convertKeySync(symKeyBlob);
  aes_encoder.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, aes_key, aes_iv);
  return aes_encoder.doFinal({ data: new Uint8Array(buffer.from(file_str).buffer) }).then((encryptData) => {
    return encryptData.data;
  });
}
/**
 * AES128 CBC 加密字节数组 返回加密后的字节数组
 *
 */
export async function encryptUint8ArrayData(data: Uint8Array, symKeyBlob: cryptoFramework.DataBlob): Promise<Uint8Array> {
  let aes_encoder = cryptoFramework.createCipher('AES128|CBC|PKCS7');
  let aes_iv: cryptoFramework.IvParamsSpec = {
    algName: "IvParamsSpec",
    iv: { data: stringToIntArray('ohtotptokenaesiv') }
  };

  //let symKeyBlob: cryptoFramework.DataBlob = { data: new Uint8Array(buffer.from(key).buffer) };
  let aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  let aes_key = aesGenerator.convertKeySync(symKeyBlob);
  aes_encoder.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, aes_key, aes_iv);
  return aes_encoder.doFinal({ data: data }).then((encryptData) => {
    return encryptData.data;
  });
}
/**
 * AES128 CBC 解密字节数组 返回解密后的明文字节数组
 *
 */
export async function decryptUint8ArrayData(data: Uint8Array, symKeyBlob: cryptoFramework.DataBlob): Promise<Uint8Array|null> {
  let aes_decoder = cryptoFramework.createCipher('AES128|CBC|PKCS7');
  let aes_iv: cryptoFramework.IvParamsSpec = {
    algName: "IvParamsSpec",
    iv: { data: stringToIntArray('ohtotptokenaesiv') }
  };
  let aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  let aes_key = aesGenerator.convertKeySync(symKeyBlob);
  await aes_decoder.init(cryptoFramework.CryptoMode.DECRYPT_MODE, aes_key, aes_iv)
    .catch((reason: string) => {
      promptAction.showToast({ message: reason });
    });
  return new Promise<Uint8Array|null>((resolve) => {
    aes_decoder.doFinal({ data: data }).then((decryptData) => {
      resolve(decryptData.data);
    }).catch((reason: BusinessError) => {
      resolve(null);
    });
  });
}

/**
 * AES128 CBC 加密字符串 返回加密后的字节数组
 *
 */
export async function encryptStringData(data: string, symKeyBlob: cryptoFramework.DataBlob): Promise<Uint8Array> {
  let dataBlob=stringToArray(data)
  return await encryptUint8ArrayData(dataBlob,symKeyBlob);
}
export async function decryptStringData(data: Uint8Array, symKeyBlob: cryptoFramework.DataBlob): Promise<string|null> {
  try {
    let decryptData=await decryptUint8ArrayData(data,symKeyBlob);
    let decoder = new util.TextDecoder();
    let content= decoder.decodeToString(decryptData);
    return content;
  }
  catch (err)
  {
    return null;
  }


}