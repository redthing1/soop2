module soop.web;

import std.stdio;
import std.typecons;
import std.json;
import std.file;
import std.path;
import std.array;
import std.algorithm;

import vibrant.d;
import datefmt;
import typetips;

import soop.global;
import soop.util;
import soop.app: APP_NAME, APP_VERSION;

enum INTERNAL_STATIC_PATH = "/__soop_static";
enum INTERNAL_STATIC_STYLE_PATH = format("%s/style.css", INTERNAL_STATIC_PATH);
enum INTERNAL_STATIC_STYLE_DATA = import("style.css");

enum DIR_INDEX_FILES = ["index.html", "index.htm"];

void vibrant_web(T)(T vib) {
    with (vib) {
        // serve internal static files
        Get(INTERNAL_STATIC_STYLE_PATH, "text/css", (req, res) {
            return INTERNAL_STATIC_STYLE_DATA;
        });

        // serve data directory as static files
        // router.get("*", serveStaticFiles(g_context.public_dir));

        bool verify_auth(HTTPServerRequest req, HTTPServerResponse res) {
            // check if policy requires authentication
            auto is_upload_request = req.method != HTTPMethod.GET;
            auto download_needs_auth = (
                g_context.security_config.policy & SecurityPolicy.authenticate_download) != 0;
            auto upload_needs_auth = (
                g_context.security_config.policy & SecurityPolicy.authenticate_upload) != 0;
            auto needs_auth = (is_upload_request && upload_needs_auth) || (!is_upload_request && download_needs_auth);
            auto auth_available = !g_context.security_config.username.isNull && !g_context
                .security_config.password.isNull;

            if (!needs_auth) {
                // auth is not needed, so we don't need to check
                return true;
            }

            // auth is needed, so we need to check

            if (!auth_available) {
                // auth is not available, so we don't need to check
                return true;
            } else {
                bool check_account(string uname, string pass) @safe {
                    return uname == g_context.security_config.username.get &&
                        pass == g_context.security_config.password.get;
                }

                string realm = "server";
                auto auth_user_name = req.performBasicAuth(res, realm, &check_account);
                return auth_user_name == g_context.security_config.username.get;
            }
        }

        void serve_public_dir_action(HTTPServerRequest req, HTTPServerResponse res) {
            if (!verify_auth(req, res)) {
                res.statusCode = HTTPStatus.unauthorized;
                return res.writeBody("unauthorized");
            }

            logger.trace("GET %s", req.path);
            // get the true path
            auto maybe_true_path = join_path_jailed(g_context.public_dir, req.path[1 .. $]);
            if (!maybe_true_path.has) {
                // bad request
                logger.warn("rejecting request with bad path: %s", req.path);
                res.statusCode = HTTPStatus.badRequest;
                return res.writeBody("bad request");
            }
            auto true_path = maybe_true_path.get;
            logger.trace("  true path: %s", true_path); // check if the path is a directory

            // if the path does not exist, return 404
            if (!exists(true_path)) {
                logger.info("path does not exist: %s", true_path);
                res.statusCode = HTTPStatus.notFound;
                return res.writeBody("not found");
            }

            if (isDir(true_path)) {
                // check if the path ends with a slash
                if (req.path.endsWith("/")) {
                    // if index file exists, serve it
                    foreach (index_file; DIR_INDEX_FILES) {
                        auto maybe_index_file_path = join_path_jailed(true_path, index_file);
                        if (!maybe_index_file_path.has)
                            continue;
                        auto index_file_path = maybe_index_file_path.get;
                        if (exists(index_file_path)) {
                            logger.info("serving index file: %s", index_file_path);
                            return serveStaticFile(index_file_path)(req, res);
                        }
                    }
                    // if no index file exists, serve directory listing

                    logger.info("serving directory listing: %s", true_path);
                    // return a simple html directory listing
                    auto sb = appender!string;
                    auto listing_rel_path = relativePath(true_path, g_context
                            .public_dir.normalized_abspath);
                    if (listing_rel_path.startsWith("."))
                        listing_rel_path = listing_rel_path[1 .. $];
                    if (!listing_rel_path.startsWith("/"))
                        listing_rel_path = format("/%s", listing_rel_path);

                    sb ~= format("<!DOCTYPE html>");
                    sb ~= format("<html><head>");
                    sb ~= format("<meta charset=\"utf-8\">");
                    sb ~= format(
                        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">");
                    sb ~= format("<title>%s | %s</title>", APP_NAME, listing_rel_path);
                    sb ~= format("<link rel=\"stylesheet\" href=\"%s\">", INTERNAL_STATIC_STYLE_PATH);
                    sb ~= format("</head>");
                    sb ~= format("<body>");
                    sb ~= format(
                        "<h1>Index of <code>%s</code></h1>", listing_rel_path);
                    sb ~= format("<table class=\"list\">");
                    sb ~= format(
                        "<tr><th>name</th><th>size</th><th>modified</th></tr>");

                    auto dir_entries = dirEntries(true_path, SpanMode.shallow).array;

                    if (!g_context.listing_config.ignore_file.isNull) {
                        // filter out ignored files
                        dir_entries = filter_ignored_paths_from(
                            dir_entries,
                            g_context.public_dir.normalized_abspath,
                            g_context.listing_config.ignore_file.get
                        );
                    }

                    // sort by name, and put directories first
                    dir_entries.sort!((a, b) {
                        if (a.isDir && !b.isDir)
                            return true;
                        if (!a.isDir && b.isDir)
                            return false;
                        return a.name < b.name;
                    }); // add a parent directory link
                    if (listing_rel_path != "/") {
                        sb ~= format(
                            "<tr><td><a href=\"../\">../</a></td><td></td><td></td></tr>");
                    }
                    foreach (dir_entry; dir_entries) {
                        try {
                            // get the relative path of the dir entry to the data dir
                            auto rel_path = relativePath(dir_entry.name, g_context
                                    .public_dir.normalized_abspath);
                            auto modtime = std.file.timeLastModified(
                                dir_entry.name);
                            string file_display_name;
                            auto rel_path_base = std.path.baseName(rel_path);
                            if (dir_entry.isDir) {
                                file_display_name = format("%s/", rel_path_base);
                            } else {
                                file_display_name = format("%s", rel_path_base);
                            }
                            auto file_request_path = format("/%s", rel_path);
                            auto human_size = human_file_size(dir_entry.size);
                            sb ~= format(
                                "<tr><td><a href=\"%s\">%s</a></td><td>%s</td><td>%s</td></tr>",
                                file_request_path, file_display_name, human_size, modtime.format(
                                    "%Y-%m-%d %H:%M:%S"));
                        } catch (Exception e) {
                            logger.error("error getting file info for %s: %s", dir_entry.name, e
                                    .msg);
                        }
                    }
                    sb ~= format("</table>");
                    sb ~= format(
                        "<footer><p>Generated by <code>%s %s</code></p></footer>",
                        APP_NAME, APP_VERSION
                    );
                    sb ~= format("</body></html>");
                    res.writeBody(sb.data, "text/html");
                } else {
                    // if it's a dir but the request doesn't end with a slash, redirect to the same path with a slash
                    logger.trace("  redirecting to %s/", req.path);
                    res.redirect(req.path ~ "/");
                }
            } else {
                // serve the file
                logger.info("serving file: %s", true_path);
                serveStaticFile(true_path)(req, res);
            }
        }

        router.get("*", &serve_public_dir_action); // accept arbitrary POST requests
        void upload_file_action(HTTPServerRequest req, HTTPServerResponse res) {
            if (!verify_auth(req, res)) {
                res.statusCode = HTTPStatus.unauthorized;
                return res.writeBody("unauthorized");
            }

            logger.trace("POST %s", req.path);

            if (!g_context.enable_upload) {
                res.statusCode = HTTPStatus.forbidden;
                return res.writeBody("uploading is disabled");
            }

            // we want to accept form data with an uploaded file
            auto uploaded_files = req.files;
            if (
                uploaded_files.length == 0) {
                // no file uploaded
                res.statusCode = HTTPStatus.badRequest;
                return res.writeBody("no file uploaded");
            }

            // we only accept one file
            auto upl_file = uploaded_files.byValue.front;
            auto upl_file_size = std.file.getSize(
                upl_file.tempPath.to!string);
            auto upl_save_name = req
                .path[1 .. $];
            logger.info(
                "received file: %s (%s), requested to upload to: %s",
                upl_file.filename, upl_file_size, upl_save_name);

            // make a filename for the uploaded file
            auto datestamp = Clock.currTime.format("%Y%m%d_%H%M%S");
            // auto recv_filename = format("%s_%s", datestamp, upl_save_name);
            auto recv_filename = upl_save_name;

            if (g_context.upload_config.prepend_timestamp) {
                recv_filename = format("%s_%s", datestamp, upl_save_name);
            }

            auto maybe_recv_path = join_path_jailed(g_context.upload_dir, recv_filename);
            if (!maybe_recv_path.has) {
                logger.error("invalid filename: %s", recv_filename);
                res.statusCode = HTTPStatus.badRequest;
                return res.writeBody("bad target filename");
            }
            auto recv_path = maybe_recv_path.get;

            // ensure the path's parent directory exists
            auto recv_path_parent = std.path.dirName(recv_path);
            if (!std.file.exists(recv_path_parent)) {
                if (g_context.upload_config.create_directories) {
                    logger.warn("creating directory: %s", recv_path_parent);
                    std.file.mkdirRecurse(recv_path_parent);
                } else {
                    logger.error("directory %s does not exist", recv_path_parent);
                    res.statusCode = HTTPStatus.notFound;
                    return res.writeBody("directory does not exist");
                }
            }

            // copy the temporary file to the data directory

            // check if the file already exists
            if (std.file.exists(recv_path)) {
                if (g_context.upload_config.prevent_overwrite) {
                    logger.error("file %s already exists, and overwriting is disabled", recv_path);
                    res.statusCode = HTTPStatus.conflict;
                    return res.writeBody("file already exists");
                } else {
                    logger.warn("file %s already exists, overwriting", recv_path);
                }
            }

            std.file.copy(upl_file.tempPath.to!string, recv_path);
            logger.info("saved file %s to %s", upl_save_name, recv_path);

            // no content
            res.statusCode = HTTPStatus.noContent;
            res.writeBody("");
        }

        router.post("*", &upload_file_action);
    }
}
