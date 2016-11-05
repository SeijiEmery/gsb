module sb.threading.impl.thread_concurrency_impl;
import sb.threading;
import std.concurrency;


class ThreadContext : IThreadContext {
    IThreadEventListener eventHandler;
    Tid                  tid;
    shared(ThreadInstance)[SbThreadId.max] threads;

    void bindWorker (SbThreadId threadId, IThreadWorker worker, bool reserveExternal) {

    }
    void enterThread (SbThreadId threadId) {

    }
    private void notifyCrashed (ThreadInstance instance, Throwable e) {
        eventHandler.onThreadError(this, instance.threadId, e);
    }
    private void notifyKilled (ThreadInstance instance) {
        eventHandler.onThreadKilled(this, instance.threadId);
    }
}

private void runThread (shared(ThreadInstance) instance) {
    try {
        instance.run();
    } catch (Throwable e) {
        writefln("Unhandled thread exception on %s!\n %s", instance.threadId, e);
    }
}
class ThreadInstance {
    SbThreadId    threadId;
    ThreadContext tc;
    ThreadWorker  worker;
    SbThreadStatus status = SbThreadStatus.NOT_RUNNING;
    Tid tid;

    void launch () {
        status = SbThreadStatus.INITIALIZING;
        shared ThreadInstance instance = this;
        tid = spawn(&runThread, instance);
    }
    private void run () {
        try {
            tc.onThreadStarted(tc, threadId);
            worker.onThreadStart(threadId);

            status = SbThreadStatus.RUNNING;
            tc.onThreadRunning(tc, threadId);

            bool running = true;
            while (running) {
                recieve(

                );
            }

            status = SbThreadStatus.EXIT_OK;
            worker.onThreadEnd(threadId);
            tc.onThreadKilled(tc, threadId);
        } catch (Throwable e) {
            try {
                worker.onThreadEnd(threadId);
            } catch (Throwable e2) {

            }
            tc.onThreadError(tc, threadId, e);
        }
    }
}





