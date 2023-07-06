module soop.global;

import std.typecons: Nullable;

public import minlog;

struct ServerConfig {
    // these options can all be overridden by command line arguments
    Nullable!string host;
    Nullable!long port;
    Nullable!string public_dir;
    Nullable!string upload_dir;
    Nullable!bool enable_upload;
    
    // these options can only be set in the config file
    long max_upload_size = 1024 * 1024 * 1024; // 1 GiB
}

struct ListingConfig {
    Nullable!string ignore_file;
}

struct Context {
    string public_dir;
    string upload_dir;
    bool enable_upload;

    ListingConfig listing_config;
}
Context g_context;

Logger logger = Logger(Verbosity.info);