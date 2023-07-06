module soop.util;

import std.string;

/** 
 * convert a file size in bytes to a human readable string (e.g. 1.51 MiB)
 * Params:
 *   size = size in bytes
 * Returns: a human readable file size
 */
string human_file_size(ulong size, int precision) {
    string[] units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"];
    int unit = 0;
    double dsize = size;
    while (dsize >= 1024 && unit < cast(long) units.length - 1) {
        dsize /= 1024;
        unit++;
    }
    return format("%.*f %s", precision, dsize, units[unit]);
}
