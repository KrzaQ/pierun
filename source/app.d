import vibe.d;

struct Settings
{
    string[] ips;
    ushort port;
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

    import api;
    router.registerRestInterface(new PierunAPI);

    listenHTTP(http_settings, router);

    import std.format;
    logInfo("Please open http://%s:%s/ in your browser.".format(settings.ips[0], settings.port));
}

//void hello(HTTPServerRequest req, HTTPServerResponse res)
//{
//    res.writeBody("Hello, World!");
//}
