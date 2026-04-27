import { authentication } from '@kit.AccountKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreferenceManager } from './PreferenceManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'HuaweiAccountManager';
const PREF_KEY_LOGGED_IN = 'huawei_logged_in';
const PREF_KEY_USER_ACCOUNT = 'huawei_user_account';

export enum HuaweiAccountErrorCode {
  ERROR_CODE_LOGIN_OUT = 1001502001,
  ERROR_CODE_NETWORK_ERROR = 1001502005,
  ERROR_CODE_INTERNAL_ERROR = 1001502009,
  ERROR_CODE_USER_CANCEL = 1001502012,
  ERROR_CODE_SYSTEM_SERVICE = 12300001,
  ERROR_CODE_REQUEST_REFUSE = 1001500002,
}

export class HuaweiAccountLoginError extends Error {
  code: number = 0;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

export class HuaweiUserInfo {
  nickname: string = '';
  avatarUri: string = '';
  unionId: string = '';

  constructor(nickname: string, avatarUri: string, unionId: string) {
    this.nickname = nickname;
    this.avatarUri = avatarUri;
    this.unionId = unionId;
  }
}

export class HuaweiAccountManager {
  private static instance: HuaweiAccountManager;
  private prefMgr = PreferenceManager.getInstance();
  public userLogin: boolean = false;
  public userAccount: HuaweiUserInfo = new HuaweiUserInfo('', '', '');

  private constructor() {}

  static getInstance(): HuaweiAccountManager {
    if (!HuaweiAccountManager.instance) {
      HuaweiAccountManager.instance = new HuaweiAccountManager();
    }
    return HuaweiAccountManager.instance;
  }

  static getLoginErrorResource(code: number): Resource | null {
    if (code === HuaweiAccountErrorCode.ERROR_CODE_LOGIN_OUT) {
      return $r('app.string.huawei_account_error_not_logged_in');
    } else if (code === HuaweiAccountErrorCode.ERROR_CODE_NETWORK_ERROR) {
      return $r('app.string.huawei_account_error_network');
    } else if (code === HuaweiAccountErrorCode.ERROR_CODE_INTERNAL_ERROR) {
      return $r('app.string.huawei_account_error_internal');
    } else if (code === HuaweiAccountErrorCode.ERROR_CODE_USER_CANCEL) {
      return $r('app.string.huawei_account_error_user_cancel');
    } else if (code === HuaweiAccountErrorCode.ERROR_CODE_SYSTEM_SERVICE) {
      return $r('app.string.huawei_account_error_system_service');
    } else if (code === HuaweiAccountErrorCode.ERROR_CODE_REQUEST_REFUSE) {
      return null;
    }
    return $r('app.string.huawei_account_login_failed');
  }

  static isUserCancel(code: number): boolean {
    return code === HuaweiAccountErrorCode.ERROR_CODE_USER_CANCEL;
  }

  async init(): Promise<void> {
    const savedLogin: boolean = await this.prefMgr.getValue<boolean>(PREF_KEY_LOGGED_IN) ?? false;
    const savedAccount: HuaweiUserInfo | null = await this.prefMgr.getValue<HuaweiUserInfo>(PREF_KEY_USER_ACCOUNT);
    if (savedLogin && savedAccount) {
      this.userLogin = true;
      this.userAccount = savedAccount;
      this.checkAuthState();
    }
    this.updateAppStorage();
  }

  private checkAuthState(): void {
    const stateRequest: authentication.StateRequest = {
      idType: authentication.IdType.UNION_ID,
      idValue: this.userAccount.unionId,
    };
    new authentication.HuaweiIDProvider().getHuaweiIDState(stateRequest)
      .then((result: authentication.StateResult) => {
        if (result.state !== authentication.State.AUTHORIZED) {
          this.userLogin = false;
        }
        this.updatePreference();
        this.updateAppStorage();
      })
      .catch((error: BusinessError) => {
        hilog.error(0, TAG, `getHuaweiIDState failed: ${error.code} ${error.message}`);
      });
  }

  getUserInfo(): HuaweiUserInfo | undefined {
    if (this.userLogin) {
      return this.userAccount;
    }
    return undefined;
  }

  async login(uiContext: UIContext): Promise<HuaweiUserInfo> {
    const credential = await this.getAuthCredential(uiContext);
    this.userAccount = new HuaweiUserInfo(
      credential.nickName ?? '',
      credential.avatarUri ?? '',
      credential.unionID ?? ''
    );
    this.userLogin = true;
    this.updatePreference();
    this.updateAppStorage();
    return this.userAccount;
  }

  private getAuthCredential(uiContext: UIContext): Promise<authentication.AuthorizationWithHuaweiIDCredential> {
    const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    authRequest.scopes = ['profile'];
    authRequest.permissions = ['serviceauthcode'];
    authRequest.forceAuthorization = true;
    authRequest.state = util.generateRandomUUID();
    const controller = new authentication.AuthenticationController(uiContext.getHostContext());
    return new Promise((resolve, reject) => {
      controller.executeRequest(authRequest).then((result) => {
        const response = result as authentication.AuthorizationWithHuaweiIDResponse;
        const state = response.state;
        if (state !== undefined && authRequest.state !== state) {
          reject(new HuaweiAccountLoginError(0, 'state mismatch'));
          return;
        }
        const credential = response.data;
        if (!credential) {
          reject(new HuaweiAccountLoginError(0, 'credential is missing'));
          return;
        }
        resolve(credential);
      }).catch((error: BusinessError) => {
        hilog.error(0, TAG, `authorize failed: ${error.code} ${error.message}`);
        reject(new HuaweiAccountLoginError(error.code, error.message));
      });
    });
  }

  async logout(): Promise<void> {
    this.userLogin = false;
    this.userAccount = new HuaweiUserInfo('', '', '');
    this.updatePreference();
    this.updateAppStorage();
  }

  selectHuaweiAccountToLogin(): void {
    this.userLogin = true;
    this.updatePreference();
    this.updateAppStorage();
  }

  private updatePreference(): void {
    this.prefMgr.setValue(PREF_KEY_LOGGED_IN, this.userLogin);
    this.prefMgr.setValue(PREF_KEY_USER_ACCOUNT, this.userLogin ? this.userAccount : null);
  }

  private updateAppStorage(): void {
    AppStorage.setOrCreate('huawei_is_logged_in', this.userLogin);
    AppStorage.setOrCreate('huawei_user', this.userLogin ? this.userAccount : null);
  }
}
