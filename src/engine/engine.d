module gsb.engine.engine;
import gsb.engine.thread_mgr;
import gsb.engine.graphics;
import gsb.engine.events;
import gsb.utils.signals;

interface IEngine {}

class Engine {
    public Signal!(Engine) onShutdown;

    this () {
        threadMgr = new ThreadManager(this);
        eventMgr  = new EventManager(this);
        graphicsMgr = new GraphicsManager(this);
    }
    void launch () {
        graphicsComponent.preInitGL();
        try {
            threadMgr.init(thisTid);
            threadMgr.launchGraphicsThread (
                &graphicsComponent.runGraphicsThread
            );
            eventMgr.runMainThread();
            onShutdown.emit(this);
            threadMgr.shutdownThreads();

        } catch (Throwable e) {
            try {
                onShutdown.emit(this);
            } catch (Throwable e) {
                writefln("during onShutdown() signal: %s", e);
            }
            threadMgr.shutdownThreads();
            throw e;
        }
    }
private:
    ThreadManager   threadMgr;
    EventManager    eventMgr;
    GraphicsManager graphicsMgr;
}




