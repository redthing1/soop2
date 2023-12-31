module soop.util;

import std.stdio;
import std.conv;
import std.algorithm;
import std.traits;
import std.format;
import std.typecons : Nullable;
import std.file;
import std.path;
import std.array;
import std.conv;

import toml;
import typetips;

static class TomlConfigHelper {
    static T bind(T)(TOMLDocument doc, string table_name) {
        auto default_model = T.init; // default value for config model
        return bind!T(default_model, doc, table_name);
    }

    static T bind(T)(ref T ret, TOMLDocument doc, string table_name) {
        // auto ret = instance;

        if (table_name !in doc) {
            // table not found in doc
            return ret;
        }

        auto table = doc[table_name];

        // for each member of T, bind the value from the table
        foreach (member_name; __traits(allMembers, T)) {
            // TODO: if the member is not a variable, skip it
            // if the member is not in the table, skip it
            if (member_name !in table) {
                // writefln("member %s not in table", member_name);
                continue;
            }
            // writefln("binding member %s", member_name);

            // get the model member type
            alias member_type = typeof(__traits(getMember, T, member_name));

            static if (is(member_type == string)) {
                __traits(getMember, ret, member_name) = table[member_name].str;
            } else static if (is(member_type == bool)) {
                __traits(getMember, ret, member_name) = table[member_name].boolean;
            } else static if (is(member_type == float)) {
                __traits(getMember, ret, member_name) = table[member_name].floating;
            } else static if (is(member_type == long)) {
                __traits(getMember, ret, member_name) = table[member_name].integer;
            } else static if (is(member_type == Nullable!string)) {
                __traits(getMember, ret, member_name) = Nullable!string(table[member_name].str);
            } else static if (is(member_type == Nullable!bool)) {
                __traits(getMember, ret, member_name) = Nullable!bool(table[member_name].boolean);
            } else static if (is(member_type == Nullable!float)) {
                __traits(getMember, ret, member_name) = Nullable!float(table[member_name].floating);
            } else static if (is(member_type == Nullable!long)) {
                __traits(getMember, ret, member_name) = Nullable!long(table[member_name].integer);
            } else static if (__traits(compiles, EnumMembers!member_type)) {
                __traits(getMember, ret, member_name) = table[member_name].str.to!member_type;
            } else {
                // static assert(0, format("cannot bind model member %s of type %s", member_name, member_type.stringof));
                static assert(0, format("cannot bind model member %s of type %s",
                        member_name, __traits(fullyQualifiedName, member_type)));
            }
        }

        return ret;
    }
}

/** 
 * convert a file size in bytes to a human readable string (e.g. 1.51 MiB)
 * Params:
 *   size = size in bytes
 * Returns: a human readable file size
 */
string human_file_size(ulong size, int precision = 2) {
    import std.string : format;

    string[] units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"];
    int unit = 0;
    double dsize = size;
    while (dsize >= 1024 && unit < cast(long) units.length - 1) {
        dsize /= 1024;
        unit++;
    }
    return format("%.*f %s", precision, dsize, units[unit]);
}

/**
 * filters out paths matching a pattern from an ignore file
*/
DirEntry[] filter_ignored_paths_from(DirEntry[] entries, string base_dir, string ignore_file) {
    // read ignore file, split by non-empty lines
    auto ignore_patterns = File(ignore_file).byLine.filter!(a => a.length > 0).array;

    // convert ignore patterns to regexes
    auto ignore_regexes = ignore_patterns.map!(a => simple_pattern_to_regex(a.to!string));

    // filter out ignored paths
    // return entries.filter!(a => !ignore_regexes.any!(b => b.match(a.name)));
    DirEntry[] ret;
    foreach (entry; entries) {
        auto rel_path = std.path.relativePath(entry.name, base_dir);
        bool matched_any = false;
        // writeln("matching path ", rel_path);
        foreach (regex_str; ignore_regexes) {
            import std.regex : regex, matchFirst;

            auto re = regex(regex_str);
            // writefln("matching path `%s` against pattern `%s` / regex `%s`", rel_path, regex_str, regex_str);
            if (matchFirst(rel_path, re)) {
                // file is ignored
                // writeln("  matched, ignoring");
                matched_any = true;
                break;
            }
        }
        if (!matched_any) {
            // file is not ignored
            ret ~= entry;
        }
    }

    return ret;
}

/**
 * convert a simple pattern to a regex
 * Params:
 *   pattern = the pattern to convert
 * Returns: a regex
 */
string simple_pattern_to_regex(string pattern) {
    // escape regex special characters
    auto escaped_pattern = pattern.replace(r"([\\^$.*+?()[\]{}|])", r"\\$1");

    // replace * with .*
    escaped_pattern = escaped_pattern.replace(r"*", r".*");

    // replace ? with .
    escaped_pattern = escaped_pattern.replace(r"?", r".");

    // // add ^ and $ to match the whole string
    // escaped_pattern = "^" ~ escaped_pattern ~ "$";

    // for now only add a $ by default (if it's not already there)
    if (!escaped_pattern.endsWith("$"))
        escaped_pattern = format("%s$", escaped_pattern);

    // writefln("simple_pattern_to_regex: pattern = `%s`, escaped_pattern = `%s`", pattern, escaped_pattern);

    return escaped_pattern;
}

Optional!string join_path_jailed(string base_dir, string component) {
    import std.path : buildPath, buildNormalizedPath, absolutePath, asNormalizedPath;

    // join the paths, and ensure the result is jailed in the base dir
    // essentially, prevent any sort of path traversal

    // writefln("join_path_jailed(%s, %s)", base_dir, component);
    auto absolute_base_dir = absolutePath(base_dir).normalized_abspath;
    auto joined_path = buildNormalizedPath(absolute_base_dir, component);
    // writefln("  absolute_base_dir = %s, joined_path = %s", absolute_base_dir, joined_path);

    // if the joined path is not a subpath of the base dir, return the base dir
    if (!joined_path.startsWith(absolute_base_dir)) {
        // writefln("  joined_path is not a subpath of base_dir, returning base_dir: %s", base_dir);
        // return base_dir;
        return no!string;
    }

    return some(joined_path);
}

string normalized_abspath(string path) {
    import std.path : buildNormalizedPath;

    return std.path.absolutePath(path).asNormalizedPath.array;
}
