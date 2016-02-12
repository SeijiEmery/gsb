
module gsb.core.log;
import std.stdio;
import std.format;

// Thread-local log (created in respective thread)
public Log log = null;

// Global references to all logs
public __gshared Log g_graphicsLog = null;
public __gshared Log g_mainLog = null;

class Log {
    string title;
    string[] lines;
    public bool writeToStdout = true;

    this (string title_) {
        title = title_;
    }

    void write (string msg) {
        lines ~= msg;
        if (writeToStdout) {
            writefln("[%s] %s", title, msg);
        }
    }
    void write (T...)(string msg, T args) {
        write(format(msg, args));
    }
}