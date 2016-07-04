module sb.threading.thread_context;
import sb.threading.thread_worker;
import sb.threading.thread_enums;

/// Creates a new thread context (binds notification events to the passed in listener,
/// which may not be null).
IThreadContext sbCreateThreadContext (IThreadEventListener);


interface IThreadContext {
    /// Lazily binds a thread worker to the target thread.
    /// If target thread was not running, a new thread will be created to run the thread
    /// worker; if it was running or exited, shuts down + replaces the previous worker
    /// with the new one.
    ///
    ///     @reserveExternal: skip creating a new thread, b/c we're going to run the 
    /// worker on our own thread instead. Always enabled for MAIN_THREAD; see enterThread().
    ///
    void bindWorker (SbThreadId, IThreadWorker, bool reserveExternal = false);

    /// Call to run a thread worker on _this_ thread.
    /// Does not return until the "thread" exits; can be used to bind external threads,
    /// and MUST be used to run the MAIN_THREAD (sb will want to hijack that thread,
    /// and you should implement your app loop, startup, and shutdown code as an IThreadWorker).
    void enterThread (SbThreadId);

    /// Get current status of given thread
    SbThreadStatus getThreadStatus (SbThreadId);

    /// Call to restart a thread that had exited. No other effects otherwise; reuses the same
    /// thread worker unless you call bindWoker() with a new one (in which case this call
    /// will be redundant).
    void restartThread (SbThreadId);

    /// Kills the target thread. No effect if thread was not running.
    void killThread (SbThreadId);

    /// Kills all threads. No effect on non-running threads.
    void killAllThreads ();

    /// Run a single work item on an elgible thread (outside of IThreadWorker; can be used
    /// for inter-thread communication or if the next phase of task XYZ requires running on a
    /// _specific_ thread or threads -- eg. MAIN_THREAD / GRAPHICS_THREAD, async file loading on
    /// ANY_WORK_THREAD, etc). 
    /// Returns false if no elgible thread (threads not running, exited, etc).
    bool runOnThread (SbThreadMask, void delegate());

    /// Run a single work item at the start of next frame. Should be called each frame to recur.
    bool runOnThreadNextFrame (SbThreadMask, void delegate());

    /// Run a work item during this frame. Adds a next-frame block until this gets run.
    void runOnThreadThisFrame (SbThreadMask, void delegate());

    ///
    /// Sb frame handling (somewhat hack-ish, but might as well implement it here)
    ///

    /// Set whether thread X may block the next-frame event.
    void setFrameWaitPolicy (SbThreadMask, bool shouldWait);

    /// Signal next-frame for this thread. onNextFrame will be dispatched to all workers
    /// when all blocking work has been completed for this frame. Must call this each frame 
    /// on all workers, or program will hang.
    void signalFrameDone    (SbThreadId);

    /// Set time in seconds before a thread blocking next-frame is considered unresponsive.
    /// A thread taking more than this amount of time will trigger a warning on the IThreadEventListener.
    void setUnresponsiveFrameThreshold (double);

    /// Set time in seconds before a work unit that fails to return is considered unresponsive.
    /// Once again, triggers a warning on the event listener (which may kill / restart the thread)
    void setUnresponsiveWorkThreshold (double);
}

/// Listener events for each thread in the thread context.
/// Recieves all thread state changes + can control thread worker changes as a result.
/// All methods are called on their respective thread.
///
interface IThreadEventListener {
    /// Called when thread started, before onThreadStart() called
    void onThreadStarted (IThreadContext, SbThreadId);

    /// Called after onThreadStart() (if ran successfully)
    void onThreadRunning (IThreadContext, SbThreadId);

    /// Called when/if the thread is killed by killThread() / killAllThreads()
    /// Can use this to detect main thread exit + 
    void onThreadKilled  (IThreadContext, SbThreadId);

    /// Called if the thread was terminated by an unhandled error (any ThreadWorker call).
    /// Should use this to shutdown threads if something critical broke.
    void onThreadError   (IThreadContext, SbThreadId, Throwable);

    /// Called if bindWorker() rebinds a different worker to a currently running thread.
    void onThreadWorkerReplaced (IThreadContext, SbThreadId, IThreadWorker existing, IThreadWorker replacement);

    /// Called if thread creation failed for some reason (internal error). Can throw 
    /// (killing this thread and triggering onThreadError), or report + suppress, or whatever.
    void onFailedToCreateThread (IThreadContext, SbThreadId, SbThreadingException);

    //
    // Thread timeout warnings (may kill / restart threads or log warnings, etc. as needed)
    //

    /// Called if worker timed out / failed to call signalFrameDone() (see setUnresponsiveFrameThreshold). 
    /// May call signalFrameDone() to resume execution (at the cost of potential bugs), 
    /// and/or log errors or kill the program.
    void onUnresponsiveFrame (IThreadContext, SbThreadId);

    /// Called if worker doThreadWork() timed out (see setUnresponsiveWorkThreshold)
    void onUnresponsiveWorkUnit (IThreadContext, SbThreadId);
}

/// Thrown on internal threading errors
class SbThreadingException : Exception {
    this (string msg, string file = __FILE__, size_t line = cast(size_t)__LINE__, Throwable next = null) {
        super(msg, file, line, next);
    }
}
/// Thrown when/if you misuse the api.
class SbThreadUsageException : Exception {
    this (string msg, string file = __FILE__, size_t line = cast(size_t)__LINE__, Throwable next = null) {
        super(msg, file, line, next);
    }
}


