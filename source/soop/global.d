module soop.global;

import std.typecons : Nullable;

public import minlog;

struct ServerConfig {
    // these options can all be overridden by command line arguments
    Nullable!string host;
    Nullable!long port;
    Nullable!string public_dir;
    Nullable!string upload_dir;
    Nullable!bool enable_upload;
}

enum SecurityPolicy {
    authenticate_none = 0,
    authenticate_upload = 1 << 1,
    authenticate_download = 1 << 2,
    authenticate_all = authenticate_upload | authenticate_download,
}

struct SecurityConfig {
    Nullable!string username;
    Nullable!string password;

    SecurityPolicy policy = SecurityPolicy.authenticate_all;
}

struct ListingConfig {
    Nullable!string ignore_file;
}

struct UploadConfig {
    long max_request_size = 1024 * 1024 * 1024; // 1 GiB
    bool prepend_timestamp = true;
    bool prevent_overwrite = true;
    bool create_directories = false;
}

struct Context {
    string public_dir;
    string upload_dir;
    bool enable_upload;

    SecurityConfig security_config;
    ListingConfig listing_config;
    UploadConfig upload_config;
}

Context g_context;

Logger logger = Logger(Verbosity.info);
