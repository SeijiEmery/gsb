module gsb.engine.threads;
import core.thread;
import core.sync.mutex;
import core.sync.condition;
import gsb.utils.signals;
import std.format;

import gsb.core.log;

// Engine thread enum; only applies to gsb EngineThread(s) with
// special semantics; other threads are not so addressed.
enum EngineThreadId {
    Unknown    = -1,
    MainThread = 0,
    GraphicsThread,
    WorkThread1,
    WorkThread2,
    WorkThread3,
    WorkThread4,
    WorkThread5,
    WorkThread6,
    WorkThread7,
    WorkThread8,
    WorkThread9,
    WorkThread10,
    WorkThread11,
    WorkThread12,
    WorkThread13,
    WorkThread14,
    WorkThread15,
    WorkThread16
}
enum ThreadStatus {
    INACTIVE = 0, RUNNING, PAUSED, EXITED, ERROR
}
__gshared EngineThread[EngineThreadId.max] gsb_engineThreads;
private EngineThread  gsb__localThread = null;

auto @property gsb_localThread () { return gsb__localThread; }
auto @property gsb_localThreadId () {
    return gsb_localThread ? gsb_localThread.engineThreadId : EngineThreadId.Unknown;
}

// special properties for accessing common threads
auto @property gsb_mainThread ()     { return gsb_engineThreads[EngineThreadId.MainThread]; }
auto @property gsb_graphicsThread () { return gsb_engineThreads[EngineThreadId.GraphicsThread]; }

// Get work thread / threadId given index in [0, 16)
auto gsb_getWorkThreadId (uint n) {
    assert(n < 16, format("work threads limited to [0, 16): %s out of bounds", n));
    return cast(EngineThreadId)(n + EngineThreadId.WorkThread1);
}
auto gsb_getWorkThread (uint n) {
    return gsb_engineThreads[gsb_getWorkThreadId(n)];
}

// one-use functions for setting + dealing with the main thread (which isn't a "real" thread, exactly,
// as instead of launching a new thread we just want to run stuff in the currently executing one, but
// with access to all of our special threading infrastructure (ie. wait() / send() / kill() etc)).
auto gsb_setMainThread (EngineThread fauxThread) {
    assert(!gsb_mainThread, format("Already set main thread: %s; attempting to override with %s", 
        gsb_mainThread, fauxThread));
    assert(fauxThread.engineThreadId == EngineThreadId.MainThread,
        format("gsb_setMainThread() must be called with thread of type %s, not %s (%s)",
            EngineThreadId.MainThread, fauxThread.engineThreadId, fauxThread));

    return gsb__localThread = gsb_engineThreads[EngineThreadId.MainThread] = fauxThread;
}
void gsb_runMainThread () {
    assert(gsb_mainThread, format("Did not set main thread!"));
    assert(gsb_mainThread.threadStatus == ThreadStatus.INACTIVE,
        format("mainThread already running / did run! (%s)", gsb_mainThread));

    gsb_mainThread.enterThread();
}

// Utility to assign graphics thread (much more straightforward)
auto gsb_setGraphicsThread (EngineThread graphicsThread) {
    assert(!gsb_graphicsThread, format("Already set graphics thread: %s; attempting to override with %s",
        gsb_graphicsThread, graphicsThread));
    assert(graphicsThread.engineThreadId == EngineThreadId.GraphicsThread,
        format("gsb_setGraphicsThread() must be called with thread of type %s, not %s (%s)",
            EngineThreadId.GraphicsThread, graphicsThread.engineThreadId, graphicsThread));

    return gsb_engineThreads[EngineThreadId.GraphicsThread] = graphicsThread;
}

// Utility function for auto-starting a work thread. Returns true if started thread,
// or false if thread already running (if thread has stopped / exited, restarts it)
bool gsb_startWorkThread(T, Args...)(uint n, Args args)
    // should also check for isSubclass(T, EngineThread), but idk how to do that with traits :/
    if (__traits(compiles, new T(EngineThreadId.WorkThread1, args)))
{
    auto threadId = gsb_getWorkThreadId(n);
    if (!gsb_engineThreads[threadId] || gsb_engineThreads[threadId].threadStatus >= ThreadStatus.EXITED) {
        gsb_engineThreads[threadId] = new T(threadId, args);
        gsb_engineThreads[threadId].start();
        return true;
    }
    return false;
}


