class LoginParams {
    constructor(userType, unionId, openId, nickname, portrait) {
        this.userType = userType;
        this.unionId = unionId;
        this.openId = openId;
        this.nickname = nickname;
        this.portrait = portrait;
    }
}

module.exports = { LoginParams };
