import vibe.d;
import vibe.textfilter.markdown;

import std.string;

struct Markdown
{
    string markdown;
}

@path("/api/")
interface API
{
    Markdown parse_markdown(string md);
}

class PierunAPI : API
{
    Markdown parse_markdown(string md) {
        import markdown;
        return Markdown(markdown.fromMarkdown(md));
    }
}
