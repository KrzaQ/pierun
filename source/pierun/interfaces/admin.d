import vibe.d;
import vibe.web.auth;

import hibernated.core;

import pierun.core;
import pierun.utils.dbcache;
import pierun.interfaces.web;

import common;

@requiresAuth
class AdminWebInterface
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

    @auth(Role.admin)
    void getSettingsRaw(HTTPServerRequest req, HTTPServerResponse res)
    {
        postSettingsRaw(req, res);
    }

    @auth(Role.admin)
    void postSettingsRaw(HTTPServerRequest req, HTTPServerResponse res)
    {
        foreach(k, v; req.form) {
            if(!k.startsWith("value_"))
                continue;
            parent.dbCache.setValue(k[6..$], v);
        }

        if(req.form.get("new_key").length > 0 &&
           req.form.get("new_value").length > 0) {
            parent.dbCache.setValue(req.form["new_key"], req.form["new_value"]);
        }

        auto kvs = parent.session
            .createQuery("FROM KeyValue")
            .list!KeyValue;

        render!("admin/settings.dt", kvs);
    }

}
