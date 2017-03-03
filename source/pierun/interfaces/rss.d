module pierun.interfaces.rss;

import vibe.d;
import vibe.web.auth;

import pierun.interfaces.common,
       pierun.interfaces.web;

@requiresAuth
class RSSWebInterface
{
    private {
        WebInterface parent;
    }

    this(WebInterface wi) {
        parent = wi;
    }

    @noRoute
    auto authenticate(HTTPServerRequest req, HTTPServerResponse res)
    {
        return parent.authenticate(req, res);
    }
}
