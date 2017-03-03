module pierun.interfaces.common;

import pierun.utils.dbcache;

struct AuthInfo
{
    string userName;
    bool admin;

    @safe:
    bool isAdmin() const { return this.admin; }
}

struct BlogInfo
{
    DBCache dbCache;
    string pageTitle;

    auto getSetting(T)(const string key, const T defaultValue = T.init) {
        auto kv = dbCache.getValue(key);
        if(kv is null) {
            return defaultValue;
        } else {
            return kv.value.to!T;
        }
    }
}
