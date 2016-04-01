
module gsb.core.errors;
import std.format;

class ResourceException : Exception {
    this (string file = __FILE__, ulong line = __LINE__, T...) (string fmt, T args) {
        super(format(fmt, args), file, line);
    }
}





