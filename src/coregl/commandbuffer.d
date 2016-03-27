
module gsb.coregl.commandbuffer;
import gsb.core.singleton;
import core.sync.mutex;
import std.algorithm.mutation: swap;

//import gsb.core.gsbstate;

alias GLCommand = void delegate();
private bool gsb_isOnGraphicsThread () { return true; }

class GLCommandBuffer {
    mixin LowLockSingleton;

    private GLCommand[] pending;
    private GLCommand[] nextFrame;
    private GLCommand[] executing;
    private Mutex mutex;

    void pushImmediate (GLCommand command) {
        synchronized (mutex) {
            pending ~= command;
        }
    }
    void pushImmediate (GLCommand[] commands) {
        synchronized (mutex) {
            pending ~= commands;
        }
    }
    void pushNextFrame (GLCommand command) {
        synchronized (mutex) {
            nextFrame ~= command;
        }
    }
    void pushNextFrame (GLCommand[] commands) {
        synchronized (mutex) {
            nextFrame ~= commands;
        }
    }
    void runCommands () {
        assert(gsb_isOnGraphicsThread());
        assert(executing.length == 0);
        synchronized (mutex) {
            swap(executing, pending);
        }
        foreach (cmd; executing)
            cmd();
        executing.length = 0;
    }
    void onNextFrame () {
        assert(gsb_isOnGraphicsThread());
        synchronized (mutex) {
            pending ~= nextFrame;
            nextFrame.length = 0;
        }
    }
}

