/**
 * 旧版 mafile 结构（Steam Guard 导出格式）。
 *
 * 仍被 `SteamAuth.fromMaFile()` / `TokenConfig.SteamMaFile` 兼容路径使用。
 */
export class maFile {
  public shared_secret: string = '';
  public serial_number: string = '';
  public revocation_code: string = '';
  public uri: string = '';
  public server_time: number = 0;
  public account_name: string = '';
  public token_gid: string = '';
  public identity_secret: string = '';
  public secret_1: string = '';
  public status: number = 0;
  public device_id: string = '';
  public fully_enrolled: boolean = false;
  public Session: string | null = null;
}

export enum ESessionPersistence {
  k_ESessionPersistence_Invalid = -1,
  k_ESessionPersistence_Ephemeral = 0,
  k_ESessionPersistence_Persistent = 1,
}

/** Steam 5 位字母动态码（由 TOTP 数字映射），供列表/卡片共用 */
export class SteamUtils {
  private static steam_chars: string = "23456789BCDFGHJKMNPQRTVWXY";
  private static steam_digits: number = 5;

  public static SteamTokenFromTOTP(totp_token: number): string {
    let total_chars = SteamUtils.steam_chars.length;
    let int_code = totp_token;
    let steam_token = '';
    for (let index = 0; index < SteamUtils.steam_digits; index++) {
      let pos = int_code % total_chars;
      steam_token += SteamUtils.steam_chars[pos];
      int_code = Math.floor(int_code / total_chars);
    }
    return steam_token;
  }
}