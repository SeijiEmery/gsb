module sb.threading.impl.thread_impl;
import sb.threading;
import std.exception: enforce;

IThreadContext sbCreateThreadContext (IThreadEventListener listener) {
    enforce!SbThreadUsageException(listener !is null, 
        "sbCreateThreadContext: invalid listener!");
    return new ThreadContext(listener);
}

private immutable Duration DEFAULT_FRAME_TIMEOUT_THRESHOLD = dur!"seconds"(1.0);
private immutable Duration DEFAULT_WORK_TIMEOUT_THRESHOLD  = dur!"seconds"(5.0);

private struct ThreadInfo {
    IThreadWorker worker;
    SbThreadStatus status = SbThreadStatus.NOT_RUNNING;
}
private class ThreadContext : IThreadContext {
    IThreadEventListener evh;  // special event handler / event listener
    ThreadInfo[SbThreadId.max] threadInfo;
    Duration frameTimeoutThreshold = DEFAULT_FRAME_TIMEOUT_THRESHOLD;
    Duration workItemTimeoutThreshold = DEFAULT_WORK_TIMEOUT_THRESHOLD;

    this (IThreadEventListener evh) {
        this.evh = evh;
    }
    void bindWorker (SbThreadId thread, IThreadWorker worker, bool reserveExternal = false) {

    }
    void enterThread (SbThreadId thread) {

    }
    SbThreadStatus getThreadStatus (SbThreadId thread) {
        return threadInfo[thread].currentStatus;
    }
    void restartThread (SbThreadId thread) {
        threadInfo[thread].shouldRestart = true;
    }
    void killThread (SbThreadId thread) {
        threadInfo[thread].shouldDie = true;
    }
    void killAllThreads () {
        foreach (ref thread; threadInfo) {
            thread.shouldDie = true;
        }
        foreach (ref thread; threadInfo) {
            thread.waitForDeath();
        }
    }
    bool runOnThread (SbThreadMask threads, void delegate() workItem) {

    }
    bool runOnThreadNextFrame (SbThreadMask threads, void delegate() workItem) {

    }
    bool runOnThreadThisFrame (SbThreadMask threads, void delegate() workItem) {

    }
    void setUnresponsiveFrameThreshold (double seconds) {
        frameTimeoutThreshold = dur!"seconds"(seconds);
    }
    void setUnresponsiveWorkThreshold (double seconds) {
        workItemTimeoutThreshold = dur!"seconds"(seconds);
    }
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
private class SbThread : Thread {
    SbThreadId     threadId;
    Throwable      err = null;
    SbThreadStatus status = SbThreadStatus.NOT_RUNNING;
    bool shouldDie = false;

    // Message passing
    void delegate()[] messages;
    Mutex             messageMutex;

    // Condition variable to wakeup thread
    Condition cvCondition;
    Mutex     cvMutex;

    // Public signals (note: will be run on thread)
    public Signal!(Throwable) onError;

    this (SbThreadId threadId) {
        super(&enterThread);
        this.engineThreadId = threadId;
        messageMutex = new Mutex();
        cvMutex      = new Mutex();
        cvCondition  = new Condition(cvMutex);
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
                if (SHOW_THREAD_PAUSE_RESUME_LOGGING)
                    log.write("paused %s", this);
                status = ThreadStatus.PAUSED;
                cvCondition.wait();
            }
            if (SHOW_THREAD_PAUSE_RESUME_LOGGING)
                log.write("resumed %s", this);
            status = ThreadStatus.RUNNING;
        }
    }
    // see wait().
    void waitUntil (bool delegate() pred) {
        synchronized (cvMutex) {
            while (!pred() && !shouldDie && !messages.length) {
                if (SHOW_THREAD_PAUSE_RESUME_LOGGING)
                    log.write("paused %s", this);
                status = ThreadStatus.PAUSED;
                cvCondition.wait();
            }
            if (SHOW_THREAD_PAUSE_RESUME_LOGGING)
                log.write("resumed %s", this);
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
        assert(gsb_localThread is null || gsb_localThread == this,
            format("Already running thread?! (%s, %s)",
                gsb_localThread, this));
        
        gsb__localThread = this;
        status = ThreadStatus.RUNNING;
        if (SHOW_THREAD_CREATE_TERM_LOGGING)
            log.write("Started thread %s", engineThreadId);
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
        return format("[%s (pid %s, status %s)]", engineThreadId, id, status);
    }
}












