/**
 * Steam 登录 + 验证器添加/迁移的引导流程（内嵌在 AddSteamTokenPage 中，不新增路由）。
 *
 * 步骤：
 *   LOGIN            输入账号密码 → BeginAuthSessionViaCredentials
 *   MFA_CODE         输入设备码/邮箱码 → UpdateAuthSessionWithSteamGuardCode
 *   MFA_WAIT         等待另一设备/邮件确认 → 按服务端 interval 轮询
 *   LINK             点击添加/迁移 → AddAuthenticator（DuplicateRequest ⇒ 转迁移）
 *   TRANSFER_CONFIRM 迁移二次确认（会顶掉旧设备）
 *   ACTIVATION       添加路径：短信/邮件激活码 → FinalizeAddAuthenticator
 *   TRANSFER_SMS     迁移路径：短信码 → RemoveAuthenticatorViaChallengeContinue
 *   DONE             回调 onCompleted 交给页面保存
 *
 * 安全：
 * - 密码只存在 @Local，登录发起后立即清空，不写日志、不落盘
 * - 离开组件时清空所有敏感状态
 */

import { delay, resourceText, TokenConfig, SteamAuth } from 'common';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AddTokenActionButton,
  AddTokenSectionTitle,
  AddTokenTextField,
  ADD_TOKEN_SECTION_PADDING,
  ADD_TOKEN_SECTION_RADIUS,
} from './AddTokenForm';
import {
  SteamAuthSession,
  SteamClient,
} from '../steam/SteamClient';
import { SteamApiError, describeRequestError } from '../steam/SteamError';
import { base64Encode } from '../steam/SteamCrypto';
import { steamGuardCode, SteamCodeGenerator } from '../steam/SteamCode';
import { currentUnixSeconds, getSteamClient, newSteamDeviceId, STEAM_DEVICE_NAME } from '../steam/SteamService';
import {
  activationCodeIsSms,
  buildAuthFromAdd,
  buildAuthFromTransfer,
  buildSteamTokenConfig,
  confirmationNeedsCode,
  extractSecretFromUri,
  finalizeUntilSuccess,
  secretBytesToBase32,
} from '../steam/SteamFlow';import {
  CTwoFactor_AddAuthenticator_Response,
  CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response,
  CTwoFactor_Status_Response,
} from '../steam/proto/SteamMessages';

const STEP_LOGIN: number = 0;
const STEP_MFA_CODE: number = 1;
const STEP_MFA_WAIT: number = 2;
const STEP_LINK: number = 3;
const STEP_TRANSFER_CONFIRM: number = 4;
const STEP_ACTIVATION: number = 5;
const STEP_TRANSFER_SMS: number = 6;
const STEP_DONE: number = 7;

/** Steam 账号明细页：绑定/验证手机号在此完成 */
const STEAM_ACCOUNT_URL: string = 'https://store.steampowered.com/account/';

function describeError(error: Object): string {
  return describeRequestError(error);
}

/**
 * 携带字符串资源的错误。
 *
 * 流程内部抛出的错误要显示给用户，文案必须随系统语言变化；
 * 这里只带 Resource，由组件在渲染期解析成当前语言。
 */
class SteamFlowError extends Error {
  readonly res: Resource | undefined;

  constructor(message: string, res: Resource | undefined = undefined) {
    super(message);
    this.res = res;
  }
}

@ComponentV2
export struct SteamLoginFlow {
  /** 取消：回到手动/mafile 表单 */
  @Param onCancel: () => void = () => {};
  /** 完成：把构建好的令牌交给页面保存 */
  @Param onCompleted: (conf: TokenConfig) => Promise<void> = async () => {};
  /** 在应用内打开网页（用于引导用户去 Steam 绑定手机号） */
  @Param onOpenUrl: (url: string) => void = () => {};
  /** 编辑已有令牌时的排序分值 */
  @Param rank: number = 0;
  /** 预填账号名（已绑定令牌重新登录时免去重新输入） */
  @Param initialAccountName: string = '';

  @Local step: number = STEP_LOGIN;
  @Local accountName: string = '';
  @Local password: string = '';
  @Local code: string = '';
  @Local busy: boolean = false;
  @Local statusText: string = '';
  @Local errorText: string = '';
  /** 是否展示「去 Steam 绑定手机号」入口（迁移条件不满足时置为 true） */
  @Local phoneHelpVisible: boolean = false;

