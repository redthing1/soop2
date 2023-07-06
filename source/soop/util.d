module soop.util;

import std.stdio;
import std.conv;
import std.algorithm;
import std.traits;
import std.format;
import typetips;
import std.typecons: Nullable;

import toml;

static class TomlConfigHelper {
    static T bind(T)(TOMLDocument doc, string table_name) {
        auto ret = T.init; // default value for config model

        if (table_name !in doc) {
            // table not found in doc
            return ret;
        }

        auto table = doc[table_name];

        // for each member of T, bind the value from the table
        foreach (member_name; __traits(allMembers, T)) {
            // if the member is not in the table, skip it
            if (member_name !in table) {
                continue;
            }

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
            }
            else {
                static assert(0, format("cannot bind model member %s of type %s", member_name, member_type
                        .stringof));
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
