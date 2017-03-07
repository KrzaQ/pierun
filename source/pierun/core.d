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
    LazyCollection!Post posts;
}

class Tag
{
    @Generated @Id int id;
    // TODO: constraint to unique
    string name;
    string slugName;
    @ManyToMany LazyCollection!PostData revisions;
}

class Post
{
    enum Status
    {
        Public,
        Unlisted,
        Private
    }

    @Generated @Id int id;
    User author;
    int status = cast(int)Status.Public;
    DateTime published;
    PostData[] edits;
    Language language;
    Comment[] comments;
}

class PostData
{
    @Generated @Id int id;
    Post post;
    string title;
    string markdown;
    string excerpt;
    string gpg;
    DateTime timestamp;
    @ManyToMany LazyCollection!Tag tags;
}

class Comment
{
    @Generated @Id int id;
    @Null Post post;
    @Null Comment parent;

    @Null User author;
    string authorName;
    string email;
    string website;
    
    string markdown;
    
    string ip;
    string host;
    DateTime timestamp;

    string gpg;

    Comment[] children;
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
    @ManyToMany LazyCollection!LinkList lists;
}

class LinkList
{
    @Generated @Id int id;

    string name;
    @ManyToMany LazyCollection!Link links;
}

class KeyValue
{
    @Generated @Id int id;

    @UniqueKey string key;
    string value;
}
