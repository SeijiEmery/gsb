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


private class ThreadContext : IThreadContext {
    IThreadEventListener evh;  // special event handler / event listener
    Duration frameTimeoutThreshold = DEFAULT_FRAME_TIMEOUT_THRESHOLD;
    Duration workItemTimeoutThreshold = DEFAULT_WORK_TIMEOUT_THRESHOLD;
    ThreadRunner[SbThreadId.max] threads;

    this (IThreadEventListener evh) {
        this.evh = evh;
    }
    void bindWorker (SbThreadId threadId, IThreadWorker worker, bool reserveExternal = false) {
        enforce!SbThreadUsageException(worker,
            format("Illegal: null IThreadWorker passed to %s!", thread));

        // create threadRunner if it doesn't exist
        if (!threads[threadId])
            threads[threadId] = new ThreadRunner(threadId);

        // Set worker + maybe launch thread
        threads[threadId].setWorker(worker);
        if (!reserveExternal)
            threads[threadId].launchThread();  // does nothing if thread already assigned + running
    }
    void enterThread (SbThreadId threadId) {
        enforce!SbThreadUsageException(threads[threadId] && threads[threadId].hasWorker,
            format("Cannot enterThread: no worker bound for %s!", thread));

        threads[threadId].run();
    }
    SbThreadStatus getThreadStatus (SbThreadId thread) {
        return threads[threadId] ?
            threads[threadId].currentStatus :
            SbThreadStatus.NOT_RUNNING;
    }
    void restartThread (SbThreadId threadId) {
        enforce!SbThreadUsageException(threads[threadId],
            format("No worker bound to %s! (cannot restart thread)", threadId));

        threads[threadId].signalShouldRestart();
    }
    void killThread (SbThreadId thread) {
        enforce!SbThreadUsageException(threads[threadId],
            format("No worker bound to %s! (cannot restart thread)", threadId));

        threads[threadId].signalShoulDie();
    }
    void killAllThreads () {
        foreach (ref thread; threads) {
            if (thread)
                thread.signalShouldDie();
        }
        foreach (ref thread; threads) {
            if (thread)
                thread.waitForDeath();
        }
    }
    bool runOnThread (SbThreadMask threads, void delegate() workItem) {
        assert(0, "Unimplemented: runOnThread");
    }
    bool runOnThreadNextFrame (SbThreadMask threads, void delegate() workItem) {
        assert(0, "Unimplemented: runOnThreadNextFrame");
    }
    bool runOnThreadThisFrame (SbThreadMask threads, void delegate() workItem) {
        assert(0, "Unimplemented: runOnThreadThisFrame");
    }
    void setUnresponsiveFrameThreshold (double seconds) {
        frameTimeoutThreshold = dur!"seconds"(seconds);
    }
    void setUnresponsiveWorkThreshold (double seconds) {
        workItemTimeoutThreshold = dur!"seconds"(seconds);
    }

    class ThreadRunner {
        SbThreadId    threadId;
        IThreadWorker worker;
        Mutex syncMutex;
        bool shouldDie = false;
        bool shouldRestart = false;

        this (SbThreadId threadId) {
            this.threadId = threadId;
            this.syncMutex = new Mutex();
        }
        void setWorker (IThreadWorker worker) {
            bool shouldRestart = false;
            synchronized (syncMutex) {
                shouldRestart = worker !is null;
                this.worker = worker;
            }
            if (shouldRestart)
                restartThread();
        }
        void launchThread () {
            synchronized (syncMutex) {
                if (!thread && !usingExternalThread) {
                    internalThreadStatus = SbThreadStatus.INITIALIZING;
                    thread = new SbThread(&runThread);
                    thread.start();
                }
            }
        }
        void restartThread () {
            bool doLaunch = false;
            synchronized (syncMutex) {
                enforce!SbThreadUsageException(!usingExternalThread,
                    format("Cannot restart external thread! (%s)", threadId));

                if (thread) {
                    thread.kill();
                    doLaunch = true;
                }
            }
            if (doLaunch)
                launchThread();
        }
        @property auto threadStatus () {
            return thread ? SbThreadStatus.NOT_RUNNING :
                internalThreadStatus;
        }
        private void runThread (SbMessageQueue queue) {
            assert( worker !is null, format("Null worker! %s", threadId) );

            void handleError (Throwable e) {
                try {
                    synchronized (syncMutex) { internalThreadStatus = SbThreadStatus.EXIT_ERROR; }
                    evh.onThreadError(threadId, e);
                } catch (Throwable e2) {
                    assert("INVALID: IThreadEventListener.onThreadError may not throw! (thread %s): ",
                        threadId, e2);
                }
            }

            try {
                worker.onThreadStart();
            } catch (Throwable e) {
                handleError(e); return; return;
            }
            synchronized (syncMutex) { internalThreadStatus = SbThreadStatus.RUNNING; }

            bool keepRunning = true;
            bool frameDone   = false;
            try {
                while (keepRunning) {
                    if (queue.hasHighPriorityMessage) {
                        queue.nextMessage.visit(
                            (ThreadMsg_Kill _) { keepRunning = false; },
                            (ThreadMsg_HighPriority msg) {
                                msg.run();
                            },
                            (ThreadMsg_NextFrame _) {
                                assert(frameDone, format("thread %s frame not done!", frameId));
                                frameDone = false;
                                worker.onThreadNextFrame();
                            }
                        );
                    } else if (frameDone && queue.hasAsyncMessage) {
                        queue.nextAsyncMessage.run();
                    } else if (frameDone) {
                        if (!worker.doThreadWork())
                            queue.waitNextMessage();
                    } else {
                        frameDone |= checkThreadFrameDone(threadId);
                        if (!worker.doThreadWork() && queue.hasAsyncMessage)
                            queue.nextAsyncMessage.run();
                    }
                }
            }
        } catch (Throwable e) {
            handleError(e); return;
        }

        synchronized (syncMutex) { threadStatus = SbThreadStatus.EXIT_OK; }
        try {
            worker.onThreadEnd();
        } catch (Throwable e) {

        }
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












