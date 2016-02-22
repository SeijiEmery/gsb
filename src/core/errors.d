
module gsb.core.errors;
import std.format;

class ResourceError : Error {
    this (T...) (string fmt, T args) {
        super(format(fmt, args));
    }
}





