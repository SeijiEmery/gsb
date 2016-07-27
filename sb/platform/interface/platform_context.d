module sb.platform.platform_context;
import sb.platform.events;
import sb.gl;
import gl3n.linalg;

// Create platform index
IPlatform sbCreatePlatformContext (SbPlatformConfig);

interface IPlatform {
    // platform init + deinit calls: call initMain + teardown on main thread,
    // and initGL on graphics thread (may be main thread)
    void init ();
    void preInitGL ();
    void initGL ();
    void teardown ();

    IGraphicsContext getGraphicsContext ();
    IEventsInstance  getEventsInstance  ();

    // Window + screen access
    IPlatformWindow createWindow (string id, SbWindowOptions);
    IPlatformWindow getWindow    (string id);
    //ScreenInfo[]    getScreenInfo ();
    //uint[2][]       getResolutions (uint screenIndex);

    // wraps glfwSwapBuffers
    void swapBuffers ();
    void pollEvents ();
}

interface IPlatformWindow {
    // Get name (IPlatformWindow id, set w/ createWindow())
    string          getName ();

    // Set window size + screen scaling
    IPlatformWindow setWindowSize (vec2i size);
    IPlatformWindow setResizable  (bool resizable);
    IPlatformWindow setScaling    (SbScreenScale scaling);
    IPlatformWindow setCustomScale (double x, double y);

    // Set window title
    IPlatformWindow setTitle (string);
    IPlatformWindow setTitle (const(char)* str, size_t len = 0);

    // Set and enable/disable fps counter in the window title 
    // (displayed in addition to window title when enabled)
    IPlatformWindow setTitleFPSVisible (bool visible);
    IPlatformWindow setTitleFPS        (double fps);
    IPlatformWindow setTitleFPSFormat  (string fmt = DEFAULT_WINDOW_TITLE_FPS_FMT);

    // Low-level window close events: check / set shouldClose, and (optionally)
    // register a onClosed callback for intercepting window close actions
    bool shouldClose ();
    IPlatformWindow onClosed  (void delegate(IPlatformWindow));
    IPlatformWindow setShouldClose (bool closed = true);

    // Kills the window
    void release ();
}
immutable auto DEFAULT_WINDOW_TITLE_FPS_FMT = "(%0.1f FPS)";

// screen + resolution info
struct ScreenInfo {
    uint[2] hardwareResolution; // full hardware screen res
    uint[2] scaledResolution;   // possibly downscaled res given screen scaling options
}

enum SbPlatform_Backend   { NONE = 0, GLFW3 };
enum SbPlatform_GLVersion { NONE = 0, GL_410 };

// Platform config
struct SbPlatformConfig {
    SbPlatform_Backend   backend;
    SbPlatform_GLVersion glVersion;
}




struct SbWindowConfig {
    string title;
    uint size_x, size_y;
    bool resizable = true;
}
struct SbWindowOptions {
    // window size + screen options.
    // Note: will attempt to best-fit screen + resolution with default options.
    //   eg. with size=10000x10000 + default options and 2 screens @1080p + 720p, will choose
    //       the bigger screen and clamp size to 1080x1920, minus menu bar size (if on osx)
    //
    uint[2] preferredWindowSize;       // preferred window size in pixels
    int     preferredScreenIndex = -1; // [0..num screens) for screen X; -1 for any screen
    bool    clampToScreenSize = true;  // if true, may clamp window size to fit whatever screen we end up using

    // resize options
    SbWindowResize resizeOption     = SbWindowResize.MAY_RESIZE;

    // retina screen scaling
    SbScreenScale screenScaleOption = SbScreenScale.AUTODETECT_RESOLUTION;
    double[2] customScreenScale;  // used iff screenScaleOption == SbScreenScale.CUSTOM_SCALE
}

// Window resizing options
enum SbWindowResize : ubyte { MAY_RESIZE, NO_RESIZE }

// Retina resolution scaling options (eg. downscales screen res by 1/2x in each dimension for FORCE_SCALE_2X).
enum SbScreenScale : ubyte {
    AUTODETECT_RESOLUTION,  // autodetect retina if screen + window sizes differ (use this for OSX!)
    FORCE_SCALE_1X,         // force 1x (default / non-retina screen)    (use these for linux)
    FORCE_SCALE_2X,         // force 2x (retina  / 2x res screen; window pixels will be scaled 1/2x)
    FORCE_SCALE_4X,         // force 4x (????    / 4x res screen; window pixels will be scaled 1/4x)
    CUSTOM_SCALE            // use with SbWindowOptions.customScreenScale if none of the above apply 
                            // and you want a wierd 1/3x screen scaling or 1/2x horizontal + 1/4x vertical
                            // or some such shit; alternatively, if you want bigger fonts + UI and don't care
                            // about rendering artifacts, you can use this to achieve that.

    // Platform-specific notes:
    // on OSX, glfw reported window + screen resolution will differ, so we can/should use AUTODETECT
    // on Linux, glfw seems to report same window + screen resolution (might depend on distro + drivers?),
    //    so AUTODETECT will not work; use FORCE_SCALE_2X / etc., if you're using a retina/high-res screen
    // on Windows... dunno, not tested, but either of the above two options will probably work.
}


