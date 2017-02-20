import vibe.d;

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

shared static this()
{
    import painlessjson;
    import std.file;
    import std.json;
    const Settings settings = read("config.json")
        .to!string
        .parseJSON
        .fromJSON!Settings;

    auto http_settings = new HTTPServerSettings;

    http_settings.port = settings.port;
    http_settings.bindAddresses = settings.ips.dup;

    //listenHTTP(http_settings, &hello);

    auto router = new URLRouter();

    {
        import pierun.api;
        router.registerRestInterface(new PierunAPI);
    }

    auto db = prepareDBConnection(settings.database);

    listenHTTP(http_settings, router);

    import std.format;
    logInfo("Please open http://%s:%s/ in your browser.".format(settings.ips[0], settings.port));
}

//void hello(HTTPServerRequest req, HTTPServerResponse res)
//{
//    res.writeBody("Hello, World!");
//}


auto prepareDBConnection(DBSettings s){
    import pierun.core;
    import hibernated.core;
    
    EntityMetaData schema = new SchemaInfoImpl!(Author, Language, Post, PostData, Tag);


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
    scope(exit) factory.close();
    {
        Connection conn = ds.getConnection();
        scope(exit) conn.close();
        factory.getDBMetaData().updateDBSchema(conn, false, true);
    }

    import std.typecons;
    return tuple!("source", "factory")(ds, factory);
}

