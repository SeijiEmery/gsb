
module gsb.utils.logging.logger;
import gsb.utils.logging.tags;
import gsb.utils.ringbuffer;

import std.algorithm.mutation;
import std.algorithm.comparison;
import std.concurrency;
//import core.thread;


void log (
    uint line = __LINE__, 
    string file = __FILE__, 
    string funcName = __FUNCTION__,
    string prettyFuncName = __PRETTY_FUNCTION__,
    string moduleName = __MODULE__,
    Args...
) (
    string[] tags, 
    LogPriority priority,
    string msg,
    Args args
) {
    logger_withTags(tags, {
        localLogger.emitMsg(line, file, funcName, prettyFuncName, moduleName, priority, format(msg, args));
    });
}

void logger_withTags (
    string[] tags,
    void delegate() expr
) {
    tagTracker.push(tags);
    expr();
    tagTracker.pop(tags);
}

enum LogPriority {
    log, trace, info, warning, critical, fatal
};

private class GlobalLoggingContext {
    LogEntry[] perFrameEntries_nextFrame;
    LogEntry[] perFrameEntries_lastFrame;
    LogEntry[] allEntries;

    protected void append (bool isPerFrame, LogEntry entry) {
        synchronized {
            if (isPerFrame) {
                perFrameEntries_nextFrame ~= entry;
            } else {
                allEntries ~= entry;
            }
        }
    }

    void onNextFrame () {
        synchronized {
            swap(perFrameEntries_nextFrame, perFrameEntries_lastFrame);
            perFrameEntries_nextFrame.length = 0;
        }
    }

    void readPerFrameEntries (int n, void delegate(ref LogEntry) visitor) {
        LogEntry[] entries = void;
        size_t     end;
        synchronized {
            entries = perFrameEntries_lastFrame;
            end     = entries.length;
        }

        size_t first = n < 0 ? 0 : cast(size_t)max(0, cast(int)end - n);
        foreach (i; end .. first) {
            visitor(entries[i]);
        }
    } 

    void readEntries (int n, void delegate(ref LogEntry) visitor) {

    }
}

struct LogEntry {
    uint seq;
    uint contextId; // see LogContext / LogContextCache
    string msg;
    ushort[] tags;
    LogPriority priority;
}

struct MessageContext {
    Tid threadId;
    uint line;
    string file;
    string funcName;
    string prettyFuncName;
    string moduleName;

    string toString () {
        // fixme: this is crappy. please fix it.
        return format("'%s':%d, %s, (%s) %s", file, line, funcName, prettyFuncName, moduleName);
    }
}

// Since many log entries will probably share the same log context (file name / line number, etc),
// it makes sense to cache it, and reuse entries (accessed by int id).
private struct MessageContextCache {
    private MessageContext[] entries;
    private uint[string] lookup;
    private uint next = 0;

    uint insert (Args...)(Args args) if (__traits(compiles, MessageContext(args))) {
        return insert(MessageContext(args));
    }
    uint insert (MessageContext entry) {
        auto key = entry.toString();
        if (key in lookup)
            return lookup[key];
        return lookup[key] = next++;
    }
    ref MessageContext get (uint index) {
        assert(index < entries.length);
        return entries[index];
    }
}

private class LocalLogger {
    private GlobalLoggingContext globalLogger;
    private MessageContextCache contextCache;
    //private RingBuffer!(LogEntry, LOCAL_LOG_RINGBUFFER_SIZE) localEntries;
    private uint readHead = 0;

    protected this (GlobalLoggingContext globalLogger) {
        this.globalLogger = globalLogger;
    }

    void emitMsg (uint line, string file, string funcName, string prettyFuncName, string moduleName, LogPriority priority, string msg) {

        //auto seq = globalLogger.getSequence();
        auto tags = tagTracker.getTagIds();
        auto contextId = contextCache.insert(thisTid, line, file, funcName, prettyFuncName, moduleName);
        auto isPerFrame = false;
        globalLogger.append(isPerFrame, LogEntry(0, contextId, msg, tags, priority));
    }
}
































