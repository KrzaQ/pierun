module pierun.interfaces.admin;

import vibe.d;
import vibe.web.auth;

import hibernated.core;

import pierun.core;
import pierun.utils.dbcache;
import pierun.interfaces.web;

import pierun.interfaces.common;

@requiresAuth
class AdminWebInterface
{
    private {
        WebInterface parent;
    }

    @noRoute @property
    auto dbCache() { return parent.dbCache; }

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

    @auth(Role.admin)
    void getModerateNewComments(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto comments = dbCache.getCommentsAwaitingModeration;

        render!("admin/moderate_new_comments.dt", comments);
    }


    @auth(Role.admin)
    void postModerateNewComments(HTTPServerRequest req, HTTPServerResponse res,
        int commentId, string author, string email, string website,
        string markdown, string status)
    {
        import std.conv;

        auto c = dbCache.getComment(commentId);

        enforceHTTP(c !is null, HTTPStatus.badRequest,
            "Cannot find post with id %s".format(commentId));

        if(author != c.authorName) {
            // TODO: assign user if there is any
            c.author = null;
            c.authorName = author;
        }

        c.email = email;
        c.website = website;
        c.markdown = markdown;
        c.status = status.to!(Comment.Status);

        // TODO: remove workaround
        c.ip = c.gpg = c.host = "";

        dbCache.updateComment(c);

        auto comments = dbCache.getCommentsAwaitingModeration;

        render!("admin/moderate_new_comments.dt", comments);
    }

    @auth(Role.admin)
    void postDeleteComment(HTTPServerRequest req, HTTPServerResponse res,
        int commentId)
    {
        import std.conv;

        auto c = dbCache.getComment(commentId);

        enforceHTTP(c !is null, HTTPStatus.badRequest,
            "Cannot find post with id %s".format(commentId));

        dbCache.removeComment(c);

        redirect("/");
    }
}
