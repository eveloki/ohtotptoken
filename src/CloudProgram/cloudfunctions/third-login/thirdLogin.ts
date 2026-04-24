import { DatabaseHelper } from './DatabaseHelper';
import { LoginParams } from './model/LoginParams';
import { UserResp } from './model/UserResp';

let myHandler = async function (event, _context, callback, logger) {
  const userType: number = event.body ? JSON.parse(event.body).userType : event.userType;
  const unionId: string = event.body ? JSON.parse(event.body).unionId : event.unionId;
  const openId: string = event.body ? JSON.parse(event.body).openId : event.openId;
  const nickname: string = event.body ? JSON.parse(event.body).nickname : event.nickname;
  const portrait: string = event.body ? JSON.parse(event.body).portrait : event.portrait;

  const loginParams = new LoginParams(userType, unionId, openId, nickname, portrait);

  try {
    const databaseHelper: DatabaseHelper = new DatabaseHelper(logger);
    const user: UserResp = await databaseHelper.queryUser(loginParams);
    if (user) {
      callback({
        code: 0,
        message: '[third-login] request successful',
        data: user,
      });
    } else {
      callback({
        code: 1,
        message: '[third-login] request failed',
        data: null,
      });
    }
  } catch (err) {
    logger.error(`[third-login] func error: ${err.message}`);
    callback({
      code: 3,
      message: '[third-login] operation exception',
      data: err,
    });
  }
};

export { myHandler };
