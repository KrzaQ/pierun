module pierun.interfaces.web;

import std.conv, std.format, std.string, std.typecons;

import vibe.d;
import vibe.web.auth;

import hibernated.core;

import pierun.core;
import pierun.utils.dbcache, pierun.utils.misc;

import pierun.interfaces.common,
       pierun.interfaces.admin,
       pierun.interfaces.rss;

@requiresAuth
class WebInterface
{
    private {
        DataSource dataSource;
        DBSession sessionMember;
        DBCache dbCacheMember;
        AdminWebInterface adminWebInterface;
        RSSWebInterface rssWebInterace;
    }

    @property AdminWebInterface admin() { return adminWebInterface; }
    @property RSSWebInterface rss() { return rssWebInterace; }

    @noRoute @property DBCache dbCache() { return dbCacheMember; }
    @noRoute @property DBSession session() { return sessionMember; }

    @noRoute
    AuthInfo authenticate(HTTPServerRequest req, HTTPServerResponse res){
        if (!req.session || !req.session.isKeySet("auth"))
            throw new HTTPStatusException(HTTPStatus.forbidden, "Not authorized to perform this action!");

        return req.session.get!AuthInfo("auth");
    }

    this(DataSource ds, DBSession s)
    {
        this.dataSource = ds;
        this.sessionMember = s;
        this.dbCacheMember = new DBCache(s);
        this.adminWebInterface = new AdminWebInterface(this);
        this.rssWebInterace = new RSSWebInterface(this);
    }
    
    @noAuth
    void index(HTTPServerRequest req, HTTPServerResponse res)
    {
        Post[] posts = dbCache.getPostsByLanguage("PL");

        render!("index.dt", posts);
    }

    @noAuth
    void getLogin(HTTPServerRequest req, string _error = null)
    {
        string page_title = "login";
        render!("login.dt", _error);
    }

    @noAuth @errorDisplay!getLogin 
    void postLogin(string username, string password,
        scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto user = session.createQuery("FROM User WHERE name=:Name")
            .setParameter("Name", username)
            .uniqueResult!User;

        enforceHTTP(user !is null,
            HTTPStatus.forbidden, "Username or password incorrect");

        import botan.passhash.bcrypt;

        enforceHTTP(checkBcrypt(password ~ user.salt, user.hashedPassword),
            HTTPStatus.forbidden, "Username or password incorrect");

        AuthInfo ai;
        ai.userName = user.name;
        ai.admin = true;
        ai.userId = user.id;
        req.session = res.startSession;
        req.session.set("auth", ai);

        redirect("/");
    }

    @path("/post/:id") @noAuth @errorDisplay!error
    void getPostId(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        getPostIdName(req, res);
    }

    @path("/post/:id/*") @noAuth @errorDisplay!error
    void getPostIdName(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto id = req.params["id"].to!int;

        Post p = dbCache.getPost(id);

        enforceHTTP(p !is null, HTTPStatus.notFound,
            "Post %d not found!".format(id));

        if(p.status == Post.Status.Private) {
            auto auth = req.getAuth;

            enforceHTTP(!auth.isNull && auth.isAdmin, HTTPStatus.notFound,
                "Post %d not found!".format(id));
        }

        auto comments = dbCache.getCommentsByPost(p);
        render!("post.dt", p, comments);
    }

    // Workaround for older browsers that do not support HTML's 
    // formaction attribute.
    @path("/post/:id/*") @noAuth @errorDisplay!error
    void postPostId(scope HTTPServerRequest req, scope HTTPServerResponse res,
        int postId)
    {
        import std.conv;
        auto parentComment = "parentCommentId" in req.form;

        postPreviewComment(req, res, postId,
            req.form["author"], req.form["email"], req.form["website"],
            req.form["markdown"], parentComment ? (*parentComment).to!int : 0);
    }

    // Workaround for older browsers that do not support HTML's 
    // formaction attribute.
    @path("/post/:id") @noAuth @errorDisplay!error
    void postPostId(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        import std.conv;
        postPostId(req, res, req.form["postId"].to!int);
    }

    @noAuth @errorDisplay!error
    void postPreviewComment(scope HTTPServerRequest req,
        scope HTTPServerResponse res, int postId, string author="",
        string email="", string website="", string markdown="",
        int parentCommentId = 0, string _error = null)
    {
        Comment parentComment;

        if(parentCommentId > 0) {
            parentComment = dbCache.getComment(parentCommentId);
        }

        Post p = dbCache.getPost(postId);

        enforceHTTP(p !is null, HTTPStatus.badRequest,
            "Cannot find post with id %s".format(postId));

        render!("preview_comment.dt", author, email, website, markdown,
            parentComment, p, _error);
    }

