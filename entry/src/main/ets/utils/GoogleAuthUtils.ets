import { decode_google_auth_pb } from "libotpcutils.so";
import { googleauth } from './google_auth.js'
import { otpType, TokenConfig } from "./TokenConfig";
import { JSON } from "@kit.ArkTS";
import { HMACAlgorithm } from "./TokenUtils";
import { Base64Util }  from './Base64Util';
import { base32Decode, base32Encode,stringToArray } from './TokenUtils';
import { hiTraceMeter, hilog } from '@kit.PerformanceAnalysisKit';
import Long from "long";

enum GA_Algorithm {
  ALGORITHM_UNSPECIFIED = 0,
  SHA1 = 1,
  SHA256 = 2,
  SHA512 = 3,
  MD5 = 4,
}

enum GA_DigitCount {
  DIGIT_COUNT_UNSPECIFIED = 0,
  SIX = 1,
  EIGHT = 2,
  SEVEN = 3,
}

enum GA_OtpType {
  OTP_TYPE_UNSPECIFIED = 0,
  HOTP = 1,
  TOTP = 2,
}

class GoogleAuth {
   public secret: string = '';
   public name: string = '';
   public issuer: string = '';
   public algorithm: GA_Algorithm = GA_Algorithm.SHA1;
   public digits: GA_DigitCount = GA_DigitCount.SIX;
   public type: GA_OtpType = GA_OtpType.TOTP;
   public counter: number = 30;
}

const GA_ALG_MAP: Map<GA_Algorithm, HMACAlgorithm> = new Map([
  [GA_Algorithm.ALGORITHM_UNSPECIFIED, 'SHA1' as HMACAlgorithm],
  [GA_Algorithm.SHA1, 'SHA1' as HMACAlgorithm],
  [GA_Algorithm.SHA256, 'SHA256' as HMACAlgorithm],
  [GA_Algorithm.SHA512, 'SHA512' as HMACAlgorithm],
  [GA_Algorithm.MD5, 'MD5' as HMACAlgorithm],
]);

const GA_TYPE_MAP: Map<GA_OtpType, otpType> = new Map([
  [GA_OtpType.OTP_TYPE_UNSPECIFIED, otpType.TOTP],
  [GA_OtpType.TOTP, otpType.TOTP],
  [GA_OtpType.HOTP, otpType.HOTP],
]);

const GA_DIGIT_MAP: Map<GA_DigitCount, number> = new Map([
  [GA_DigitCount.DIGIT_COUNT_UNSPECIFIED, 6],
  [GA_DigitCount.SIX, 6],
  [GA_DigitCount.EIGHT, 8],
  [GA_DigitCount.SEVEN, 7],
]);
interface  ENUM_MAPPERS_In
{
  ALGORITHM:Map<googleauth.MigrationPayload.Algorithm, GA_Algorithm>;
  DIGITS:Map<googleauth.MigrationPayload.DigitCount, GA_DigitCount>;
  TYPE:Map<googleauth.MigrationPayload.OtpType, GA_OtpType>;
}
// 映射表优化为常量对象
const ENUM_MAPPERS:ENUM_MAPPERS_In = {
  ALGORITHM: new Map<googleauth.MigrationPayload.Algorithm, GA_Algorithm>([
    [googleauth.MigrationPayload.Algorithm.SHA1, GA_Algorithm.SHA1],
    [googleauth.MigrationPayload.Algorithm.SHA256, GA_Algorithm.SHA256],
    [googleauth.MigrationPayload.Algorithm.SHA512, GA_Algorithm.SHA512],
    [googleauth.MigrationPayload.Algorithm.MD5, GA_Algorithm.MD5],
    [googleauth.MigrationPayload.Algorithm.ALGORITHM_UNSPECIFIED, GA_Algorithm.ALGORITHM_UNSPECIFIED]
  ]),

  DIGITS: new Map<googleauth.MigrationPayload.DigitCount, GA_DigitCount>([
    [googleauth.MigrationPayload.DigitCount.SIX, GA_DigitCount.SIX],
    [googleauth.MigrationPayload.DigitCount.EIGHT, GA_DigitCount.EIGHT],
    [googleauth.MigrationPayload.DigitCount.SEVEN, GA_DigitCount.SEVEN],
    [googleauth.MigrationPayload.DigitCount.DIGIT_COUNT_UNSPECIFIED, GA_DigitCount.DIGIT_COUNT_UNSPECIFIED]
  ]),

  TYPE: new Map<googleauth.MigrationPayload.OtpType, GA_OtpType>([
    [googleauth.MigrationPayload.OtpType.HOTP, GA_OtpType.HOTP],
    [googleauth.MigrationPayload.OtpType.TOTP, GA_OtpType.TOTP],
    [googleauth.MigrationPayload.OtpType.OTP_TYPE_UNSPECIFIED, GA_OtpType.OTP_TYPE_UNSPECIFIED]
  ])
};


