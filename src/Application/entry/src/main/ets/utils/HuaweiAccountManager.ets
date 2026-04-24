import { authentication } from '@kit.AccountKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreferenceManager } from './PreferenceManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import cloudRequest from './CloudRequest';

const TAG = 'HuaweiAccountManager';
const PREF_KEY_LOGGED_USER = 'huawei_logged_user';
const CLOUD_FUNC_LOGIN = 'third-login';
const HW_ACCOUNT_TYPE = 2;

export class HuaweiUserInfo {
  nickname: string = '';
  avatarUri: string = '';
  unionId: string = '';
  openId: string = '';
  serverUserId: string = '';

  constructor(nickname: string, avatarUri: string, unionId: string, openId: string, serverUserId?: string) {
    this.nickname = nickname;
    this.avatarUri = avatarUri;
    this.unionId = unionId;
    this.openId = openId;
    this.serverUserId = serverUserId ?? '';
  }
}

class AuthResult {
  nickname: string = '';
  avatarUri: string = '';

  constructor(nickname: string, avatarUri: string) {
    this.nickname = nickname;
    this.avatarUri = avatarUri;
  }
}

class LoginResult {
  unionId: string = '';
  openId: string = '';

  constructor(unionId: string, openId: string) {
    this.unionId = unionId;
    this.openId = openId;
  }
}

class CloudLoginParams {
  userType: number = HW_ACCOUNT_TYPE;
  unionId: string = '';
  openId: string = '';
  nickname: string = '';
  portrait: string = '';
}

class CloudLoginResponse {
  id: string = '';
  nickname: string = '';
  portrait: string = '';
  description: string = '';
  userType: number = 0;
  unionId: string = '';
  openId: string = '';
}

export class HuaweiAccountManager {
  private static instance: HuaweiAccountManager;
  private context: Context | null = null;
  private prefMgr = PreferenceManager.getInstance();

  private constructor() {}

  static getInstance(): HuaweiAccountManager {
    if (!HuaweiAccountManager.instance) {
      HuaweiAccountManager.instance = new HuaweiAccountManager();
    }
    return HuaweiAccountManager.instance;
  }

  setContext(context: Context): void {
    this.context = context;
  }

  async loginWithHuaweiID(): Promise<HuaweiUserInfo | null> {
    if (!this.context) {
      hilog.error(0, TAG, 'context is null');
      return null;
    }

    try {
      const authResult = await this.authorizeWithHuaweiID();
      if (!authResult) {
        return null;
      }

      const loginResult = await this.loginWithHuaweiIDInternal();
      if (!loginResult) {
        return null;
      }

      const userInfo = new HuaweiUserInfo(
        authResult.nickname,
        authResult.avatarUri,
        loginResult.unionId,
        loginResult.openId
      );

      const cloudUser = await this.cloudLogin(userInfo);
      if (cloudUser) {
        userInfo.serverUserId = cloudUser.id;
        if (cloudUser.nickname) {
          userInfo.nickname = cloudUser.nickname;
        }
        if (cloudUser.portrait) {
          userInfo.avatarUri = cloudUser.portrait;
        }
      }

      AppStorage.setOrCreate('huawei_user', userInfo);
      AppStorage.setOrCreate('huawei_is_logged_in', true);
      AppStorage.setOrCreate('huawei_server_user_id', userInfo.serverUserId);
      await this.prefMgr.setValue(PREF_KEY_LOGGED_USER, userInfo);
      return userInfo;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0, TAG, `login failed: ${err.code} ${err.message}`);
      return null;
    }
  }

  private async cloudLogin(userInfo: HuaweiUserInfo): Promise<CloudLoginResponse | null> {
    try {
      const params = new CloudLoginParams();
      params.userType = HW_ACCOUNT_TYPE;
      params.unionId = userInfo.unionId;
      params.openId = userInfo.openId;
      params.nickname = userInfo.nickname;
      params.portrait = userInfo.avatarUri;
      const result = await cloudRequest.call(CLOUD_FUNC_LOGIN, params) as CloudLoginResponse;
      if (result && result.id) {
        hilog.info(0, TAG, `cloud login success, serverUserId=${result.id}`);
        return result;
      }
      hilog.warn(0, TAG, 'cloud login returned no data');
      return null;
    } catch (e) {
      hilog.error(0, TAG, `cloud login failed: ${(e as Error).message}`);
      return null;
    }
  }

  private authorizeWithHuaweiID(): Promise<AuthResult | null> {
    return new Promise((resolve) => {
      const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
      authRequest.scopes = ['profile', 'openid'];
      authRequest.permissions = ['idtoken'];
      authRequest.forceAuthorization = true;
      authRequest.state = util.generateRandomUUID();

      const controller = new authentication.AuthenticationController(this.context!);
      controller.executeRequest(authRequest, (err, data) => {
        if (err) {
          hilog.error(0, TAG, `authorize failed: ${err.code} ${err.message}`);
          resolve(null);
          return;
        }
        const response = data as authentication.AuthorizationWithHuaweiIDResponse;
        if (response.state != undefined && authRequest.state != response.state) {
          hilog.error(0, TAG, 'authorize state mismatch');
          resolve(null);
          return;
        }
        const credential = response.data!;
        resolve(new AuthResult(credential.nickName || '', credential.avatarUri || ''));
      });
    });
  }

  private loginWithHuaweiIDInternal(): Promise<LoginResult | null> {
    return new Promise((resolve) => {
      const loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
      loginRequest.forceLogin = true;
      loginRequest.state = util.generateRandomUUID();

      const controller = new authentication.AuthenticationController(this.context!);
      controller.executeRequest(loginRequest, (err, data) => {
        if (err) {
          hilog.error(0, TAG, `login failed: ${err.code} ${err.message}`);
          resolve(null);
          return;
        }
        const response = data as authentication.LoginWithHuaweiIDResponse;
        if (response.state != undefined && loginRequest.state != response.state) {
          hilog.error(0, TAG, 'login state mismatch');
          resolve(null);
          return;
        }
        const credential = response.data!;
        resolve(new LoginResult(credential.unionID || '', credential.openID || ''));
      });
    });
  }

  async logout(): Promise<void> {
    AppStorage.setOrCreate('huawei_user', null);
    AppStorage.setOrCreate('huawei_is_logged_in', false);
    AppStorage.setOrCreate('huawei_server_user_id', '');
    await this.prefMgr.setValue(PREF_KEY_LOGGED_USER, null);
  }

  async restoreLoginState(): Promise<void> {
    const saved = await this.prefMgr.getValue<HuaweiUserInfo>(PREF_KEY_LOGGED_USER);
    if (saved) {
      AppStorage.setOrCreate('huawei_user', saved);
      AppStorage.setOrCreate('huawei_is_logged_in', true);
      AppStorage.setOrCreate('huawei_server_user_id', saved.serverUserId ?? '');
    }
  }

  getServerUserId(): string {
    return AppStorage.get<string>('huawei_server_user_id') ?? '';
  }

  isLoggedIn(): boolean {
    return AppStorage.get<boolean>('huawei_is_logged_in') ?? false;
  }
}
