//module sb.platform.window;

//interface IPlatformWindow {
//    // Get name (IPlatformWindow id, set w/ createWindow())
//    string          getName ();

//    // Setters
//    IPlatformWindow setResolution (uint x, uint y);

//    IPlatformWindow setResize     (SbWindowResize);
//    IPlatformWindow setScaling    (SbScreenScale scaling);
//    IPlatformWindow setCustomScale (double x, double y);

//    IPlatformWindow setTitle (string);
//    IPlatformWindow setTitle (const(char)* str, size_t len = 0);

//    // Kills the window
//    void release ();
//}

//struct SbWindowOptions {
//    // window size + screen options.
//    // Note: will attempt to best-fit screen + resolution with default options.
//    //   eg. with size=10000x10000 + default options and 2 screens @1080p + 720p, will choose
//    //       the bigger screen and clamp size to 1080x1920, minus menu bar size (if on osx)
//    //
//    uint[2] preferredWindowSize;       // preferred window size in pixels
//    int     preferredScreenIndex = -1; // [0..num screens) for screen X; -1 for any screen
//    bool    clampToScreenSize = true;  // if true, may clamp window size to fit whatever screen we end up using

//    // resize options
//    SbWindowResize resizeOption     = SbWindowResize.MAY_RESIZE;

//    // retina screen scaling
//    SbScreenScale screenScaleOption = SbScreenScale.AUTODETECT_RESOLUTION;
//    double[2] customScreenScale;  // used iff screenScaleOption == SbScreenScale.CUSTOM_SCALE
//}

//// Window resizing options
//enum SbWindowResize : ubyte { MAY_RESIZE, NO_RESIZE }

//// Retina resolution scaling options (eg. downscales screen res by 1/2x in each dimension for FORCE_SCALE_2X).
//enum SbScreenScale : ubyte {
//    AUTODETECT_RESOLUTION,  // autodetect retina if screen + window sizes differ (use this for OSX!)
//    FORCE_SCALE_1X,         // force 1x (default / non-retina screen)    (use these for linux)
//    FORCE_SCALE_2X,         // force 2x (retina  / 2x res screen; window pixels will be scaled 1/2x)
//    FORCE_SCALE_4X,         // force 4x (????    / 4x res screen; window pixels will be scaled 1/4x)
//    CUSTOM_SCALE            // use with SbWindowOptions.customScreenScale if none of the above apply 
//                            // and you want a wierd 1/3x screen scaling or 1/2x horizontal + 1/4x vertical
//                            // or some such shit; alternatively, if you want bigger fonts + UI and don't care
//                            // about rendering artifacts, you can use this to achieve that.

//    // Platform-specific notes:
//    // on OSX, glfw reported window + screen resolution will differ, so we can/should use AUTODETECT
//    // on Linux, glfw seems to report same window + screen resolution (might depend on distro + drivers?),
//    //    so AUTODETECT will not work; use FORCE_SCALE_2X / etc., if you're using a retina/high-res screen
//    // on Windows... dunno, not tested, but either of the above two options will probably work.
//}