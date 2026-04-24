class user {
    getFieldTypeMap() {
        let fieldTypeMap = new Map();
        fieldTypeMap.set('id', 'String');
        fieldTypeMap.set('username', 'String');
        fieldTypeMap.set('nickname', 'String');
        fieldTypeMap.set('portrait', 'Text');
        fieldTypeMap.set('union_id', 'String');
        fieldTypeMap.set('open_id', 'String');
        fieldTypeMap.set('user_type', 'Integer');
        fieldTypeMap.set('description', 'String');
        fieldTypeMap.set('create_time', 'Date');
        fieldTypeMap.set('update_time', 'Date');
        return fieldTypeMap;
    }

    getClassName() {
        return 'user';
    }

    getPrimaryKeyList() {
        let primaryKeyList = [];
        primaryKeyList.push('id');
        return primaryKeyList;
    }

    getIndexList() {
        let indexList = [];
        return indexList;
    }

    getEncryptedFieldList() {
        let encryptedFieldList = [];
        return encryptedFieldList;
    }

    setId(id) { this.id = id; }
    getId() { return this.id; }

    setUsername(username) { this.username = username; }
    getUsername() { return this.username; }

    setNickname(nickname) { this.nickname = nickname; }
    getNickname() { return this.nickname; }

    setPortrait(portrait) { this.portrait = portrait; }
    getPortrait() { return this.portrait; }

    setUnion_id(union_id) { this.union_id = union_id; }
    getUnion_id() { return this.union_id; }

    setOpen_id(open_id) { this.open_id = open_id; }
    getOpen_id() { return this.open_id; }

    setUser_type(user_type) { this.user_type = user_type; }
    getUser_type() { return this.user_type; }

    setDescription(description) { this.description = description; }
    getDescription() { return this.description; }

    setCreate_time(create_time) { this.create_time = create_time; }
    getCreate_time() { return this.create_time; }

    setUpdate_time(update_time) { this.update_time = update_time; }
    getUpdate_time() { return this.update_time; }
}

module.exports = { user };