// gsb extension to phobos threads. Adds the following features:
// – thread registry (gsb_engineThreads, gsb_localThread)
// - standardized enumerated thread ids for engine threads (EngineThreadId)
// - standardized kill() method + threadStatus()
// - builtin error handling (catches Throwable) and propogation
//   with onError() signal.
// - simple messaging system that can inject arbitrary code (delegates)
//   into the thread run loop with send(). As such, the user must implement
//   three abstract methods: init(), runNextTask(), and atExit(), instead
//   of the standard run() / equivalent.
class EngineThread : Thread {
    EngineThreadId engineThreadId;
    Throwable      err = null;
    ThreadStatus   status = ThreadStatus.INACTIVE;
    bool shouldDie = false;

    // Message passing
    void delegate()[] messages;
    Mutex             messageMutex;

    // Condition variable to wakeup thread
    Condition cvCondition;
    Mutex     cvMutex;

    // Public signals (note: will be run on thread)
    public Signal!(Throwable) onError;

    this (EngineThreadId threadId) {
        super(&enterThread);
        this.engineThreadId = threadId;
        messageMutex = new Mutex();
        cvMutex      = new Mutex();
        cvCondition  = new Condition(cvMutex);

        log.write("Created thread %s", threadId);
        //assert(!g_engineThreads[threadId], format("already registered %s", threadId));
        //g_engineThreads[threadId] = this;
    }
    auto threadStatus () { return status; }
    auto @property running () { return status == ThreadStatus.RUNNING || status == ThreadStatus.PAUSED; }
    auto @property paused  () { return status == ThreadStatus.PAUSED; }
    auto @property started () { return status != ThreadStatus.INACTIVE; }
    auto @property terminated () { return status == ThreadStatus.EXITED || status == ThreadStatus.ERROR; }

    void kill () { 
        shouldDie = true;
        notify();
    }

    // Force thread to wait using internal cv -- use this instead of external
    // methods, since a waiting engine thread may still be woken up by 
    // notify(), send() or kill().
    void wait () {
        synchronized (cvMutex) {
            if (!shouldDie && !messages.length) {
                status = ThreadStatus.PAUSED;
                cvCondition.wait();
            }
            status = ThreadStatus.RUNNING;
        }
    }
    // see wait().
    void waitUntil (bool delegate() pred) {
        synchronized (cvMutex) {
            while (!pred() && !shouldDie && !messages.length) {
                status = ThreadStatus.PAUSED;
                cvCondition.wait();
            }
            status = ThreadStatus.RUNNING;
        }
    }
    // Wake up this thread if paused by wait() / waitUntil().
    // Called by send() and kill(); does not affect yield() or sleep().
    void notify () {
        synchronized (cvMutex) {
            cvCondition.notify();
        }
    }

    abstract void init        ();
    abstract void runNextTask ();
    abstract void atExit      ();

    void send (void delegate() message) {
        synchronized (messageMutex) {
            messages ~= message;
        }
        if (status == ThreadStatus.PAUSED)
            notify();
    }

    final void enterThread () {
        log.write("Started thread %s", engineThreadId);
        assert(gsb_localThread is null || gsb_localThread == this,
            format("Already running thread?! (%s, %s)",
                gsb_localThread, this));
        
        gsb__localThread = this;
        status = ThreadStatus.RUNNING;
        try {
            init();
            while (!shouldDie) {
                if (messages.length)
                    runMessages();
                runNextTask();
            }
            atExit();
            status = ThreadStatus.EXITED;
        } catch (Throwable e) {
            status = ThreadStatus.ERROR;
            err = e;
            onError.emit(e);
        }
    }
    private void runMessages () {
        synchronized (messageMutex) {
            foreach (message; messages) {
                message();
            }
            messages.length = 0;
        }
    }

    override string toString () {
        return format("[gsb.%s (pid %s, status %s)]", engineThreadId, id, status);
    }
}

