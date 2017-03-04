module pierun.utils.misc;

alias identity(alias X) = X;

string toSlugForm(const string name)
{
    import std.conv;
    import vibe.textfilter.markdown;
    return name.asSlug.to!string;
}

static string getPostAddress(int id, const string title)
{
    import std.format, std.string;
    return "/post/%s/%s".format(id, title.toSlugForm);
}


template dbg(string S, string file = __FILE__, size_t line = __LINE__)
{
    immutable string dbg = `{ import std.stdio, std.string; ` ~ 
        `writefln("%s:%s: %-40s: %s",` ~ file.stringof ~ `, ` ~ line.stringof ~
        `, "` ~ S ~ `", ` ~ S ~ `); }`;
}

string dbg(alias S, string file = __FILE__, size_t line = __LINE__)()
{
    import std.stdio;
    writefln("%s:%s: %-40s: %s", file, line, S.stringof, S);
}
