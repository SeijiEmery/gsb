module gsb.engine.thread_mgr;
import gsb.engine.graphics;
import gsb.engine.events;

import std.concurrency;

class ThreadMgr {
private:
    Tid mainThread     = 0;
    Tid graphicsThread = 0;

public:
    void shutdownThreads () {

    }
}
