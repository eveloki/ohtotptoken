import { cloud, CloudDBCollection, CloudDBZoneQuery } from '@hw-agconnect/cloud-server';
import { LoginParams } from './model/LoginParams';
import { user as User } from './model/user';
import { UserResp } from './model/UserResp';

const ZONE_NAME = 'default';
const HW_ACCOUNT_LOGIN = 2;

export class DatabaseHelper {
  logger;
  colUser: CloudDBCollection<User>;

  constructor(logger) {
    this.logger = logger;
    this.colUser = cloud.database({ zoneName: ZONE_NAME }).collection(User);
  }

  async queryUser(loginParams: LoginParams): Promise<UserResp> {
    try {
      let userResp: UserResp;
      let userResult: User;
      if (loginParams.userType === HW_ACCOUNT_LOGIN && loginParams.unionId !== '') {
        userResult = await this.accountLogin(loginParams);
      }

      if (userResult) {
        userResp = new UserResp(
          userResult.getId(),
          userResult.getNickname(),
          userResult.getPortrait(),
          userResult.getDescription(),
          userResult.getUser_type(),
          userResult.getUnion_id(),
          userResult.getOpen_id()
        );
      }
      return userResp;
    } catch (error) {
      this.logger.error(`[third-login] queryUser error: ${error}`);
    }
  }

  async accountLogin(loginParams: LoginParams): Promise<User> {
    let userResult: User;
    const cloudDBZoneQuery: CloudDBZoneQuery<User> = this.colUser.query().equalTo("union_id", loginParams.unionId);
    const userList: User[] = await cloudDBZoneQuery.get();
    if (userList.length > 0) {
      userResult = userList[0];
      userResult.setNickname(loginParams.nickname || userResult.getNickname());
      userResult.setPortrait(loginParams.portrait || userResult.getPortrait());
      userResult.setOpen_id(loginParams.openId || userResult.getOpen_id());
      userResult.setUpdate_time(new Date());
      await this.colUser.upsert(userResult);
    } else {
      const maxIdUserQuery: CloudDBZoneQuery<User> = this.colUser.query().orderByDesc("id").limit(1);
      const maxIdUserData: User[] = await maxIdUserQuery.get();
      let newUserId = 'u10000001';
      if (maxIdUserData.length > 0) {
        const maxIdUser: User = maxIdUserData[0];
        const userId: string = maxIdUser.getId();
        const id = userId.replace('u', '');
        newUserId = 'u' + (Number.parseInt(id) + 1);
      }
      const createResult: number = await this.createUser(loginParams, newUserId);
      if (createResult > 0) {
        const userList: User[] = await cloudDBZoneQuery.get();
        userResult = userList[0];
      }
    }
    return userResult;
  }

  async createUser(loginParams: LoginParams, newUserId: string): Promise<number> {
    try {
      const createUser = new User();
      createUser.setId(newUserId);
      createUser.setNickname(loginParams.nickname || '');
      createUser.setPortrait(loginParams.portrait || '');
      createUser.setUnion_id(loginParams.unionId);
      createUser.setOpen_id(loginParams.openId || '');
      createUser.setUser_type(HW_ACCOUNT_LOGIN);
      createUser.setDescription('');
      createUser.setCreate_time(new Date());
      createUser.setUpdate_time(new Date());
      return await this.colUser.upsert(createUser);
    } catch (error) {
      this.logger.error(`[third-login] createUser error: ${error}`);
      return -1;
    }
  }
}
