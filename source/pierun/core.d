module pierun.core;

import std.datetime;
import std.string;

import hibernated.core;

class Author
{
    @Id @Generated int id;
    string name;
    string email;
    string hashedPassword;
    string salt;
    Post[] posts;
}

class Tag
{
    @Generated @Id int id;
    // TODO: constraint to unique
    string name;
}

class Post
{
    @Generated @Id int id;
    Author author;
    DateTime published;
    PostData[] edits;
    Language language;
}

class PostData
{
    @Generated @Id int id;
    Post post;
    string markdown;
    string excerpt;
    string gpg;
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
