class UserResp {
    constructor(id, nickname, portrait, description, userType, unionId, openId) {
        this.id = id;
        this.nickname = nickname;
        this.portrait = portrait;
        this.description = description;
        this.userType = userType;
        this.unionId = unionId;
        this.openId = openId;
    }
}

module.exports = { UserResp };
