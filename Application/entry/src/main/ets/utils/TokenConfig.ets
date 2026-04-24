import { HMACAlgorithm } from './TokenUtils';
import { util } from '@kit.ArkTS';
import { maFile } from './SteamUtils';

export enum otpType {
  TOTP,
  Forti,
  HOTP,
  Steam
}

export class TokenConfig {
  TokenUUID: string;
  TokenType: otpType;
  TokenSecret: string;
  TokenIssuer: string;
  TokenName: string;
  TokenAlgorithm: HMACAlgorithm;
  TokenPeriod: number;
  TokenDigits: number;
  TokenCounter: number;
  FortiToken: string;
  FortiDevID: string;
  RankScore: number;
  SteamMaFile: maFile | undefined = undefined;
  TokenIconPath: string | undefined = undefined;

  constructor(
    secret: string = '',
    type: otpType = 0,
    issuer: string = 'Issuer',
    name: string = 'Name',
    algorithm: HMACAlgorithm = 'SHA1',
    period: number = 30,
    digits: number = 6,
    counter: number = 0,
    rank: number = 0
  ) {
    this.TokenSecret = secret;
    this.TokenType = type;
    this.TokenIssuer = issuer;
    this.TokenName = name;
    this.TokenAlgorithm = algorithm;
    this.TokenPeriod = period;
    this.TokenDigits = digits;
    this.TokenCounter = counter;
    this.FortiToken = '';
    this.FortiDevID = '';
    this.TokenUUID = util.generateRandomUUID();
    this.RankScore = rank;
  }

}