module pierun.utils.dbcache;

import std.conv, std.uni;

import hibernated.core;

import pierun.core, pierun.utils.misc;

alias DBSession = hibernated.session.Session;

template Cache(Value, string id = "id")
{
    alias Cache = CacheElement!(DBElementDriver!(Value, id));
}

class DBCache
{
    private {
        DBSession session;
        Cache!Post posts;
        Cache!(KeyValue, "key") keyValues;
        Cache!(Tag, "name") tags;
        Cache!(Language, "isoCode") languages;
        Cache!Comment comments;

        CacheList!Post postLists;
    }

    this(DBSession s)
    {
        import std.traits;

        foreach(n; FieldNameTuple!DBCache) {
            alias ElementType = typeof(mixin("this." ~ n));
            static if(isInstanceOf!(CacheElement, ElementType)) {
                mixin("this." ~ n) = ElementType(s);
            }
            static if(isInstanceOf!(CacheList, ElementType)) {
                mixin("this." ~ n) = ElementType(s);
            }
        }
        
        this.session = s;
    }

    auto getPost(int id)
    {
        return posts.get(id);
    }

    Language getLanguage(const string code)
    {
        return languages.get(code);
    }

    Tag getTag(const string name)
    {
        return tags.get(name);
    }

    void setTag(const string name, string slug = null)
    {
        tags.setOrUpdate(name, (Tag t) => t.slugName = slug);
    }

    KeyValue getValue(const string key)
    {
        return keyValues.get(key);
    }

    void setValue(T)(const string key, const T value)
    {
        keyValues.setOrUpdate(key, (KeyValue v) => v.value = value.to!string);
    }

    auto getPostsByLanguage(const string language)
    {
        return postLists.get(
            "SELECT P FROM Post AS P " ~
            "WHERE status = 0 AND language.isoCode = :Lang " ~
            "ORDER BY P.published DESC",
            BoundValue("Lang", language)
        );
    }
}

private struct DBElementDriver(Value, string Key)
{
    alias ValueType = Value;
    alias KeyType = typeof(mixin(Value.stringof ~ "." ~ Key));
    enum KeyName = Key;

    static ValueType get(DBSession session, const KeyType key)
    {
        ValueType v = session
            .createQuery("FROM " ~ ValueType.stringof ~
                " WHERE " ~ Key ~ "=:Key")
            .setParameter("Key", key)
            .uniqueResult!ValueType;
        return v;
    }

    static void set(DBSession session, ValueType value)
    {
        session.save(value);
    }

    static void update(DBSession session, ValueType value)
    {
        session.update(value);
    }

    static void remove(DBSession session, ValueType value)
    {
        session.remove(value);
    }
}

private struct CacheElement(Driver, int IdealValuesCount = 1024)
{
    import std.datetime;

    alias ValueType = Driver.ValueType;
    alias KeyType = Driver.KeyType;

    this(DBSession session)
    {
        this.session = session;
    }

    ValueType get(const KeyType key)
    {
        auto ptr = key in data;

        if(ptr !is null) {
            ptr.lastAccessed = Clock.currTime;
            return ptr.value;
        }

        auto value = Driver.get(session, key);

        if(value !is null) {
            data[key] = Element(value);
        }

        return value;
    }

    void reset()
    {
        data.clear;
    }

    void reset(const KeyType value)
    {
        data.remove(value);
    }

    void remove(ValueType value)
    {
        Driver.remove(session, value);
    }

    void set(ValueType value)
    {
        Driver.set(session, value);
    }

    void update(ValueType value)
    {
        Driver.update(session, value);
    }

    void setOrUpdate(Updater)(KeyType key, Updater updater)
    {
        auto value = this.get(key);
        if(value is null) {
            value = new ValueType;
            mixin("value." ~ Driver.KeyName) = key;
            updater(value);
            this.set(value);
        } else {
            updater(value);
            this.update(value);
        }
    }

    void gc()
    {
        if(data.length < 2 * IdealValuesCount)
            return;

        import std.algorithm, std.array, std.range;
        auto toRemove = data.byKeyValue
            .array
            .sort!((a,b) => a.value.lastAccessed > b.value.lastAccessed)
            .drop(cast(int)(IdealValuesCount * 0.75))
            .map!(e => e.key);

        foreach(k; toRemove) {
            data.remove(k);
        }
    }

    private struct Element
    {
        this(ValueType value)
        {
            this.value = value;
            this.lastAccessed = Clock.currTime;
        }

        ValueType value;
        SysTime lastAccessed;
    }

    private {
        DBSession session;
        Element[KeyType] data;
    }
}

private struct BoundValue
{
    this(T)(const string k, const T v)
    {
        import std.conv;
        key = k;
        value = v.to!string;
    }

    int opCmp(ref const BoundValue o)
    {
        import std.algorithm;
        int r = cmp(key, o.key);
        if(r != 0) {
            return r;
        } else {
            return cmp(value, o.value);
        }
    }

    string key;
    string value;
}

private struct CacheList(Value, int IdealValuesCount = 1024)
{
    alias ValueList = Value[];

    struct Key
    {
        import std.typecons;
        string query;
        BoundValue[] boundValues;
    }

    this(DBSession s)
    {
        this.session = s;
    }

    ValueList get(Param...)(string query, Param params)
    {
        import std.array, std.algorithm, std.range;
        Key k;
        k.query = query;
        k.boundValues = sort([params]).array;

        auto ptr = k in data;

        if(ptr !is null) {
            import std.datetime;
            ptr.lastAccessed = Clock.currTime;
            return ptr.value;
        }

        auto bindValues = function(Query q, BoundValue[] vals) {
            foreach(v; vals) {
                q = q.setParameter(v.key, v.value);
            }
            return q;
        };

        auto value = session
            .createQuery(k.query)
            .identity!(bindValues)(k.boundValues)
            .list!Value;

        if(value !is null && value.length > 0) {
            data[k] = Element(value);
        }

        return value;
    }

    void reset()
    {
        data.clear;
    }

    void gc()
    {
        if(data.length < 2 * IdealValuesCount)
            return;

        import std.algorithm, std.array, std.range;
        auto toRemove = data.byKeyValue
            .array
            .sort!((a,b) => a.value.lastAccessed > b.value.lastAccessed)
            .drop(cast(int)(IdealValuesCount * 0.75))
            .map!(e => e.key);

        foreach(k; toRemove) {
            data.remove(k);
        }
    }

    private struct Element
    {
        import std.datetime;

        this(ValueList value)
        {
            this.value = value;
            this.lastAccessed = Clock.currTime;
        }

        ValueList value;
        SysTime lastAccessed;
    }

    private {
        DBSession session;
        Element[Key] data;
    }
}
