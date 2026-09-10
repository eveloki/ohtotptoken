/**
 * Steam 令牌的右键菜单动作：扫码登录、交易确认、撤销验证器。
 *
 * 统一在这里处理：
 * - access_token 获取（带缓存，见 SteamClient.generateAccessToken）
 * - 错误文案（EResult → 中文）
 * - 撤销前的二次确认
 */

import { base32Decode, delay, ScanBarCode, showSnackBar, SnackBarNotifyType, SteamAuth,
  steamAuthCanRevoke, steamAuthHasConfirmationCredentials, TokenConfig } from 'common';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { base64Encode } from '../steam/SteamCrypto';
import { currentUnixSeconds, getSteamClient } from '../steam/SteamService';
import { parseSteamQrChallenge, SteamQrChallenge } from '../steam/SteamClient';
import { SteamApiError, describeRequestError } from '../steam/SteamError';

const TAG = 'SteamActions';

/** Steam 错误 → 用户可读文案（含网络错误码映射） */
export function describeSteamError(error: Object): string {
  return describeRequestError(error);
}

/**
 * 是否具备交易确认/扫码登录所需的凭证。
 *
 * 用字段判断（自由函数）而非 `auth.hasConfirmationCredentials()`：
 * 本函数在右键菜单构建期被调用，任何异常都会导致应用被系统杀掉。
 */
export function canUseSteamAccountFeatures(token: TokenConfig): boolean {
  return steamAuthHasConfirmationCredentials(token.SteamAuth);
}

/** 是否具备撤销验证器的凭证（同样为菜单构建期调用，必须无异常） */
export function canRevokeSteamAuthenticator(token: TokenConfig): boolean {
  return steamAuthCanRevoke(token.SteamAuth);
}

/** 取 access_token（refresh_token → JWT，客户端内按 exp 缓存） */
export async function ensureSteamAccessToken(auth: SteamAuth): Promise<string> {
  return getSteamClient().generateAccessToken(BigInt(auth.steamid), auth.refreshToken,
    currentUnixSeconds());
}

/** shared_secret（本项目以 base32 存于 TokenSecret）→ base64，用于扫码登录签名 */
export function sharedSecretBase64(token: TokenConfig): string {
  return base64Encode(base32Decode(token.TokenSecret));
}

/**
 * 系统扫码页返回后应用窗口可能仍在恢复中，立即弹提示会被盖住或丢弃。
 * 等一小段时间再提示，保证「成功/失败」用户一定看得到。
 */
async function delayAfterScanner(): Promise<void> {
  await delay(350);
}

/**
 * 扫码登录：扫描 https://s.team/q/<version>/<clientId> 后向 Steam 确认。
 *
 * 提示策略（每一种结局都有明确反馈）：
 * - 扫码失败 / 取消 → 失败提示（取消不提示）
 * - 不是 Steam 登录二维码 → 失败提示
 * - 已读到二维码 → 先提示「正在确认登录…」，网络慢时用户不会以为没反应
 * - 确认成功 / 失败 → 结果提示（停留 3 秒）
 */
export async function steamApproveQrLogin(token: TokenConfig): Promise<void> {
  const auth: SteamAuth | undefined = token.SteamAuth;
  if (auth === undefined || !steamAuthHasConfirmationCredentials(auth)) {
    showSnackBar($r('app.string.steam_error_no_credentials'), SnackBarNotifyType.ERROR);
    return;
  }
  let scanned: string = '';
  try {
    scanned = await ScanBarCode();
  } catch (error) {
    const business = error as BusinessError;
    if (business.code === 1000500002) {
      return; // 用户取消扫描
    }
    hilog.error(0, TAG, `scan failed: code=${business.code} ${business.message}`);
    showSnackBar($r('app.string.toast_scan_failed'), SnackBarNotifyType.ERROR);
    return;
  }
  await delayAfterScanner();
  const challenge: SteamQrChallenge | undefined = parseSteamQrChallenge(scanned);
  if (challenge === undefined) {
    showSnackBar($r('app.string.steam_qr_invalid'), SnackBarNotifyType.ERROR);
    return;
  }
  showSnackBar($r('app.string.steam_qr_confirming'), SnackBarNotifyType.INFO);
  try {
    const accessToken: string = await ensureSteamAccessToken(auth);
    // persistence=false：按参考实现采用临时会话，不替用户默认「保持登录」
    await getSteamClient().approveQrLogin(BigInt(auth.steamid), accessToken,
      sharedSecretBase64(token), challenge, false);
    showSnackBar($r('app.string.steam_qr_success'), SnackBarNotifyType.SUCCESS, { duration: 3000 });
  } catch (error) {
    const message: string = describeSteamError(error as Object);
    hilog.error(0, TAG, `approveQrLogin failed: ${message}`);
    showSnackBar(message, SnackBarNotifyType.ERROR, { duration: 3000 });
  }
}

/**
 * 撤销验证器：二次确认后调用 RemoveAuthenticator(revocation_code)。
 *
 * @param onRevoked 撤销成功后的回调（通常用于删除本地令牌）
 */
export function steamConfirmRevoke(ui: UIContext, token: TokenConfig, onRevoked: () => void): void {
  const auth: SteamAuth | undefined = token.SteamAuth;
  if (auth === undefined || !steamAuthCanRevoke(auth)) {
    showSnackBar($r('app.string.steam_error_no_credentials'), SnackBarNotifyType.ERROR);
    return;
  }
  ui.showAlertDialog({
    title: $r('app.string.steam_revoke_confirm_title'),
    subtitle: token.TokenName,
    message: $r('app.string.steam_revoke_confirm_message'),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    primaryButton: {
      defaultFocus: false,
      value: $r('app.string.dialog_btn_cancel'),
      action: () => {
        return;
      }
    },
    secondaryButton: {
      defaultFocus: true,
      enabled: true,
      value: $r('app.string.dialog_btn_confirm'),
      fontColor: Color.Red,
      action: () => {
        steamRevokeAuthenticator(token, onRevoked);
      }
    }
  });
}

/** 执行撤销（内部方法，供确认框调用） */
export async function steamRevokeAuthenticator(token: TokenConfig, onRevoked: () => void): Promise<void> {
  const auth: SteamAuth | undefined = token.SteamAuth;
  if (auth === undefined) {
    return;
  }
  try {
    const accessToken: string = await ensureSteamAccessToken(auth);
    const result = await getSteamClient().revokeAuthenticator(BigInt(auth.steamid), accessToken,
      auth.revocationCode);
    if (!result.success) {
      throw new Error('Steam 拒绝了撤销请求，请稍后重试');
    }
    showSnackBar($r('app.string.steam_revoke_success'), SnackBarNotifyType.SUCCESS);
    onRevoked();
  } catch (error) {
    hilog.error(0, TAG, `revoke failed: ${describeSteamError(error as Object)}`);
    showSnackBar(describeSteamError(error as Object), SnackBarNotifyType.ERROR);
  }
}
