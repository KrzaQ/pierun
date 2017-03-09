module pierun.interfaces.web;

import std.conv, std.format, std.string, std.typecons;

import vibe.d;
import vibe.web.auth;

import hibernated.core;

import pierun.core;
import pierun.utils.dbcache, pierun.utils.misc;

import pierun.interfaces.common,
       pierun.interfaces.admin,
       pierun.interfaces.rss;

@requiresAuth
class WebInterface
{
    private {
        DataSource dataSource;
        DBSession sessionMember;
        DBCache dbCacheMember;
        AdminWebInterface adminWebInterface;
        RSSWebInterface rssWebInterace;
    }

    @property AdminWebInterface admin() { return adminWebInterface; }
    @property RSSWebInterface rss() { return rssWebInterace; }

    @noRoute @property DBCache dbCache() { return dbCacheMember; }
    @noRoute @property DBSession session() { return sessionMember; }

    @noRoute
    AuthInfo authenticate(HTTPServerRequest req, HTTPServerResponse res){
        if (!req.session || !req.session.isKeySet("auth"))
            throw new HTTPStatusException(HTTPStatus.forbidden, "Not authorized to perform this action!");

        return req.session.get!AuthInfo("auth");
    }

    this(DataSource ds, DBSession s)
    {
        this.dataSource = ds;
        this.sessionMember = s;
        this.dbCacheMember = new DBCache(s);
        this.adminWebInterface = new AdminWebInterface(this);
        this.rssWebInterace = new RSSWebInterface(this);
    }
    
    @noAuth
    void index(HTTPServerRequest req, HTTPServerResponse res)
    {
        Post[] posts = dbCache.getPostsByLanguage("EN");

        render!("index.dt", posts);
    }

    @noAuth
    void getLogin(HTTPServerRequest req, string _error = null)
    {
        string page_title = "login";
        render!("login.dt", _error);
    }

    @noAuth @errorDisplay!getLogin 
    void postLogin(string username, string password,
        scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto user = session.createQuery("FROM User WHERE name=:Name")
            .setParameter("Name", username)
            .uniqueResult!User;

        enforceHTTP(user !is null,
            HTTPStatus.forbidden, "Username or password incorrect");

        import botan.passhash.bcrypt;

        enforceHTTP(checkBcrypt(password ~ user.salt, user.hashedPassword),
            HTTPStatus.forbidden, "Username or password incorrect");

        AuthInfo ai;
        ai.userName = user.name;
        ai.admin = true;
        req.session = res.startSession;
        req.session.set("auth", ai);

        redirect("/");
    }

    @path("/post/:id/*") @noAuth @errorDisplay!error
    void getPostIdName(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto id = req.params["id"].to!int;

        Post p = dbCache.getPost(id);

        enforceHTTP(p !is null, HTTPStatus.notFound,
            "Post %d not found!".format(id));

        if(p.status == Post.Status.Private) {
            auto auth = req.getAuth;

            enforceHTTP(!auth.isNull && auth.isAdmin, HTTPStatus.notFound,
                "Post %d not found!".format(id));
        }

        render!("post.dt", p);
    }

    @path("/post/:id") @noAuth @errorDisplay!error
    void getPostId(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        getPostIdName(req, res);
    }

    @noAuth @errorDisplay!error
    void postSendComment(HTTPServerRequest req, HTTPServerResponse res,
        string author, string email, string website, string markdown,
        string parentId = null)
    {
        auto c = new Comment;
        auto auth = req.getAuth;

        if(!auth.isNull) {
            //c.author = 
        }
    }

    @auth(Role.admin)
    void getAddPost(HTTPServerRequest req, HTTPServerResponse res)
    {
        postAddPost(req, res);
    }

    @auth(Role.admin)
    void postAddPost(HTTPServerRequest req, HTTPServerResponse res,
        string markdown = "", string excerpt = "", string title = "",
        string language = "EN", string tags = "", string _error = null)
    {
        render!("add_post.dt", markdown, excerpt,
                title, language, tags, _error);
    }

    @auth(Role.admin) @errorDisplay!postAddPost
    void postSendPost(HTTPServerRequest req, HTTPServerResponse res,
        AuthInfo ai, string markdown, string excerpt, string title,
        string language, string tags)
    {
        enforceHTTP(language.length == 2, HTTPStatus.badRequest,
            "Language must be two characters long");

        import std.array, std.algorithm, std.regex, std.traits;

        auto getOrMakeTag = delegate Tag(const string name) {
            auto t = dbCache.getTag(name);
            if(t is null) {
                t = new Tag;
                t.name = name;
                t.slugName = name.toSlugForm;
                session.save(t);
            }
            return t;
        };

        auto splitTags = tags
            .split(ctRegex!`,\s+`)
            .map!(identity!getOrMakeTag)
            .array;


        auto getOrMakeLanguage = delegate Language(const string name) {
            auto l = dbCache.getLanguage(name);
            if(l is null) {
                import std.uni;
                l = new Language;
                l.name = name;
                l.isoCode = name.toUpper;
                session.save(l);
            }
            return l;
        };

        User u = session.createQuery("FROM User WHERE name=:Name")
            .setParameter("Name", ai.userName)
            .uniqueResult!User;

        Post p = new Post;
        PostData pd = new PostData;

        p.author = u;
        p.edits = [pd];
        p.published = cast(DateTime)Clock.currTime;
        p.language = getOrMakeLanguage(language);

        pd.title = title;
        pd.markdown = markdown;
        pd.excerpt = excerpt;
        pd.timestamp = p.published;
        pd.post = p;
        pd.tags = splitTags;
        pd.gpg = "";

        u.posts ~= p;

        session.update(u);
        session.save(p);
        session.save(pd);

        redirect("/");
    }


    @noRoute @noAuth
    void error(HTTPServerRequest req, string _error)
    {
        render!("error.dt", _error);
    }

    mixin PrivateAccessProxy;
}

Nullable!AuthInfo getAuth(ref HTTPServerRequest req) {
    Nullable!AuthInfo auth;
    if (req.session && req.session.isKeySet("auth"))
        auth = req.session.get!AuthInfo("auth");
    return auth;
}

Nullable!string getTime(ref HTTPServerRequest req) {
    Nullable!string ret;
    import std.conv;
    auto diff = Clock.currTime - req.timeCreated;
    ret = diff.to!string;
    return ret;
}