//用于测试的谷歌认证数据
const TestGoogleProtobufData="CiMKCskCjMDVZlPV3OQSD015IFRlc3QgQWNjb3VudCABKAEwAhAB";
export async function testProtobufToJson():Promise<void>{
  //let a1=await decodeProtobufToJson(TestGoogleProtobufData);
  let a2=await decodeProtobufToJsonArkTs(TestGoogleProtobufData);
}

/**
 * 将Google Protobuf数据转换为标准JSON格式 使用原生Arkts
 * @param payload Base64编码的Protobuf数据
 * @returns 符合GoogleAuth结构的JSON字符串
 */
export async function decodeProtobufToJsonArkTs(payload: string): Promise<string> {

  try {
    // 参数校验
    if (!payload || typeof payload !== 'string') {
      throw new Error('Invalid base64 payload');
    }

    // 执行解码
    const arrayBuffer = await Base64Util.decodeSync(payload);
    const decodeMsg = googleauth.MigrationPayload.decode(arrayBuffer);

    if (!decodeMsg?.otpParameters?.length) {
      return decode_google_auth_pb(payload);
    }

    // 转换处理
    const results = decodeMsg.otpParameters.map(item => {
      let aditem=new GoogleAuth();
      aditem.secret=base32Encode(item.secret);
      aditem.name= item.name ?? '';
      aditem.issuer = item.issuer ?? '';
      aditem.algorithm= ENUM_MAPPERS.ALGORITHM.get(item.algorithm!) ?? GA_Algorithm.ALGORITHM_UNSPECIFIED;
      aditem.digits= ENUM_MAPPERS.DIGITS.get(item.digits!) ?? GA_DigitCount.DIGIT_COUNT_UNSPECIFIED;
      aditem.type =  ENUM_MAPPERS.TYPE.get(item.type!) ?? GA_OtpType.OTP_TYPE_UNSPECIFIED;
      aditem.counter= safeConvertCounter(item.counter);
      return aditem;
    });

    return JSON.stringify(results);
  } catch (error) {
    hilog.error(0x0000, 'GoogleAuth', `Decode failed: ${error.message}`);
  } finally {

  }
  //兜底 报错后还是使用Native的实现
  return decode_google_auth_pb(payload);

}

// 安全转换计数器数值
function safeConvertCounter(counter?: number|Long|null): number {
  if (counter === undefined) return 0;
  return counter instanceof Long ? counter.toNumber() : Number(counter);
}


export async function decodeProtobuf(payload: string): Promise<Array<TokenConfig>> {
  const google_auth_json: string = await decodeProtobufToJsonArkTs(payload);
  const GAs = JSON.parse(google_auth_json) as Array<GoogleAuth>;

  let result: Array<TokenConfig> = [];
  GAs.forEach((ga) => {
    let token = new TokenConfig();
    token.TokenType = GA_TYPE_MAP.get(ga.type) ?? otpType.TOTP;
    token.TokenSecret = ga.secret ?? '';
    token.TokenIssuer = ga.issuer ?? 'Unknown';
    token.TokenName = ga.name ?? 'Unknown';
    token.TokenAlgorithm = GA_ALG_MAP.get(ga.algorithm) ?? 'SHA1';
    token.TokenPeriod = 30;
    token.TokenCounter = ga.counter ?? 0;
    token.TokenDigits = GA_DIGIT_MAP.get(ga.digits) ?? 6;
    result.push(token)
  });

  return result;
}