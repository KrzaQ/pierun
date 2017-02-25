module pierun.utils.markdown;

import std.functional;
import vibe.textfilter.markdown;

static string parseMarkdownImpl(const string md)
{
    return filterMarkdown(md, MarkdownFlags.forumDefault);
}

alias parseMarkdown = memoize!parseMarkdownImpl;

static string getPostAddress(int id, const string title)
{
    import std.format, std.string;
    return "/post/%s/%s".format(id, title.asSlug);
}

//alias getPostAddress = memoize!getPostAddressImpl;