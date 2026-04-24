import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'CloudBackupCrypto';
const DOMAIN = 0xFF00;

export enum CloudBackupCryptoMode {
  NONE = 0,
  MASTER_KEY = 1,
}

export interface CloudBackupHeader {
  version: number;
  mode: CloudBackupCryptoMode;
  salt: string;
  iv: string;
}

export interface CloudBackupPayload {
  header: CloudBackupHeader;
  payload: string;
}

export interface CloudBackupRecord {
  id: string;
  date: string;
  timestamp: number;
  tokenCount: number;
  size: number;
  encrypted: boolean;
  deviceId: string;
  deviceName: string;
}

export class CloudBackupCrypto {
  private static instance: CloudBackupCrypto | null = null;

  private constructor() {}

  static getInstance(): CloudBackupCrypto {
    if (!CloudBackupCrypto.instance) {
      CloudBackupCrypto.instance = new CloudBackupCrypto();
    }
    return CloudBackupCrypto.instance;
  }

  getMode(isMasterKeySet: boolean): CloudBackupCryptoMode {
    return isMasterKeySet ? CloudBackupCryptoMode.MASTER_KEY : CloudBackupCryptoMode.NONE;
  }

  async encrypt(plaintext: string, mode: CloudBackupCryptoMode): Promise<string> {
    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'encrypt: no encryption mode, returning plaintext');
      return plaintext;
    }

    hilog.info(DOMAIN, TAG, `encrypt: mode=${mode}, mock implementation`);
    const header: CloudBackupHeader = {
      version: 1,
      mode: mode,
      salt: 'mock_salt_' + Date.now(),
      iv: 'mock_iv_' + Date.now(),
    };
    const obj: CloudBackupPayload = {
      header: header,
      payload: plaintext,
    };
    return JSON.stringify(obj);
  }

  async decrypt(ciphertext: string, mode: CloudBackupCryptoMode): Promise<string> {
    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'decrypt: no encryption mode, returning ciphertext as-is');
      return ciphertext;
    }

    hilog.info(DOMAIN, TAG, `decrypt: mode=${mode}, mock implementation`);
    try {
      const parsed: CloudBackupPayload = JSON.parse(ciphertext) as CloudBackupPayload;
      if (parsed && parsed.payload !== undefined) {
        return parsed.payload as string;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'decrypt: failed to parse, returning as-is');
    }
    return ciphertext;
  }
}
