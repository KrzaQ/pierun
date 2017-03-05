module pierun.interfaces.rss;

import std.conv, std.string;

import vibe.d;

import hibernated.core;

import pierun.core;

import pierun.utils.misc;

import pierun.interfaces.common,
       pierun.interfaces.web;

class RSSWebInterface
{
    private {
        WebInterface parent;
    }

    @noRoute @property auto session() { return parent.session; }
    @noRoute @property auto dbCache() { return parent.dbCache; }

    this(WebInterface wi) {
        parent = wi;
    }

    @path("/lang/:lang")
    void getLang(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        import std.uni;
        auto lang = req.params["lang"].to!string;

        Post[] posts = session
            .createQuery("SELECT P FROM Post AS P " ~ 
                         "WHERE P.status = 0 AND " ~
                            "P.language.isoCode = :Language " ~
                         "ORDER BY P.published DESC")
            .setParameter("Language", lang.toUpper)
            .list!Post;

        import std.algorithm, std.range;
        import arsd.dom;

        auto rss = new Document(`<?xml version="1.0" encoding="UTF-8" ?>` ~ 
            "\n" ~ `<rss version="2.0" xmlns:atom=` ~ 
            `"http://www.w3.org/2005/Atom"></rss>`, true, true);

        rss.setProlog = `<?xml version="1.0" encoding="UTF-8" ?>` ~ "\n";

        auto channel = rss.root.addChild("channel");

        auto setting = delegate string(string key, string default_ = "") {
            auto kv = dbCache.getValue(key);
            return kv is null ? default_ : kv.value;
        };

        auto blogName = setting("blog_name", "{blog_name}");
        channel.addChild("title", blogName ~ " - " ~ lang);
        auto desc = setting("blog_description", null);
        if(desc !is null)
            channel.addChild("description", desc);

        channel.addChild("link").innerText =
            setting("blog_address") ~ "/lang/" ~ lang;
        channel.addChild("ttl", setting("rss_ttl", "7200"));

        auto al = channel.addChild("atom:link");
        al.href = setting("blog_address") ~ "/rss/lang/" ~ lang;
        al.rel = "self";
        al.type = "application/rss+xml";

        channel.addChild("lastBuildDate", posts.getBuildDate);

        posts
            .map!(p => p.toRSSItem(setting("blog_address")))
            .each!(e => channel.addChild(e));

        //res.contentType = `application/rss+xml; charset=UTF-8`;
        res.writeBody(rss.toString, `application/rss+xml; charset=UTF-8`);
    }
}

private auto toRSSItem(Post p, string blogAddress)
{
    import arsd.dom, std.format, std.conv;
    import pierun.utils.markdown, pierun.utils.misc;

    auto pd = p.edits[$-1];
    auto item = new Element("item");
    item.addChild("title", pd.title);
    item.addChild("author", "%s (%s)".format(p.author.email, p.author.name));

    string permalink = blogAddress ~ getPostAddress(p.id, pd.title);

    item.addChild("link").innerText = permalink;
    item.addChild("guid", permalink);

    item.addChild("pubDate", p.published.toLegitDate);
    item.addChild("description", pd.excerpt.parseMarkdown);

    return item;
}

private string getBuildDate(Post[] posts)
{
    import std.datetime;

    if(posts is null || posts.length == 0) {
        return toLegitDate(cast(DateTime)Clock.currTime);
    }

    return posts[0].published.toLegitDate;
}

private string toLegitDate(DateTime dt)
{
    SysTime date = cast(SysTime)dt;
    import std.conv;

    auto offset = date.timezone.utcOffsetAt(date.stdTime);

    int h, m;
    char sign = offset > -1.dur!"seconds" ? '+' : '-';
    offset.split!("hours", "minutes")(h, m);
    string tz = "%c%02s%02s".format(sign, h, m);

    return format(
        "%.3s, %02d %.3s %d %02d:%02d:%02d %s",
        to!string(date.dayOfWeek).capitalize,
        date.day,
        to!string(date.month).capitalize,
        date.year,
        date.hour,
        date.minute,
        date.second,
        tz
    );
}
