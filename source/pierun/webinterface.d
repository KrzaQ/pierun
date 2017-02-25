module pierun.webinterface;

import std.conv, std.format, std.string, std.typecons;

import vibe.d;
import vibe.web.auth;

import hibernated.core;

import pierun.core;

alias DBSession = hibernated.session.Session;

struct SessionData
{
    bool loggedIn = false;
    string userName;
    string sessionId;
}

struct AuthInfo
{
    string userName;
    bool admin;

    @safe:
    bool isAdmin() const { return this.admin; }
}

@requiresAuth
class WebInterface
{
    private {
        DataSource dataSource;
        DBSession session;
        //SessionVar!(SessionData, "session") sessdionData;
    }
    
    @noRoute
    AuthInfo authenticate(HTTPServerRequest req, HTTPServerResponse res){
        if (!req.session || !req.session.isKeySet("auth"))
            throw new HTTPStatusException(HTTPStatus.forbidden, "Not authorized to perform this action!");

        return req.session.get!AuthInfo("auth");
    }

    this(DataSource ds, DBSession s)
    {
        this.dataSource = ds;
        this.session = s;
    }
    
    @noAuth
    void index(HTTPServerRequest req)
    {
        auto markdown = "";
        render!("index.dt", markdown);
    }

    @noAuth
    void getLogin(HTTPServerRequest req, string _error = null)
    {
        render!("login.dt", _error);
    }

    @noAuth @errorDisplay!getLogin 
    void postLogin(string username, string password,
        scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto user = session.createQuery("FROM User WHERE name=:Name")
            .setParameter("Name", username)
            .uniqueResult!User;

        enforceHTTP(user !is null, HTTPStatus.forbidden, "Username or password incorrect");

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

    @noAuth
    void post(HTTPServerRequest req, string markdown)
    {
        import pierun.utils.markdown;
        import std.conv;

        markdown = pierun.utils.markdown.parseMarkdown(markdown);


        render!("index.dt", markdown);
    }

    @path("/post/:id/*") @noAuth
    void getPostIdName(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto id = req.params["id"].to!int;

        Post p = session.createQuery("FROM Post WHERE id=:Id")
            .setParameter("Id", id)
            .uniqueResult!Post;

        enforceHTTP(p !is null, HTTPStatus.notFound,
            "Post %d not found!".format(id));

        render!("post.dt", p);
    }

    @path("/post/:id") @noAuth
    void getPostId(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        getPostIdName(req, res);
    }

    @auth(Role.admin) @errorDisplay!getLogin 
    void getAddPost(HTTPServerRequest req, HTTPServerResponse res)
    {
        postAddPost(req, res);
    }

    @auth(Role.admin) @errorDisplay!getLogin 
    void postAddPost(HTTPServerRequest req, HTTPServerResponse res,
        string markdown = "", string excerpt = "", string title = "",
        string language = "")
    {
        render!("add_post.dt", markdown, excerpt, title, language);
    }

    @auth(Role.admin) @errorDisplay!getLogin
    void postSendPost(HTTPServerRequest req, HTTPServerResponse res,
        AuthInfo ai, string markdown, string excerpt, string title,
        string language)
    {
        User u = session.createQuery("FROM User WHERE name=:Name")
            .setParameter("Name", ai.userName)
            .uniqueResult!User;
        Post p = new Post;
        PostData pd = new PostData;

        p.author = u;
        p.edits = [pd];
        p.published = cast(DateTime)Clock.currTime;

        pd.title = title;
        pd.markdown = markdown;
        pd.excerpt = excerpt;
        pd.timestamp = p.published;
        pd.post = p;

        u.posts ~= p;

        session.update(u);
        session.save(p);
        session.save(pd);

        redirect("/");
    }


    @noRoute
    void error(HTTPServerRequest req, string error)
    {
        render!("error.dt", error);
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
