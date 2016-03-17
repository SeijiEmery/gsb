
module gsb.core.threadstate;
import std.concurrency;

private __gshared Tid   gsb_mainThread;
private __gshared Tid   gsb_graphicsThread;
private __gshared Tid[] gsb_workerThreads;
private __gshared bool  gsb_threadStateDirty = true;

private Tid           gsb_currentThread;
private GsbThreadType ourThreadType = GsbThreadType.UNKNOWN;

enum GsbThreadType {
    UNKNOWN = 0,
    MAIN_THREAD = 1,
    GRAPHICS_THREAD,
    WORKER_THREAD
};

void gsb_setMainThread () {
    //assert(!gsb_mainThread);
}













