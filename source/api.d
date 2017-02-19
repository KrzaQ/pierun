import vibe.d;
import vibe.textfilter.markdown;

import std.functional;
import std.string;

struct Markdown
{
    string markdown;
}

@path("/api/")
interface API
{
    Markdown postMarkdown(string md);
}

//alias toMarkdown = memoize!filterMarkdown;

class PierunAPI : API
{
    static string toMarkdownImpl(const string md) {
        return filterMarkdown(md, MarkdownFlags.forumDefault);
    }

    alias toMarkdown = memoize!toMarkdownImpl;

    Markdown postMarkdown(string md) {
        return Markdown(toMarkdown(md));
    }
}
