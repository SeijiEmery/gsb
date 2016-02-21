
module gsb.core.events;
import gsb.core.window;
import gsb.core.log;

import gl3n.linalg;
import core.thread;
//import std.signals;

struct Signal(T...) {
    private Slot!T[] connectedSlots;

    auto connect (void delegate(T) cb, bool autoDc = false) {
        auto slot = new Slot!T(cb, autoDc);
        connectedSlots ~= slot;
        //log.write("Signal %s connecting slot: %s", cast(void*)&this, cast(void*)&(slot.cb));
        return slot;
    }
    void emit (T args) {
        for (auto i = connectedSlots.length; i --> 0; ) {
            if (!connectedSlots[i].active) {
                //log.write("Signal %s disconnecting slot: %s", cast(void*)&this, cast(void*)&(connectedSlots[i].cb));
                connectedSlots[i] = connectedSlots[$-1];
                connectedSlots.length--;
            } else {
                //log.write("Signal %s emitting signal to %s", cast(void*)&this, cast(void*)&(connectedSlots[i].cb));
                connectedSlots[i].cb(args);
            }
        }
    }

    class Slot(T...) {
        void delegate (T) cb;
        bool active = true;
        bool autoDc = false;

        this (typeof(cb) cb, bool autoDc) {
            this.cb = cb;
            this.autoDc = autoDc;
        }
        ~this () {
            if (autoDc)
                disconnect();
        }
        void disconnect () {
            //log.write("Disconnecting %s", cast(void*)this);
            active = false;
        }
    }

    unittest {
        Signal!(int) someSignal;
        int foo = 0;
        int bar = 0;

        auto c1 = someSignal.connect((int x) {
            foo = x;
        });
        auto c2 = someSignal.connect((int y) {
            bar = y;
        });

        someSignal.emit(4);
        assert(foo == 4 && bar == 4);

        c2.disconnect();
        someSignal.emit(5);
        assert(foo == 5 && bar == 4);

        auto c3 = someSignal.connect((int y) {
            bar = -y;
        });
        someSignal.emit(8);
        assert(foo == 8 && bar == -8);

        c1.disconnect();
        someSignal.emit(9);
        assert(foo == 8 && bar == -9);

        c3.disconnect();
        someSignal.emit(10);
        assert(foo == 8 && bar == -9);

        auto c4 = someSignal.connect((int x) {
            foo = bar = x;
        });
        someSignal.emit(11);
        assert(foo == 11 && bar == 11);

        c4.disconnect();
        someSignal.emit(12);
        assert(foo == 11 && bar == 11);
    }
    //unittest {
    //    log.write("Starting scoping test");
    //    Signal!(int) someSignal;
    //    int foo = 0, bar = 0;

    //    someSignal.connect((int x) { foo = x; }, true);
    //    someSignal.emit(12);
    //    assert(foo == 0);
    //}
}


// Window event API.
// Provides signals for window size + resolution, and guarantees that these get called
// from the main thread once per frame (at most).
struct WindowEvents {
    static WindowEvents instance;
    private this (this) {}
private:
    Window mainWindow = null;
    typeof(mainWindow.pixelDimensions)  lastPixelDimensions;
    typeof(mainWindow.screenDimensions) lastScreenDimensions;
    typeof(mainWindow.screenScale)      lastScreenScale;

    typeof(getpid()) eventThreadPid;

public:
    //mixin Signal!(float, float) onScreenSizeChanged;
    //mixin Signal!(float, float) onFramebufferSizeChanged;
    //mixin Signal!(float, float) onScreenScaleChanged;

    Signal!(float, float) onScreenSizeChanged;
    Signal!(float, float) onFramebufferSizeChanged;
    Signal!(float, float) onScreenScaleChanged;

    void init (typeof(mainWindow) window) { 
        assert(mainWindow is null);
        mainWindow = window;
        eventThreadPid = getpid();
        updateFromMainThread();
    }
    void deinit () {
        mainWindow = null;
        eventThreadPid = 0;
    }
    void updateFromMainThread () {
        assert(!(mainWindow is null));
        assert(getpid() == eventThreadPid);
        bool needsUpdate = false;

        if (mainWindow.pixelDimensions != lastPixelDimensions) {
            lastPixelDimensions = mainWindow.pixelDimensions;
            onFramebufferSizeChanged.emit(
                cast(float)lastPixelDimensions.x,
                cast(float)lastPixelDimensions.y
            );
            needsUpdate = true;
        }
        if (mainWindow.screenDimensions != lastScreenDimensions) {
            lastScreenDimensions = mainWindow.screenDimensions;
            onScreenSizeChanged.emit(
                cast(float)lastScreenDimensions.x,
                cast(float)lastScreenDimensions.y
            );
            needsUpdate = true;
        }
        if (needsUpdate && mainWindow.recalcScreenScale() != lastScreenScale) {
            lastScreenScale = mainWindow.screenScale;
            onScreenScaleChanged.emit(
                lastScreenScale.x,
                lastScreenScale.y
            );
        }
    }
}



