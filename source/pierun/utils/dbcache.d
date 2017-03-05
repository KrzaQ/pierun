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
        //CacheElement!(DBElementDriver!(Post, "id")) posts;
        Cache!Post posts;
        Cache!(KeyValue, "key") keyValues;
        Tag[string] tags;
        Language[string] languages;
    }

    this(DBSession s)
    {
        this.session = s;
        posts = typeof(posts)(s);
        keyValues = typeof(keyValues)(s);
    }

    auto getPost(int id)
    {
        return posts.get(id);
    }

    Language getLanguage(const string code)
    {
        auto ptr = code in languages;
        if(ptr !is null) {
            return *ptr;
        }

        Language l = session
            .createQuery("FROM Language WHERE isoCode=:Code")
            .setParameter("Code", code)
            .uniqueResult!Language;

        if(l !is null) {
            languages[code] = l;
        }

        return l;
    }

    Tag getTag(const string name)
    {
        auto ptr = name in tags;
        if(ptr !is null) {
            return *ptr;
        }

        Tag t = session
            .createQuery("FROM Tag WHERE name=:Name")
            .setParameter("Name", name)
            .uniqueResult!Tag;

        if(t !is null) {
            tags[name] = t;
        }

        return t;
    }

    void setTag(const string name, string slug = null)
    {
        tags.remove(name);
        
        Tag t = session
            .createQuery("FROM Tag WHERE name=:Name")
            .setParameter("Name", name)
            .uniqueResult!Tag;
        
        if(slug is null)
            slug = name.toSlugForm;

        if(t is null) {
            import vibe.textfilter.markdown;
            t = new Tag;
            t.name = name;
            t.slugName = slug;
            session.save(t);
            tags[name] = t;
        } else {
            t.slugName = slug;
            session.update(t);
        }
    }


    KeyValue getValue(const string key)
    {
        return keyValues.get(key);
        //auto ptr = key.toLower in keyValues;
        //if(ptr !is null) {
        //    return *ptr;
        //}

        //KeyValue kv = session
        //    .createQuery("FROM KeyValue WHERE key=:Key")
        //    .setParameter("Key", key.toLower)
        //    .uniqueResult!KeyValue;

        //if(kv !is null) {
        //    keyValues[key.toLower] = kv;
        //}

        //return kv;
    }

    void setValue(T)(const string key, const T value)
    {
        auto updater = delegate (KeyValue v) => v.value = value.to!string;
        keyValues.setOrUpdate(key, updater);
        //keyValues.remove(key.toLower);
        
        //KeyValue kv = session
        //    .createQuery("FROM KeyValue WHERE key=:Key")
        //    .setParameter("Key", key.toLower)
        //    .uniqueResult!KeyValue;

        //if(kv is null) {
        //    kv = new KeyValue;
        //    kv.key = key.toLower;
        //    kv.value = value.to!string;
        //    session.save(kv);
        //    keyValues[kv.key] = kv;
        //} else {
        //    kv.value = value.to!string;
        //    session.update(kv);
        //}
    }
}

private struct DBElementDriver(Value, string Key)
{
    alias ValueType = Value;
    alias KeyType = typeof(mixin(Value.stringof ~ "." ~ Key));

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
