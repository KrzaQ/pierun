module pierun.utils.markdown;

import std.functional;
import vibe.textfilter.markdown;

static string parseMarkdownImpl(const string md) {
    return filterMarkdown(md, MarkdownFlags.forumDefault);
}

alias parseMarkdown = memoize!parseMarkdownImpl;