    @noAuth @errorDisplay!error
    void postSendComment(scope HTTPServerRequest req,
        scope HTTPServerResponse res, int postId, string author,
        string email="", string website="", string markdown="",
        int parentCommentId = 0, string _error = null)
    {
        enforceHTTP(markdown.length > 0, HTTPStatus.badRequest,
            "Content required");

        // Workaround for older browsers that do not support HTML's 
        // formaction attribute.
        auto preview = "preview" in req.form;
        if(preview !is null) {
            postPreviewComment(req, res, postId, author, email, website,
                markdown, parentCommentId, _error);
            return;
        }

        auto post = dbCache.getPost(postId);

        enforceHTTP(post !is null, HTTPStatus.badRequest,
            "Cannot find post with id %s".format(postId));

        auto c = new Comment;
        c.post = post;

        auto auth = req.getAuth;
        if(!auth.isNull) {
            c.author = dbCache.getUser(auth.userId);
            c.status = Comment.Status.Public;
        }

        c.authorName = c.author is null ? author : c.author.name;

        enforceHTTP(c.authorName.length > 0, HTTPStatus.badRequest,
            "Name required");

        c.email = email;
        c.website = website;
        c.markdown = markdown;
        c.timestamp = cast(DateTime)Clock.currTime;

        // todo
        c.ip = "";
        c.host = "";
        c.gpg = "";

        // set parent - also todo

        dbCache.setComment(c);

        if(post is null) {
            redirect("/");
            return;
        }

        redirect(getPostAddress(post.id, post.data.title));
    }

    @path("/:lang/tag/:tag") @noAuth @errorDisplay!error
    void getTag(HTTPServerRequest req, HTTPServerResponse res)
    {
        immutable int page = 1;
        auto tag = req.params["tag"];
        auto lang = req.params["lang"];
        getTagImpl(req, res, tag, lang, page);
    }

    @path("/:lang/tag/:tag/:page") @noAuth @errorDisplay!error
    void getTagPage(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.conv;
        int page = req.params["page"].to!int;
        auto tag = req.params["tag"];
        auto lang = req.params["lang"];
        getTagImpl(req, res, tag, lang, page);
    }

    @noRoute
    void getTagImpl(HTTPServerRequest req, HTTPServerResponse res,
        string tag, string lang, int page)
    {
        auto posts = dbCache.getPostsByLanguageTag(lang, tag);

        render!("list.dt", posts);
    }

    @auth(Role.admin)
    void getAddPost(HTTPServerRequest req, HTTPServerResponse res)
    {
        postAddPost(req, res);
    }

    @auth(Role.admin)
    void postAddPost(HTTPServerRequest req, HTTPServerResponse res,
        string markdown = "", string excerpt = "", string title = "",
        string language = "EN", string tags = "", string _error = null)
    {
        render!("add_post.dt", markdown, excerpt,
                title, language, tags, _error);
    }

    @auth(Role.admin) @errorDisplay!postAddPost
    void postSendPost(HTTPServerRequest req, HTTPServerResponse res,
        AuthInfo ai, string markdown, string excerpt, string title,
        string language, string tags)
    {
        enforceHTTP(language.length == 2, HTTPStatus.badRequest,
            "Language must be two characters long");

        import std.array, std.algorithm, std.regex, std.traits;

        auto getOrMakeTag = delegate Tag(const string name) {
            auto t = dbCache.getTag(name);
            if(t is null) {
                t = new Tag;
                t.name = name;
                t.slugName = name.toSlugForm;
                session.save(t);
            }
            return t;
        };

        auto splitTags = tags
            .split(ctRegex!`,\s+`)
            .map!(identity!getOrMakeTag)
            .array;


        auto getOrMakeLanguage = delegate Language(const string name) {
            auto l = dbCache.getLanguage(name);
            if(l is null) {
                import std.uni;
                l = new Language;
                l.name = name;
                l.isoCode = name.toUpper;
                session.save(l);
            }
            return l;
        };

        User u = session.createQuery("FROM User WHERE name=:Name")
            .setParameter("Name", ai.userName)
            .uniqueResult!User;

        Post p = new Post;
        PostData pd = new PostData;

        p.author = u;
        p.revisions = [pd];
        p.published = cast(DateTime)Clock.currTime;
        p.language = getOrMakeLanguage(language);

        pd.title = title;
        pd.markdown = markdown;
        pd.excerpt = excerpt;
        pd.timestamp = p.published;
        pd.post = p;
        pd.tags = splitTags;
        pd.gpg = "";
        pd.isCurrent = 1;

        u.posts ~= p;

        dbCache.setPost(p);

        redirect("/");
    }

    @noRoute @noAuth
    void error(HTTPServerRequest req, string _error)
    {
        render!("error.dt", _error);
    }

    mixin PrivateAccessProxy;
}

Nullable!AuthInfo getAuth(ref HTTPServerRequest req) {
    Nullable!AuthInfo auth;
    if (req.session && req.session.isKeySet("auth"))
        auth = req.session.get!AuthInfo("auth");
    return auth;
}

Nullable!string getTime(ref HTTPServerRequest req) {
    Nullable!string ret;
    import std.conv;
    auto diff = Clock.currTime - req.timeCreated;
    ret = diff.to!string;
    return ret;
}

