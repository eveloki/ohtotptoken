/**
 * Steam 服务单例与时间/设备工具。
 *
 * 真实网络实现（NetworkHttpTransport）只在 UI 层使用；
 * 单测直接构造 SteamClient + 假传输层，不走这里。
 */

import { util } from '@kit.ArkTS';
import { nowUnixSeconds } from 'common';
import { NetworkHttpTransport, SteamTransport } from './SteamHttp';
import { SteamClient } from './SteamClient';

let sharedClient: SteamClient | undefined = undefined;

/** 全局 Steam 客户端（首次调用时构建真实 HTTP 传输层） */
export function getSteamClient(): SteamClient {
  if (sharedClient === undefined) {
    sharedClient = new SteamClient(new SteamTransport(new NetworkHttpTransport()));
  }
  return sharedClient;
}

/** 当前 Unix 秒（与生成动态码、确认签名共用同一时间基准） */
export function currentUnixSeconds(): number {
  return nowUnixSeconds();
}

/**
 * 生成设备标识：必须与添加验证器时写入的值一致，
 * 后续交易确认接口的 `p=` 参数要用同一个值。
 */
export function newSteamDeviceId(): string {
  return `android:${util.generateRandomUUID()}`;
}

/** 设备显示名（出现在 Steam 账号安全页） */
export const STEAM_DEVICE_NAME: string = 'OTP Token';
