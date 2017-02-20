module pierun.core;

import std.datetime;
import std.string;

import hibernated.core;

class Author
{
    @Id @Generated ulong id;
    string name;
    string email;
    string hashedPassword;
    Post[] posts;
}

class Tag
{
    @Generated @Id ulong id;

    //@Column("tag_name")
    //@UniqueKey("tag_name_index")
    string name;
}

class Post
{
    @Generated @Id ulong id;
    Author author;
    DateTime published;
    PostData[] edits;
    Language language;
}

class PostData
{
    @Generated @Id ulong id;
    Post post;
    string markdown;
    DateTime timestamp;
    @ManyToMany Tag[] tags;
}

class Language
{
    @Generated @Id ulong id;

    @Column("iso_code")
    @UniqueKey("iso_code")
    string isoCode;

    string name;
}
