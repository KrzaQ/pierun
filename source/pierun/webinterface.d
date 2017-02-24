module pierun.webinterface;

import std.typecons;

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
    bool isAdmin() const { return admin; }
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
    AuthInfo authenticate(HTTPServerRequest, HTTPServerResponse){
        return AuthInfo();
    }

    this(DataSource ds, DBSession s)
    {
        this.dataSource = ds;
        this.session = s;
    }
    
    @noAuth
    void index(HTTPServerRequest req)
    {
        auto code = "";
        auto time = null;
        auto auth = req.getAuth;
        render!("index.dt", code, time, auth);
    }

    //void editPost

    @noAuth
    void getLogin(HTTPServerRequest req, string _error = null)
    {
        auto auth = req.getAuth;

        auto time = null;
        render!("login.dt", time, auth, _error);
    }

    @noAuth @errorDisplay!getLogin 
    void postLogin(string username, string password, scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto user = session.createQuery("FROM User WHERE name=:Name")
            .setParameter("Name", username)
            .uniqueResult!User;

        enforceHTTP(user !is null, HTTPStatus.forbidden, "Username or password incorrect");

        import botan.passhash.bcrypt;

        enforceHTTP(checkBcrypt(password ~ user.salt, user.hashedPassword), HTTPStatus.forbidden, "Username or password incorrect");

        AuthInfo ai;
        ai.userName = user.name;
        req.session = res.startSession;
        req.session.set("auth", ai);

        redirect("/");
    }

    @noAuth
    void post(HTTPServerRequest req, string code)
    {
        import pierun.utils.markdown;
        import std.conv;

        auto auth = req.getAuth;

        code = pierun.utils.markdown.parseMarkdown(code);

        auto time = (Clock.currTime - req.timeCreated).to!string;

        render!("index.dt", code, time, auth);
    }

    mixin PrivateAccessProxy;
}

Nullable!AuthInfo getAuth(ref HTTPServerRequest req) {
    Nullable!AuthInfo auth;
    if (req.session && req.session.isKeySet("auth"))
        auth = req.session.get!AuthInfo("auth");
    return auth;
}
