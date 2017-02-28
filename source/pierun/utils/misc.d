module pierun.utils.misc;

alias identity(alias X) = X;

string toSlugForm(const string name)
{
    import std.conv;
    import vibe.textfilter.markdown;
    return name.asSlug.to!string;
}
