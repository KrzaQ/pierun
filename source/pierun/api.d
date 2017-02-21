module pierun.api;

import vibe.d;
import vibe.textfilter.markdown;

import std.string;

struct Markdown
{
    string result;
}

@path("/api/")
interface API
{
    Markdown parse_markdown(string md);
}

class PierunAPI : API
{
    Markdown parse_markdown(string md) {
        import pierun.utils.markdown;
        return Markdown(pierun.utils.markdown.parseMarkdown(md));
    }
}
