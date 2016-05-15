module gsb.core.log;
import std.stdio;
import std.format;


// debug logging toggles
immutable bool TEXTRENDERER_DEBUG_LOGGING_ENABLED = false;


// Thread-local log (created in respective thread)
private Log localLog = null;
//public @property Log log () {
//    if (!localLog)
//        log = createWorkerLog();
//    return log;
//}
public @property Log log (Log log_ = null) {
    if (!localLog) {
        if (!g_mainLog) {
            g_mainLog = localLog = new Log("main-thread");
        } else {
            localLog = log_ ?
                log_ :
                createEnumeratedWorkerLog();
        }
    }
    return localLog;
}
//public Log log = null;

// Global references to all logs
public __gshared Log g_graphicsLog = null;
public __gshared Log g_mainLog = null;
public __gshared Log[string] g_workerLogs = null;
private __gshared int nextWorker = 0;

auto createEnumeratedWorkerLog () {
    if (localLog is null) {
        synchronized {
            auto name = format("work-thread %d", nextWorker++);
            localLog = g_workerLogs[name] = new Log(name);
        }
    }
    return localLog;
}

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