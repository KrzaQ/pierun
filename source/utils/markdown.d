import std.functional;
import vibe.textfilter.markdown;

static string fromMarkdownImpl(const string md) {
    return filterMarkdown(md, MarkdownFlags.forumDefault);
}

alias fromMarkdown = memoize!fromMarkdownImpl;

