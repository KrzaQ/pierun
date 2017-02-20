module pierun.core;

import std.datetime;
import std.string;

import hibernated.core;

class Author
{
    string name;
    string email;
    string hashedPassword;
}

class Tag
{
    string name;
}

class Post
{
    @Id @Generated
    ulong id;
    Author author;
    DateTime published;
    PostData[] edits;
}

class PostData
{
    string markdown;
    DateTime timestamp;
    @ManyToMany
    Tag[] tags;
}

