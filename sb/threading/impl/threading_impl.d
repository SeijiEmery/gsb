module sb.threading.impl.thread_impl;
import sb.threading;
import std.exception: enforce;
import std.datetime: Duration, dur;
import core.sync.mutex;
import core.sync.condition;
import core.thread;


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
private struct Message { SbThreadMask target; SbThreadId assigned = SbThreadId.NONE; void delegate() msg; }

private class MessageBox {
    Message[][2] frameMessages;
    Message[][2] asyncMessages;
    uint[2]      pendingFrameMessage;
    uint[2]      pendingAsyncMessage;

    uint curFrameId = 0;
    ReadWriteMutex frameMutex;

    this () { frameMutex = new ReadWriteMutex(); }
    void pushThisFrame (SbThreadMask target, void delegate msg) {
        synchronized (frameMutex.read) {
            frameMessages[curFrameId & 1] ~= Message(target, SbThreadId.NONE, msg);
            pendingFrameMessage[curFrameId & 1] |= target;
        }
    }
    void pushNextFrame (SbThreadMask target, void delegate msg) {
        synchronized (frameMutex.read) {
            frameMessages[(curFrameId+1) & 1] ~= Message(target, SbThreadId.NONE, msg);
            pendingFrameMessage[(curFrameId+1) & 1] |= target;
        }
    }
    void pushAsync (SbThreadMask target, void delegate msg) {
        synchronized (frameMutex.read) {
            asyncMessages[curFrameId & 1] ~= Message(target, SbThreadId.NONE, msg);
            pendingAsyncMessage[curFrameId & 1] |= target;
        }
    }

    Message* fetchFrameMessage (SbThreadId threadId) {
        synchronized (frameMutex.read) {
            auto mask = threadId.toMask;
            auto fid  = curFrameId & 1;
            if (!pendingFrameMessages[fid] & mask)
                return null;

            foreach (ref message; frameMessages[fid]) {
                if (message.assigned != SbThreadId.NONE && 
                    message.target & mask &&
                    cas(&message.assigned, SbThreadId.NONE, threadId))
                {
                    return &message;
                }
            }
            do {
                auto current = pendingFrameMessages[fid];
                auto next    = current & ~threadId.toMask;
            } while (!cas(&pendingFrameMessages[fid], current, next));


            while (!cas(pendingFrameMessages[fid] & ~threadId.toMask,
                pendingFrameMessages[fid], ))


            pendingFrameMessages[curFrameId & 1] &= ~threadId.toMask;
            return null;
        }
    }













}






private class ThreadRunner {
    ThreadContext  tc;
    IThreadWorker  worker;
    SbThreadId     threadId;
    SbThreadStatus status = SbThreadStatus.NOT_RUNNING;
    bool shouldDie     = false;
    bool shouldRestart = false;
    IThreadWorker workerReplacement = null; // use iff shouldRestart
final:
    private void startupThread () {
        status = SbThreadStatus.INITIALIZING;
        tc.notifyStarted(threadId);
        worker.onThreadStart(threadId);

        status = SbThreadStatus.RUNNING;
        tc.notifyRunning(threadId);
    }
    private void teardownThread_ok () {
        status = SbThreadStatus.EXIT_OK;
        try {
            worker.onThreadEnd();
        } catch (Throwable e) {
            status = SbThreadStatus.EXIT_ERROR;
            tc.notifyError(threadId);
            return;
        }
        tc.notifyExited(threadId);
    }
    private void teardownThread_andReportError (Throwable err) {
        status = SbThreadStatus.EXIT_ERROR;
        worker.onThreadEnd();
        tc.notifyError(threadId);
    }
    private void restartThread (ThreadWorker newWorker) {
        teardownThread_ok();
        worker = newWorker;
        startupThread();
    }
    private void runLoop () {
        while (!shouldDie) {
            if (shouldRestart && workerReplacement) {
                if (workerReplacement != worker)
                    restartThread(workerReplacement);
                shouldRestart = false;
                workerReplacement = null;

            } else if (nextFrameId != frameId) {
                worker.onNextFrame();
                frameId = nextFrameId;



            } else if (hasExternWork) {
                doExternWork();
            } else {
                worker.doThreadWork();
            }
        }
    }
    private void swapFrame () {
        worker.onNextFrame();
    }






    void run () {
        enforce!SbThreadingException(status == SbThreadStatus.NOT_RUNNING,
            format("Invalid state: %s", status));
        try {
            startupThread();
            runLoop();
            teardownThread_ok();
        } catch (Throwable e) {
            teardownThread_andReportError(e);
        }
        shouldDie = shouldRestart = false;
        workerReplacement = null;
    }
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












