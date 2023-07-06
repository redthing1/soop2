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

// import mir.ser.json : serializeJson;

import soop.global;
import soop.util;

void vibrant_web(T)(T vib) {
    with (vib) {
        // serve data directory as static files
        // router.get("*", serveStaticFiles(g_context.data_dir));

        void serve_data_dir_action(HTTPServerRequest req, HTTPServerResponse res) {
            logger.trace("GET %s", req.path);
            // get the true path
            auto true_path = buildPath(g_context.data_dir, req.path[1 .. $]);
            logger.trace("  true path: %s", true_path);

            // check if the path is a directory
            if (isDir(true_path)) {
                // check if the path ends with a slash
                if (req.path.endsWith("/")) {
                    logger.info("serving directory listing: %s", true_path);
                    // return a simple html directory listing
                    auto sb = appender!string;

                    enum DIR_LISTING_CSS = `
                        body, html { background: #222; margin:0; }
                        html { font: 14px/1.4 'Helvetica Neue', Helvetica, sans-serif; color: #ddd; font-weight: 400; }
                        h1 { font-weight: 200; font-size: 45px; margin: 20px 35px; }
                        div.list { background: #111; padding: 20px 35px; }
                        td { line-height: 21px; }
                        tr:hover { background: black; }
                        a { color: #32C6FF; }
                        a:visited { color: #BD32FF; }
                        a:hover { color: #B8EBFF; }
                    `;

                    sb ~= format("<html><head><style>%s</style></head>", DIR_LISTING_CSS);
                    sb ~= format("<body><h1>Directory listing</h1><table class=\"list\">");
                    sb ~= format("<tr><th>name</th><th>size</th><th>modified</th></tr>");

                    auto dir_entries = dirEntries(true_path, SpanMode.shallow).array;
                    // sort by name, and put directories first
                    dir_entries.sort!((a, b) {
                        if (a.isDir && !b.isDir) return true;
                        if (!a.isDir && b.isDir) return false;
                        return a.name < b.name;
                    });
                    foreach (dir_entry; dir_entries) {
                        try {
                            // get the relative path of the dir entry to the data dir
                            auto rel_path = relativePath(dir_entry.name, g_context.data_dir);
                            auto modtime = std.file.timeLastModified(dir_entry.name);
                            string file_display_name;
                            if (dir_entry.isDir) {
                                file_display_name = format("%s/", rel_path);
                            } else {
                                file_display_name = format("%s", rel_path);
                            }
                            auto file_request_path = format("/%s", rel_path);
                            auto human_size = human_file_size(dir_entry.size);
                            sb ~= format("<tr><td><a href=\"%s\">%s</a></td><td>%s</td><td>%s</td></tr>",
                                file_request_path, file_display_name, human_size, modtime.format(
                                    "%Y-%m-%d %H:%M:%S"));
                        } catch (Exception e) {
                            logger.error("error getting file info for %s: %s", dir_entry.name, e.msg);
                        }
                    }
                    sb ~= format("</table></body></html>");

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

        router.get("*", &serve_data_dir_action);

        // accept arbitrary POST requests
        void upload_file_action(HTTPServerRequest req, HTTPServerResponse res) {
            // we want to accept form data with an uploaded file
            auto uploaded_files = req.files;
            if (uploaded_files.length == 0) {
                // no file uploaded
                res.statusCode = HTTPStatus.badRequest;
                return res.writeBody("no file uploaded");
            }

            // we only accept one file
            auto upl_file = uploaded_files.byValue.front;
            auto upl_file_size = std.file.getSize(upl_file.tempPath.to!string);
            auto upl_save_name = req.path[1 .. $];

            logger.info("received file: %s (%s), requested to upload to: %s", upl_file.filename, upl_file_size, upl_save_name);

            // make a filename for the uploaded file
            auto datestamp = Clock.currTime.format("%Y%m%d_%H%M%S");
            auto recv_filename = format("%s_%s", datestamp, upl_save_name);

            // copy the temporary file to the data directory
            auto recv_path = buildPath(g_context.data_dir, recv_filename);
            std.file.copy(upl_file.tempPath.to!string, recv_path);
            logger.info("saved file %s to %s", upl_save_name, recv_path);

            // no content
            res.statusCode = HTTPStatus.noContent;
            res.writeBody("");
        }

        router.post("*", &upload_file_action);
    }
}