  private client: SteamClient = getSteamClient();
  private session: SteamAuthSession | undefined = undefined;
  private accessToken: string = '';
  private deviceId: string = '';
  private confirmationType: number = 0;
  private addResponse: CTwoFactor_AddAuthenticator_Response | undefined = undefined;
  private codeGen: SteamCodeGenerator = new SteamCodeGenerator();

  aboutToAppear(): void {
    if (this.accountName.length === 0 && this.initialAccountName.length > 0) {
      this.accountName = this.initialAccountName;
    }
  }

  aboutToDisappear(): void {
    // 流程结束/取消后清空所有敏感状态：明文密码、验证码、refresh/access token、
    // 以及 AddAuthenticator 响应里的 shared_secret / identity_secret
    this.password = '';
    this.code = '';
    this.accessToken = '';
    this.session = undefined;
    this.addResponse = undefined;
    this.codeGen.reset();
  }

  private fail(error: Object): void {
    if (error instanceof SteamFlowError) {
      const flow = error as SteamFlowError;
      if (flow.res !== undefined) {
        this.errorText = this.textOf(flow.res);
        this.busy = false;
        return;
      }
    }
    this.errorText = describeError(error);
    this.busy = false;
  }

  /** 资源 → 当前语言文案（统一走 common/UiUtils.resourceText） */
  private textOf(res: Resource): string {
    return resourceText(this.getUIContext(), res);
  }

  /** 设置进度文案（资源随系统语言切换） */
  private setStatus(res: Resource): void {
    this.statusText = this.textOf(res);
  }

  // ------------------------------------------------------------ 登录

