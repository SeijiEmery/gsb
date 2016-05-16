module gsb.engine.engine;
import gsb.engine.thread_mgr;
import gsb.engine.graphics_thread;
import gsb.engine.event_thread;
import gsb.utils.signals;
import std.concurrency;
import std.stdio;

interface IEngine {}

class Engine : IEngine {
    public Signal!(Engine) onShutdown;

    this () {
        threadMgr.engine = this;
        eventMgr.engine  = this;
        graphicsMgr.engine = this;
    }
    void launch () {
        graphicsMgr.preInitGL();
        try {
            // non-blocking call: launches parallel graphics thread, finishes init + waits for instructions
            threadMgr.launchGraphicsThread ( &graphicsMgr.runGraphicsThread );

            // **blocking** call: "launches" + runs event system on _this_ thread, which drives the rest of
            // the application. Returns only when application exits (normally); throws an exception / throwable
            // on error (which must be handled so we can shutdown remaining threads).
            threadMgr.launchEventThread ( &eventMgr.runMainThread );

            // Teardown code: emit signal + shutdown threads
            onShutdown.emit(this);
            threadMgr.shutdownThreads();

        } catch (Throwable e) {
            try {
                onShutdown.emit(this);
            } catch (Throwable e) {
                writefln("during onShutdown(): %s\n", e);
            }
            threadMgr.shutdownThreads();
            throw e;
        }
    }
private:
    // Engine components
    ThreadManager         threadMgr;
    EventThreadManager    eventMgr;
    GraphicsThreadManager graphicsMgr;
}




