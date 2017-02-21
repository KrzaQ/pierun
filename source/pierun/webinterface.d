module pierun.webinterface;

import vibe.d;

import hibernated.core;

class WebInterface
{
    this(DataSource, SessionFactory)
    {

    }
    
    void index()
    {
        auto code = "";
        render!("index.dt", code);
    }

    void post(string code)
    {
        import pierun.utils.markdown;

        code = pierun.utils.markdown.parseMarkdown(code);

        render!("index.dt", code);
    }

}
