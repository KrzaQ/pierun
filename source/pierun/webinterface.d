module pierun.webinterface;

import vibe.d;

import hibernated.core;

alias DBSession = hibernated.session.Session;

struct SessionData
{
    bool loggedIn = false;
    string userName;
    string sessionId;
}

class WebInterface
{
    private {
        DataSource dataSource;
        DBSession session;
        SessionVar!(SessionData, "session") sessdionData;
    }

    this(DataSource ds, DBSession s)
    {
        this.dataSource = ds;
        this.session = session;
    }
    
    void index()
    {
        auto code = "";
        auto time = "";
        render!("index.dt", code, time);
    }

    void post(HTTPServerRequest req, string code)
    {
        import pierun.utils.markdown;
        import std.conv;

        code = pierun.utils.markdown.parseMarkdown(code);

        auto time = (Clock.currTime - req.timeCreated).to!string;

        render!("index.dt", code, time);
    }

    mixin PrivateAccessProxy;
}
