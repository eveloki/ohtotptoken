import { hilog } from '@kit.PerformanceAnalysisKit';
import { buffer, util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

const TAG = 'CloudBackupCrypto';
const DOMAIN = 0xFF00;
const TOKEN_SEPARATOR = '.';
const PBKDF2_ITERATIONS = 10000;
const KEY_SIZE = 16;
const MOCK_SALT_PREFIX = 'mock_salt_';

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

  private constructor() {
  }

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
    if (mode === CloudBackupCryptoMode.NONE) {
      throw new CloudBackupTokenError('Encryption requires a valid mode', 3);
    }

    const salt = this.generateRandomBytes(KEY_SIZE);
    const iv = this.generateRandomBytes(KEY_SIZE);

    const saltB64 = this.uint8ArrayToBase64(salt);
    const ivB64 = this.uint8ArrayToBase64(iv);

    const header: CloudBackupTokenHeader = {
      version: 2,
      mode: mode,
      salt: saltB64,
      iv: ivB64,
      tokenCount: tokenCount,
      size: plaintext.length,
      timestamp: timestamp,
      deviceId: deviceId,
      deviceName: deviceName,
    };

    const plaintextBytes = new Uint8Array(buffer.from(plaintext, 'utf-8').buffer);
    const ciphertext = await this.aesEncrypt(plaintextBytes, key, salt, iv);

    const headerB64 = this.encodeBase64(JSON.stringify(header));
    const payloadB64 = this.uint8ArrayToBase64(ciphertext);
    const hash = await this.computeSha256(headerB64 + TOKEN_SEPARATOR + payloadB64);

    hilog.info(DOMAIN, TAG, `encrypt: version=2, tokenCount=${tokenCount}, size=${header.size}`);
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

    const headerJson = this.decodeBase64(headerB64);
    const header = JSON.parse(headerJson) as CloudBackupTokenHeader;

    if (header.salt.startsWith(MOCK_SALT_PREFIX)) {
      hilog.info(DOMAIN, TAG, 'decrypt: legacy mock format detected, returning plaintext payload');
      const payload = this.decodeBase64(payloadB64);
      return payload;
    }

    const salt = this.base64ToUint8Array(header.salt);
    const iv = this.base64ToUint8Array(header.iv);
    const ciphertext = this.base64ToUint8Array(payloadB64);

    const plaintextBytes = await this.aesDecrypt(ciphertext, key, salt, iv);
    const result = buffer.from(plaintextBytes).toString('utf-8');

    hilog.info(DOMAIN, TAG, `decrypt: version=${header.version}, decrypted size=${result.length}`);
    return result;
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

  isMockFormat(token: string): boolean {
    try {
      const header = this.parseTokenHeader(token);
      return header.salt.startsWith(MOCK_SALT_PREFIX);
    } catch (e) {
      return false;
    }
  }

  private async aesEncrypt(
    plaintext: Uint8Array,
    password: string,
    salt: Uint8Array,
    iv: Uint8Array,
  ): Promise<Uint8Array> {
    const symKey = await this.deriveKey(password, salt);
    const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
    const ivSpec: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: { data: iv },
    };
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, ivSpec);
    const result = await cipher.doFinal({ data: plaintext });
    return result.data;
  }

  private async aesDecrypt(
    ciphertext: Uint8Array,
    password: string,
    salt: Uint8Array,
    iv: Uint8Array,
  ): Promise<Uint8Array> {
    const symKey = await this.deriveKey(password, salt);
    const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
    const ivSpec: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: { data: iv },
    };
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, ivSpec);
    const result = await cipher.doFinal({ data: ciphertext });
    return result.data;
  }

  private async deriveKey(password: string, salt: Uint8Array): Promise<cryptoFramework.SymKey> {
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: password,
      salt: salt,
      iterations: PBKDF2_ITERATIONS,
      keySize: KEY_SIZE,
    };
    const kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
    const symKeyBlob = await kdf.generateSecret(spec);
    const aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
    return aesGenerator.convertKey(symKeyBlob);
  }

  private generateRandomBytes(length: number): Uint8Array {
    const arr = new Uint8Array(length);
    for (let i = 0; i < length; i++) {
      arr[i] = Math.floor(Math.random() * 256) as number;
    }
    return arr;
  }

  private encodeBase64(text: string): string {
    const uint8Array = new Uint8Array(buffer.from(text, 'utf-8').buffer);
    return this.base64Helper.encodeToStringSync(uint8Array);
  }

  private decodeBase64(base64Str: string): string {
    const uint8Array = this.base64Helper.decodeSync(base64Str);
    return buffer.from(uint8Array).toString('utf-8');
  }

  private uint8ArrayToBase64(data: Uint8Array): string {
    return this.base64Helper.encodeToStringSync(data);
  }

  private base64ToUint8Array(base64Str: string): Uint8Array {
    return this.base64Helper.decodeSync(base64Str);
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
