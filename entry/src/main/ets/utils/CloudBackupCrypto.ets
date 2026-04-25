import { hilog } from '@kit.PerformanceAnalysisKit';
import { buffer, util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

const TAG = 'CloudBackupCrypto';
const DOMAIN = 0xFF00;
const TOKEN_SEPARATOR = '.';

export enum CloudBackupCryptoMode {
  NONE = 0,
  HUAWEI_ACCOUNT = 1,
}

export interface CloudBackupTokenHeader {
  version: number;
  mode: CloudBackupCryptoMode;
  salt: string;
  iv: string;
  tokenCount: number;
  size: number;
  timestamp: number;
  deviceId: string;
  deviceName: string;
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
  location: number;
}

export class CloudBackupTokenError extends Error {
  code: number;
  constructor(message: string, code: number = 0) {
    super(message);
    this.name = 'CloudBackupTokenError';
    this.code = code;
  }
}

export class CloudBackupCrypto {
  private static instance: CloudBackupCrypto | null = null;
  private base64Helper: util.Base64Helper = new util.Base64Helper();

  private constructor() {}

  static getInstance(): CloudBackupCrypto {
    if (!CloudBackupCrypto.instance) {
      CloudBackupCrypto.instance = new CloudBackupCrypto();
    }
    return CloudBackupCrypto.instance;
  }

  getMode(isHuaweiLoggedIn: boolean): CloudBackupCryptoMode {
    return isHuaweiLoggedIn ? CloudBackupCryptoMode.HUAWEI_ACCOUNT : CloudBackupCryptoMode.NONE;
  }

  async encrypt(
    plaintext: string,
    mode: CloudBackupCryptoMode,
    key: string,
    tokenCount: number,
    timestamp: number,
    deviceId: string,
    deviceName: string,
  ): Promise<string> {
    const header: CloudBackupTokenHeader = {
      version: 1,
      mode: mode,
      salt: 'mock_salt_' + timestamp,
      iv: 'mock_iv_' + timestamp,
      tokenCount: tokenCount,
      size: plaintext.length,
      timestamp: timestamp,
      deviceId: deviceId,
      deviceName: deviceName,
    };

    let payload: string;
    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'encrypt: no encryption mode');
      payload = plaintext;
    } else {
      hilog.info(DOMAIN, TAG, `encrypt: mode=${mode}, mock implementation`);
      payload = plaintext;
    }

    const headerB64 = this.encodeBase64(JSON.stringify(header));
    const payloadB64 = this.encodeBase64(payload);
    const hash = await this.computeSha256(headerB64 + TOKEN_SEPARATOR + payloadB64);

    hilog.info(DOMAIN, TAG, `encrypt: tokenCount=${tokenCount}, size=${header.size}`);
    return headerB64 + TOKEN_SEPARATOR + payloadB64 + TOKEN_SEPARATOR + hash;
  }

  async decrypt(token: string, mode: CloudBackupCryptoMode, key: string): Promise<string> {
    const segments = token.split(TOKEN_SEPARATOR);
    if (segments.length !== 3) {
      throw new CloudBackupTokenError('Invalid token format: expected 3 segments', 1);
    }

    const headerB64 = segments[0];
    const payloadB64 = segments[1];
    const signature = segments[2];

    const isValid = await this.verifySha256(headerB64 + TOKEN_SEPARATOR + payloadB64, signature);
    if (!isValid) {
      throw new CloudBackupTokenError('Token integrity check failed', 2);
    }

    const payload = this.decodeBase64(payloadB64);

    if (mode === CloudBackupCryptoMode.NONE) {
      hilog.warn(DOMAIN, TAG, 'decrypt: no encryption mode');
      return payload;
    }

    hilog.info(DOMAIN, TAG, `decrypt: mode=${mode}, mock implementation`);
    return payload;
  }

  parseTokenHeader(token: string): CloudBackupTokenHeader {
    const segments = token.split(TOKEN_SEPARATOR);
    if (segments.length !== 3) {
      throw new CloudBackupTokenError('Invalid token format: expected 3 segments', 1);
    }
    const headerJson = this.decodeBase64(segments[0]);
    return JSON.parse(headerJson) as CloudBackupTokenHeader;
  }

  async verifyToken(token: string): Promise<boolean> {
    const segments = token.split(TOKEN_SEPARATOR);
    if (segments.length !== 3) {
      return false;
    }
    return await this.verifySha256(segments[0] + TOKEN_SEPARATOR + segments[1], segments[2]);
  }

  private encodeBase64(text: string): string {
    const uint8Array = new Uint8Array(buffer.from(text, 'utf-8').buffer);
    return this.base64Helper.encodeToStringSync(uint8Array);
  }

  private decodeBase64(base64Str: string): string {
    const uint8Array = this.base64Helper.decodeSync(base64Str);
    return buffer.from(uint8Array).toString('utf-8');
  }

  private async computeSha256(data: string): Promise<string> {
    const md = cryptoFramework.createMd('SHA256');
    const inputData = new Uint8Array(buffer.from(data, 'utf-8').buffer);
    await md.update({ data: inputData });
    const result = await md.digest();
    return buffer.from(result.data).toString('hex');
  }

  private async verifySha256(data: string, expectedHex: string): Promise<boolean> {
    const actualHex = await this.computeSha256(data);
    return actualHex === expectedHex;
  }
}
