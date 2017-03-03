struct DBSettings
{
    string host;
    ushort port;
    string user;
    string password;
    string name;
}

struct Settings
{
    string[] ips;
    ushort port;
    DBSettings database;
}


void main()
{
    import vibe.d;
    if (!finalizeCommandLineOptions())
        return;
 
    import std.file, std.json;
    static import db = hibernated.core;
    import painlessjson;
    import pierun.api, pierun.interfaces.web;

    const Settings settings = read("config.json")
        .to!string
        .parseJSON
        .fromJSON!Settings;

    auto http_settings = new HTTPServerSettings;

    http_settings.port = settings.port;
    http_settings.bindAddresses = settings.ips.dup;
    http_settings.sessionStore = new MemorySessionStore;

    auto tup = prepareDBConnection(settings.database);
    db.DataSource ds = tup.source;
    db.SessionFactory sf = tup.factory;
    scope(exit) sf.close;
    db.Session s = sf.openSession;
    scope(exit) s.close;

    auto router = new URLRouter();

    
    router.registerRestInterface(new PierunAPI);
    router.registerWebInterface(new WebInterface(ds, s));

    auto fsettings = new HTTPFileServerSettings;
    fsettings.serverPathPrefix = "/static";
    router.get("/static/*", serveStaticFiles("static/", fsettings));

    listenHTTP(http_settings, router);

    import std.format;
    logInfo("Please open http://%s:%s/ in your browser.".format(settings.ips[0], settings.port));

    lowerPrivileges();
    runEventLoop();
}

auto prepareDBConnection(DBSettings s){
    import pierun.core;
    import hibernated.core;
    
    EntityMetaData schema = new SchemaInfoImpl!(KeyValue, Language, Link,
        LinkList, LoginSession, Post, PostData, Tag, User);

    version(USE_PGSQL){
        import ddbc.drivers.pgsqlddbc;
        auto driver = new PGSQLDriver();
        Dialect dialect = new PGSQLDialect();
        auto url = driver.generateUrl(s.host, s.port, s.name);
        driver.setUserAndPassword(s.user, s.password);
    } else version (USE_MYSQL) {
        import ddbc.drivers.mysqlddbc;
        auto driver = new MySQLDriver();
        Dialect dialect = new MySQLDialect();
        auto url = driver.generateUrl(s.host, s.port, s.name);
        driver.setUserAndPassword(s.user, s.password);
    } else version (USE_SQLITE) {
        import ddbc.drivers.sqliteddbc;
        auto driver = new SQLITEDriver();
        string url = s.name ~ ".sqlite";
        Dialect dialect = new SQLiteDialect();
    } else {
        static assert(0);
    }

    string[string] params;
    DataSource ds = new ConnectionPoolDataSourceImpl(driver, url, params);
    SessionFactory factory = new SessionFactoryImpl(schema, dialect, ds);

    {
        Connection conn = ds.getConnection();
        scope(exit) conn.close();
        factory.getDBMetaData().updateDBSchema(conn, false, true);
    }

    {
        auto sess = factory.openSession();
        scope(exit) sess.close;

        User[] as = sess.createQuery("FROM User").list!User;

        if(as.length == 0) {
            import std.random, std.stdio;

            User a = new User;
            a.salt = genPassword(32);
            
            "No authors listed. Adding one".writeln;
            "Type your name: ".writeln;
            std.stdio.readf(" %s\n", &a.name);
            "Type your email: ".writeln;
            std.stdio.readf(" %s\n", &a.email);

            auto password = genPassword(16);

            import botan.passhash.bcrypt, botan.rng.auto_rng;

            a.hashedPassword = generateBcrypt(password ~ a.salt, new AutoSeededRNG);

            assert(checkBcrypt(password ~ a.salt, a.hashedPassword));

            sess.save(a);

            writefln("New author: %s, email: %s, password: %s", a.name, a.email, password);

            auto set = delegate void(string key, string value) {
                import std.uni;
                KeyValue kv = sess
                    .createQuery("FROM KeyValue WHERE key=:Key")
                    .setParameter("Key", key.toLower)
                    .uniqueResult!KeyValue;

                if(kv !is null) {
                    kv.value = value;
                    sess.update(kv);
                } else {
                    kv = new KeyValue;
                    kv.key = key.toLower;
                    kv.value = value;
                    sess.save(kv);
                }
            };

            set("blog_name", "Pierun");
            set("base_address", "http://localhost/");
        }
    }

    import std.typecons;
    return tuple!("source", "factory")(ds, factory);
}

string genPassword(int len)
{
    static immutable char[] chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ~
                                    "abcdefghijklmnopqrstuvwxyz" ~
                                    "01234567890" ~
                                    "[]{}()-=_+<>?~";

    import std.random, std.algorithm, std.range, std.conv;
    return iota(len).map!(e => chars[uniform(0, chars.length)]).to!string;
}

