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
        Language[string] languages;
    }

    this(DBSession s)
    {
        import std.traits;

        foreach(n; FieldNameTuple!DBCache) {
            alias ElementType = typeof(mixin("this." ~ n));
            static if(isInstanceOf!(CacheElement, ElementType)) {
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
