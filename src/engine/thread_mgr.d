module gsb.engine.thread_mgr;
import gsb.engine.graphics_thread;
import gsb.engine.event_thread;
import gsb.engine.engine;
import gsb.core.log;

import std.concurrency;

private void launchThread (Args...)(void delegate(Args) f, Args args) if (__traits(compiles, f(args))) {
    f(args);
}

class ThreadManager {
private:
    GThreadContext   graphicsThread;
    EThreadContext   eventThread;
    WThreadContext[] threadList;

public:
    public IEngine engine;

    void shutdownThreads () {
        foreach (thread; threadList)
            thread.kill();
    }
    void launchGraphicsThread (void delegate(GThreadContext) fcn) {
        assert(!graphicsThread);
        graphicsThread = new GThreadContext();
        graphicsThread.tid = spawn(launchThread, fcn, graphicsThread);
        threadList ~= graphicsThread;
    }
    void launchEventThread (void delegate(EThreadContext) fcn) {
        assert(!eventThread);
        threadList ~= (eventThread = new EThreadContext());
        eventThread.tid = thisTid;

        fcn(eventThread);
    }

    //
    // Hooks passed to graphics_thread + event_thread
    //
    class WThreadContext {
        Tid  tid;
        bool isRunning = false;
        bool shouldDie = false;
        @property auto mainTid () { return eventThread.tid; }

        void kill () { shouldDie = true; }
        @property auto running () { return isRunning && !shouldDie; }
        @property auto running (bool v) { isRunning = v; }
        
        void notifyThreadTerminated () { 
            isRunning = false; 
        }
        void notifyTerminatedWithError (Throwable e) {
            isRunning = false;
            if (thisTid != eventThread.tid) {
                log.write("worker thread terminated with error: %s", e);
                send(eventThread.tid, ClientMessage.KillRequest());
            } else {
                throw e;
            }
        }
    }
    class GThreadContext : WThreadContext {

    }
    class EThreadContext : WThreadContext {

    }
}

static struct ClientMessage {
    static struct KillRequest {}
    static struct NextFrame {

    }
}
static struct GraphicsMessage {
    static struct ReadyForNextFrame {

    }
}






