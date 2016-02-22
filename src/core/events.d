
module gsb.core.events;
import gsb.core.window;
import gsb.core.log;
import gsb.core.pseudosignals;

import gl3n.linalg;
import core.thread;

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

struct GraphicsEvents {
    static Signal!() glStateInvalidated;
}



