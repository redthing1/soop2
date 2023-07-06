module soop.global;

import std.typecons: Nullable;

public import minlog;

struct ServerConfig {
    Nullable!string host;
    Nullable!long port;
    Nullable!string public_dir;
    Nullable!string upload_dir;
}

struct Context {
    string public_dir;
    string upload_dir;
}
Context g_context;

Logger logger = Logger(Verbosity.info);