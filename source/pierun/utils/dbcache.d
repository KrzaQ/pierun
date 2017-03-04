module pierun.utils.dbcache;

import std.conv, std.uni;

import hibernated.core;

import pierun.core, pierun.utils.misc;

alias DBSession = hibernated.session.Session;

class DBCache
{
    private {
        DBSession session;
        Post[int] posts;
        KeyValue[string] keyValues;
        Tag[string] tags;
        Language[string] languages;
    }

    this(DBSession s)
    {
        this.session = s;
    }

    auto getPost(int id)
    {
        auto ptr = id in posts;
        if(ptr !is null) return *ptr;

        Post p = session.createQuery("FROM Post WHERE id=:Id")
            .setParameter("Id", id)
            .uniqueResult!Post;

        if(p !is null)
            posts[id] = p;
        return p;
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
        auto ptr = key.toLower in keyValues;
        if(ptr !is null) {
            return *ptr;
        }

        KeyValue kv = session
            .createQuery("FROM KeyValue WHERE key=:Key")
            .setParameter("Key", key.toLower)
            .uniqueResult!KeyValue;

        if(kv !is null) {
            keyValues[key.toLower] = kv;
        }

        return kv;
    }

    void setValue(T)(const string key, const T value)
    {
        keyValues.remove(key.toLower);
        
        KeyValue kv = session
            .createQuery("FROM KeyValue WHERE key=:Key")
            .setParameter("Key", key.toLower)
            .uniqueResult!KeyValue;

        if(kv is null) {
            kv = new KeyValue;
            kv.key = key.toLower;
            kv.value = value.to!string;
            session.save(kv);
            keyValues[kv.key] = kv;
        } else {
            kv.value = value.to!string;
            session.update(kv);
        }
    }
}