  private async doLogin(): Promise<void> {
    if (this.accountName.trim().length === 0 || this.password.length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.setStatus($r('app.string.steam_status_logging_in'));
    const account: string = this.accountName.trim();
    const password: string = this.password;
    try {
      const session: SteamAuthSession = await this.client.beginAuthSession(account, password,
        STEAM_DEVICE_NAME);
      // 登录成功后才清空明文密码：网络抖动导致失败时用户可直接重试，不必重新输入
      this.password = '';
      this.session = session;
      if (session.steamid === 0n) {
        this.statusText = '';
        this.fail(new SteamFlowError('', $r('app.string.steam_err_bad_credentials')));
        return;
      }
      this.deviceId = newSteamDeviceId();
      this.confirmationType = session.preferredConfirmation() === undefined ? 0
        : session.preferredConfirmation()!.confirmationType;
      if (session.preferredConfirmation() === undefined) {
        this.statusText = '';
        this.fail(new SteamFlowError('', $r('app.string.steam_err_twofactor_disabled')));
        return;
      }
      if (confirmationNeedsCode(this.confirmationType)) {
        this.statusText = '';
        this.busy = false;
        this.step = STEP_MFA_CODE;
        return;
      }
      // 需要用户在其他设备/邮箱确认
      this.step = STEP_MFA_WAIT;
      this.setStatus($r('app.string.steam_status_wait_confirm'));
      await this.waitForAuthorization();
    } catch (error) {
      this.statusText = '';
      this.fail(error as Object);
    }
  }

  private async waitForAuthorization(): Promise<void> {
    const session: SteamAuthSession | undefined = this.session;
    if (session === undefined) {
      this.fail(new SteamFlowError('', $r('app.string.steam_err_session_expired')));
      return;
    }
    try {
      await this.client.pollUntilAuthorized(session, 20);
      this.statusText = '';
      this.busy = false;
      this.step = STEP_LINK;
    } catch (error) {
      this.statusText = '';
      this.fail(error as Object);
    }
  }

  private async doSubmitMfaCode(): Promise<void> {
    const session: SteamAuthSession | undefined = this.session;
    if (session === undefined || this.code.trim().length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.setStatus($r('app.string.steam_status_verifying'));
    const code: string = this.code.trim();
    this.code = '';
    try {
      await this.client.submitSteamGuardCode(session, code, this.confirmationType);
      await this.client.pollUntilAuthorized(session, 20);
      this.statusText = '';
      this.busy = false;
      this.step = STEP_LINK;
    } catch (error) {
      this.statusText = '';
      this.fail(error as Object);
    }
  }

  // ------------------------------------------------------------ 添加 / 迁移

  private async ensureAccessToken(): Promise<string> {
    const session: SteamAuthSession | undefined = this.session;
    if (session === undefined) {
      throw new SteamFlowError('', $r('app.string.steam_err_session_expired'));
    }
    if (this.accessToken.length > 0) {
      return this.accessToken;
    }
    this.accessToken = await this.client.generateAccessToken(session.steamid, session.refreshToken,
      currentUnixSeconds());
    return this.accessToken;
  }

  private async doAddAuthenticator(): Promise<void> {
    const session: SteamAuthSession | undefined = this.session;
    if (session === undefined || this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.setStatus($r('app.string.steam_status_adding'));
    try {
      const token: string = await this.ensureAccessToken();
      const response: CTwoFactor_AddAuthenticator_Response =
        await this.client.addAuthenticator(session.steamid, token, this.deviceId);
      this.addResponse = response;
      this.codeGen.syncServerTime(Number(response.serverTime), currentUnixSeconds());
      this.confirmationType = response.confirmType;
      this.statusText = '';
      this.busy = false;
      this.step = STEP_ACTIVATION;
    } catch (error) {
      const apiError = error as SteamApiError;
      if (apiError instanceof SteamApiError && (apiError as SteamApiError).isDuplicateRequest()) {
        this.statusText = '';
        this.busy = false;
        this.step = STEP_TRANSFER_CONFIRM;
        return;
      }
      this.statusText = '';
      this.fail(error as Object);
    }
  }

  private async doStartTransfer(): Promise<void> {
    const session: SteamAuthSession | undefined = this.session;
    if (session === undefined || this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.setStatus($r('app.string.steam_status_transfer_request'));
    try {
      const token: string = await this.ensureAccessToken();
      await this.client.startTransferAuthenticator(session.steamid, token);
      this.statusText = '';
      this.busy = false;
      this.step = STEP_TRANSFER_SMS;
    } catch (error) {
      this.statusText = '';
      this.errorText = await this.describeTransferFailure(error as Object, session);
      hilog.error(0, 'SteamLoginFlow', `startTransfer failed: ${this.errorText}`);
      this.busy = false;
    }
  }

  /**
   * 迁移启动失败时的诊断信息。
   *
   * `RemoveAuthenticatorViaChallengeStart` 返回 EResult 2(Fail) 时，常见原因是
   * 账号未绑定手机号——该接口要靠短信验证码完成迁移。
   * 判定依据：紧随其后的 QueryStatus 用的是同一个 access_token 且成功，
   * 说明令牌有效，失败来自账号侧条件而非鉴权。
   */
  private async describeTransferFailure(error: Object, session: SteamAuthSession): Promise<string> {
    let message: string = describeError(error);
    const apiError = error as SteamApiError;
    if (apiError instanceof SteamApiError && (apiError as SteamApiError).eresult === 2) {
      this.phoneHelpVisible = true;
      message += `\n${this.textOf($r('app.string.steam_err_transfer_phone'))}`;
    }
    // 账号状态明细只进日志：界面上给用户看的是可操作的建议，不是诊断字段
    try {
      const token: string = await this.ensureAccessToken();
      const status: CTwoFactor_Status_Response = await this.client.queryStatus(session.steamid, token);
      hilog.info(0, 'SteamLoginFlow', `transfer status: state=${status.state},`
        + ` authenticator_type=${status.authenticatorType},`
        + ` steamguard_scheme=${status.steamguardScheme}, email_validated=${status.emailValidated},`
        + ` authenticator_allowed=${status.authenticatorAllowed},`
        + ` allow_external_authenticator=${status.allowExternalAuthenticator},`
        + ` time_created=${status.timeCreated},`
        + ` revocation_attempts_remaining=${status.revocationAttemptsRemaining}`);
    } catch (statusError) {
      hilog.warn(0, 'SteamLoginFlow', `queryStatus failed: ${describeError(statusError as Object)}`);
    }
    return message;
  }

  private async doSubmitActivationCode(): Promise<void> {
    const session: SteamAuthSession | undefined = this.session;
    const add: CTwoFactor_AddAuthenticator_Response | undefined = this.addResponse;
    if (session === undefined || add === undefined || this.code.trim().length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.setStatus($r('app.string.steam_status_finalizing'));
    const activation: string = this.code.trim();
    try {
      const token: string = await this.ensureAccessToken();
      const sharedSecretBase64: string = base64Encode(add.sharedSecret);
      // want_more=true 表示验证码时间步未对齐，需用新码重试（finalizeUntilSuccess 内部处理）
      const finished: boolean = await finalizeUntilSuccess({
        attempt: (code: string, serverTimeSeconds: number) =>
          this.client.finalizeAddAuthenticator(session.steamid, token, code, serverTimeSeconds, activation),
        codeForServerTime: (serverTimeSeconds: number) =>
          steamGuardCode(sharedSecretBase64, serverTimeSeconds),
        currentServerTimeSeconds: () => currentUnixSeconds() + this.codeGen.getOffsetSeconds(),
        sleep: (ms: number) => delay(ms),
      }, 5);
      if (!finished) {
        throw new SteamFlowError('', $r('app.string.steam_err_finalize_incomplete'));
      }
      const auth: SteamAuth = buildAuthFromAdd(add, this.accountName.trim(),
        session.steamid.toString(), this.deviceId, session.refreshToken, token);
      const secret: string = extractSecretFromUri(add.uri);
      const fallback: string = secretBytesToBase32(add.sharedSecret);
      await this.complete(auth, secret.length > 0 ? secret : fallback, auth.accountName);
    } catch (error) {
      this.statusText = '';
      this.fail(error as Object);
    }
  }

  private async doSubmitTransferSms(): Promise<void> {
    const session: SteamAuthSession | undefined = this.session;
    if (session === undefined || this.code.trim().length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.setStatus($r('app.string.steam_status_transferring'));
    const sms: string = this.code.trim();
    try {
      const token: string = await this.ensureAccessToken();
      const response: CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response =
        await this.client.submitTransferSmsCode(session.steamid, token, sms);
      if (!response.success || response.replacementToken === undefined) {
        throw new SteamFlowError('', $r('app.string.steam_err_transfer_code'));
      }
      const replacement = response.replacementToken;
      const auth: SteamAuth = buildAuthFromTransfer(replacement, this.accountName.trim(),
        session.steamid.toString(), this.deviceId, session.refreshToken, token);
      const secret: string = extractSecretFromUri(replacement.uri);
      const fallback: string = secretBytesToBase32(replacement.sharedSecret);
      await this.complete(auth, secret.length > 0 ? secret : fallback, auth.accountName);
    } catch (error) {
      this.statusText = '';
      this.fail(error as Object);
    }
  }

  private async complete(auth: SteamAuth, secretBase32: string, displayName: string): Promise<void> {
    if (secretBase32.length === 0) {
      this.fail(new SteamFlowError('', $r('app.string.steam_err_no_secret')));
      return;
    }
    const conf: TokenConfig = buildSteamTokenConfig(auth, secretBase32, 'Steam', displayName, this.rank);
    this.step = STEP_DONE;
    this.setStatus($r('app.string.steam_status_success'));
    this.busy = false;
    await this.onCompleted(conf);
  }

  build() {
    Column({ space: 14 }) {
      if (this.step === STEP_LOGIN) {
        AddTokenSectionTitle({ text: $r('app.string.steam_login_section') })
        Text($r('app.string.steam_login_intro'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
        AddTokenTextField({
          label: $r('app.string.steam_login_account'),
          value: this.accountName,
          inputType: InputType.Normal,
          onChange: (value: string) => this.accountName = value
        })
        AddTokenTextField({
          label: $r('app.string.steam_login_password'),
          value: this.password,
          inputType: InputType.Password,
          onChange: (value: string) => this.password = value
        })
        Text($r('app.string.steam_login_password_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
        AddTokenActionButton({
          text: $r('app.string.steam_login_action'),
          loading: this.busy,
          buttonEnabled: !this.busy && this.accountName.trim().length > 0 && this.password.length > 0,
          action: () => this.doLogin()
        })
      } else if (this.step === STEP_MFA_CODE) {
        AddTokenSectionTitle({ text: $r('app.string.steam_mfa_section') })
        Text(this.confirmationType === 3 ? $r('app.string.steam_mfa_device_code_hint')
          : $r('app.string.steam_mfa_email_code_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
        AddTokenTextField({
          label: $r('app.string.steam_mfa_code'),
          value: this.code,
          maxLength: 8,
          onChange: (value: string) => this.code = value
        })
        AddTokenActionButton({
          text: $r('app.string.steam_mfa_submit'),
          loading: this.busy,
          buttonEnabled: !this.busy && this.code.trim().length > 0,
          action: () => this.doSubmitMfaCode()
        })
      } else if (this.step === STEP_MFA_WAIT) {
        AddTokenSectionTitle({ text: $r('app.string.steam_mfa_section') })
        Text($r('app.string.steam_mfa_wait_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
      } else if (this.step === STEP_LINK) {
        AddTokenSectionTitle({ text: $r('app.string.steam_link_section') })
        Text(this.accountName.trim().length > 0 ? this.accountName.trim() : 'Steam')
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
        Text($r('app.string.steam_link_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
        AddTokenActionButton({
          text: $r('app.string.steam_link_action'),
          loading: this.busy,
          buttonEnabled: !this.busy,
          action: () => this.doAddAuthenticator()
        })
      } else if (this.step === STEP_TRANSFER_CONFIRM) {
        AddTokenSectionTitle({ text: $r('app.string.steam_transfer_section') })
        Text($r('app.string.steam_transfer_warning'))
          .fontSize(13).lineHeight(20).fontColor($r('sys.color.warning')).width('100%')
        Text($r('app.string.steam_transfer_phone_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
        Text($r('app.string.steam_bind_phone_action'))
          .fontSize(14)
          .fontColor($r('sys.color.font_emphasize'))
          .decoration({ type: TextDecorationType.Underline, color: $r('sys.color.font_emphasize') })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => this.onOpenUrl(STEAM_ACCOUNT_URL))
        AddTokenActionButton({
          text: $r('app.string.steam_transfer_action'),
          loading: this.busy,
          buttonEnabled: !this.busy,
          action: () => this.doStartTransfer()
        })
      } else if (this.step === STEP_ACTIVATION) {
        AddTokenSectionTitle({ text: $r('app.string.steam_activation_section') })
        Text(activationCodeIsSms(this.confirmationType) ? $r('app.string.steam_activation_sms_hint')
          : $r('app.string.steam_activation_email_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
        AddTokenTextField({
          label: $r('app.string.steam_activation_code'),
          value: this.code,
          maxLength: 10,
          onChange: (value: string) => this.code = value
        })
        AddTokenActionButton({
          text: $r('app.string.steam_activation_submit'),
          loading: this.busy,
          buttonEnabled: !this.busy && this.code.trim().length > 0,
          action: () => this.doSubmitActivationCode()
        })
      } else if (this.step === STEP_TRANSFER_SMS) {
        AddTokenSectionTitle({ text: $r('app.string.steam_transfer_sms_section') })
        Text($r('app.string.steam_transfer_sms_hint'))
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_tertiary')).width('100%')
        AddTokenTextField({
          label: $r('app.string.steam_activation_code'),
          value: this.code,
          maxLength: 10,
          onChange: (value: string) => this.code = value
        })
        AddTokenActionButton({
          text: $r('app.string.steam_transfer_sms_submit'),
          loading: this.busy,
          buttonEnabled: !this.busy && this.code.trim().length > 0,
          action: () => this.doSubmitTransferSms()
        })
      } else {
        AddTokenSectionTitle({ text: $r('app.string.steam_done_section') })
        Text(this.statusText)
          .fontSize(14).lineHeight(20).fontColor($r('sys.color.font_primary')).width('100%')
      }

      if (this.statusText.length > 0 && this.step !== STEP_DONE) {
        Text(this.statusText)
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.font_secondary')).width('100%')
      }
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(12).lineHeight(18).fontColor($r('sys.color.warning')).width('100%')
      }
      if (this.phoneHelpVisible && this.step !== STEP_TRANSFER_CONFIRM) {
        // 迁移条件不满足时给出直达入口，避免用户自己找绑定手机号的路径
        Text($r('app.string.steam_bind_phone_action'))
          .fontSize(14)
          .fontColor($r('sys.color.font_emphasize'))
          .decoration({ type: TextDecorationType.Underline, color: $r('sys.color.font_emphasize') })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => this.onOpenUrl(STEAM_ACCOUNT_URL))
      }
      if (this.step !== STEP_DONE) {
        AddTokenActionButton({
          text: $r('app.string.dialog_btn_cancel'),
          buttonEnabled: !this.busy,
          action: () => this.onCancel()
        })
      }
    }
    .width('100%')
    .padding(ADD_TOKEN_SECTION_PADDING)
    .borderRadius(ADD_TOKEN_SECTION_RADIUS)
    .backgroundColor($r('app.color.item_bg'))
    .alignItems(HorizontalAlign.Start)
  }
}
