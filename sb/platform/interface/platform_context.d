module sb.platform.platform_context;
import sb.platform.window;
import sb.events;

// Create platform index
IPlatform sbCreatePlatformContext (SbPlatformConfig);

interface IPlatform {
    // platform init + deinit calls: call initMain + teardown on main thread,
    // and initGL on graphics thread (may be main thread)
    void initMain ();
    void initGL   ();
    void teardown ();

    // Window + screen access
    IPlatformWindow createWindow (string id, SbWindowOptions);
    IPlatformWindow getWindow    (string id);
    ScreenInfo[]    getScreenInfo ();
    uint[2][]       getResolutions (uint screenIndex);

    // wraps glfwSwapBuffers
    void swapBuffers ();

    // Event polling: produces a list of events (see sb.events)
    void pollEvents (IEventProducer);
}

// screen + resolution info
struct ScreenInfo {
    uint[2] hardwareResolution; // full hardware screen res
    uint[2] scaledResolution;   // possibly downscaled res given screen scaling options
}

enum GLVersion { GL_410 };

// Platform config
struct SbPlatformConfig {
    GLVersion glVersion;
}





