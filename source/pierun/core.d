module pierun.core;

import std.datetime, std.string, std.typecons;

import hibernated.core;

class User
{
    @Generated @Id int id;
    string name;
    string email;
    string hashedPassword;
    string salt;
    LoginSession[] sessions;
    Post[] posts;
}

class LoginSession
{
    @Generated @Id int id;
    User user;
    string sessionId;
    DateTime expires;
}

class Tag
{
    @Generated @Id int id;
    // TODO: constraint to unique
    string name;
    string slugName;
}

class Post
{
    enum Status
    {
        Ok,
        Unlisted,
        Private
    }

    @Generated @Id int id;
    User author;
    int status = cast(int)Status.Ok;
    DateTime published;
    PostData[] edits;
    Language language;
}

class PostData
{
    @Generated @Id int id;
    Post post;
    string title;
    string markdown;
    string excerpt;
    Nullable!string gpg;
    DateTime timestamp;
    @ManyToMany Tag[] tags;
}

class Language
{
    @Generated @Id int id;

    // TODO: constraint to 2 characters and unique
    string isoCode;
    string name;
}

class Link
{
    @Generated @Id int id;

    string link;
    string name;
    string altText;
    @ManyToMany LinkList[] lists;
}

class LinkList
{
    @Generated @Id int id;

    string name;
    @ManyToMany Link[] links;
}

class KeyValue
{
    @Generated @Id int id;

    @UniqueKey string key;
    string value;
}
