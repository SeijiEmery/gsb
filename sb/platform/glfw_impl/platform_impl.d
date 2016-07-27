module sb.platform.impl.platform_impl;
import sb.platform;
import sb.events;
import sb.gl;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;
import std.exception: enforce;
import gl3n.linalg;
import std.format;
import std.string: toStringz;
import core.stdc.string: strlen;

IPlatform sbCreatePlatformContext (IGraphicsLib graphicsLib, SbPlatformConfig config) {
    enforce(config.backend != SbPlatform_Backend.NONE,
        format("Invalid platform: %s", config.backend));
    enforce(config.glVersion != SbPlatform_GLVersion.NONE,
        format("Invalid gl version: %s", config.glVersion));

    enforce(graphicsLib.glVersion == GraphicsLibVersion.GL_410,
        format("Unsupported graphics backend: %s", graphicsLib.glVersion));

    switch (config.backend) {
        case SbPlatform_Backend.GLFW3:
            return new SbPlatform( graphicsLib, config );
        default:
            throw new Exception(format("Unsupported platform backend: %s", config.backend));
    }
}
struct SbTime {
    immutable size_t NUM_SAMPLES = 128;
    double[NUM_SAMPLES] mt_in_frame_samples;
    double[NUM_SAMPLES] mt_frame_samples;
    double ft_start, ft_end, ft_deltaTime = 0;
    uint   frameId = 0;

    this (this) { ft_start = ft_end = glfwGetTime(); }
    void beginFrame () {
        auto now = glfwGetTime();
        frameId = (frameId + 1) % NUM_SAMPLES;

        ft_deltaTime = now - ft_start;
        ft_start     = now;
        mt_frame_samples[ frameId ] = ft_deltaTime;
    }
    void endFrame () {
        ft_end = glfwGetTime();
        mt_in_frame_samples[ frameId ] = ft_end - ft_start;
    }
    @property auto frameTime   () { return ft_start; }
    @property auto currentTime () { return glfwGetTime(); }
    @property auto dt          () { return ft_deltaTime; }
    @property auto frameIndex  () { return frameId; }
    @property auto timeSamples () {
        import std.range: chain;
        return chain( mt_frame_samples[ frameId+1 .. $ ], mt_frame_samples[ 0 .. frameId+1 ] );
    }
}

class SbPlatform : IPlatform {
    SbPlatformConfig m_config;
    IGraphicsLib     m_graphicsLib;
    SbWindow[string] m_windows;
    SbWindow         m_mainWindow;
    SbTime           m_time;

    this (IGraphicsLib graphicsLib, SbPlatformConfig config) { 
        m_config = config;
        m_graphicsLib = graphicsLib;
    }
    void init () {
        // preload gl + glfw
        DerelictGLFW3.load();
        m_graphicsLib.preInit();

        enforce( glfwInit(), "failed to initialize glfw" );
    }
    void initGL () {
        m_graphicsLib.initOnThread();
        if (m_mainWindow)
            glfwMakeContextCurrent(m_mainWindow.handle);
    }
    void teardown () {
        foreach (name, window; m_windows) {
            window.release();
        }
        glfwTerminate();
        m_graphicsLib.teardown();
    }
    IGraphicsContext graphicsContext () { 
        return m_graphicsLib.getContext; 
    }
    IPlatformWindow createWindow (string id, SbWindowConfig config) {
        import std.variant: visit;

        enforce(id !in m_windows, format("Already registered window '%s'", id));
        enforce(!m_mainWindow, format("Unimplemented: multi-window support"));

        assert( m_graphicsLib.glVersion == GraphicsLibVersion.GL_410 );
        m_graphicsLib.getVersionInfo.visit!(
            (OpenglVersionInfo info) {
                glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, info.VERSION_MAJOR);
                glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, info.VERSION_MINOR);
                glfwWindowHint(GLFW_OPENGL_PROFILE, info.IS_CORE_PROFILE ?
                    GLFW_OPENGL_CORE_PROFILE : GLFW_OPENGL_ANY_PROFILE);
                glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, info.IS_FORWARD_COMPAT ?
                    GL_TRUE : GL_FALSE);
            }
        );
        glfwWindowHint(GLFW_RESIZABLE, config.resizable ? GL_TRUE : GL_FALSE);

        auto handle = glfwCreateWindow(
            config.size_x, config.size_y,
            config.title.toStringz,
            null, null);
        enforce(handle, format("Failed to create window '%s'", id));

        auto window = new SbWindow( this, id, handle, config );
        m_windows[ id ] = window;
        if (!m_mainWindow) {
            m_mainWindow = window;
            glfwMakeContextCurrent( handle );
        }
    }
    IPlatformWindow getWindow (string id) {
        return id in m_windows ? m_windows[id] : null;
    }
    private void unregisterWindow (string id) {
        if (id in m_windows) {
            if (m_windows[id] == m_mainWindow)
                m_mainWindow = null;

            m_windows.remove(id);
        }
    }
    void swapFrame () {
        if (m_mainWindow) {
            m_time.endFrame();
            glfwSwapBuffers( m_mainWindow.handle );
            m_time.beginFrame();
        }
    }
    void pollEvents () {
        glfwPollEvents();
        eventImpl.beginFrame();
        foreach (_, window; m_windows) {
            window.collectEvents( eventImpl.eventProducer );
            window.swapState();
        }
        pollGamepads();
        eventImpl.dispatchEvents();
    }
    private void pollGamepads () {
        // TODO: integrate existing glfw gamepad impl
    }
}

struct SbWindowState {
    vec2i windowSize, framebufferSize;
    vec2  scaleFactor; // 1.0 + 0.5 for retina, and other scale factors for w/e (hacky way to scale ui)
    float aspectRatio;
    bool fullscreen = false;

    void recalcScaleFacor () {
        scaleFactor.x = cast(double)framebufferSize.x / cast(double)windowSize.x;
        scaleFactor.y = cast(double)framebufferSize.y / cast(double)windowSize.y;
    }
}


class SbWindow : IPlatformWindow {
    SbPlatform platform;
    string     id;
    GLFWwindow*    handle;
    SbWindowConfig config;
    
    // current + next window state. Mutating operations change @nextState, 
    // preserving @state until swapState() is called.
    SbWindowState  state, nextState;

    // Screen scaling options (corresponds to SbScreenScale)
    bool autodetectScreenScale = true;
    vec2 forcedScaleFactor     = 0.0;   // used iff !autodetectScreenScale

    // Internal event buffer.
    // Populated by glfw event callbacks (ASSUMES single-threaded / synchronous);
    // consumed by an IEventProducer via consumeEvents().
    SbEvent[] windowEvents;

    // D Callbacks
    void delegate(SbWindow) nothrow closeAction = null;

    // Window fps, etc
    bool   showWindowFPS;
    string windowFpsString = "";
    string windowFpsFormat = DEFAULT_WINDOW_TITLE_FPS_FMT;
    double lastWindowFps   = 0;

    this (
        typeof(platform) platform, typeof(id) id, 
        typeof(handle) handle, typeof(config) config
    ) {
        this.platform = platform;
        this.id     = id;
        this.handle = handle;
        this.config = config;

        // Setup state: for simplicity, we call setScreenScale (calls onWindowSizeChanged)
        // and swapState() to make state / nextState match starting window config parameters.
        this.state.windowSize = vec2i(config.size_x, config.size_y);
        if (config.screenScaleOption != SbScreenScale.CUSTOM_SCALE)
            setScreenScale( config.screenScaleOption );
        else
            setScreenScale( config.customScale );
        swapState();

        // set glfw callbacks (almost all callbacks are on a per-window basis)
        glfwSetWindowUserPointer(handle, cast(void*)this);
        glfwSetWindowSizeCallback(handle, &windowSizeCallback);
        glfwSetFramebufferSizeCallback(handle, &windowFramebufferSizeCallback);
        glfwSetWindowFocusCallback(handle, &windowFocusCallback);
        glfwSetWindowRefreshCallback(handle, &windowRefreshCallback);
        glfwSetKeyCallback(handle,  &windowKeyInputCallback);
        glfwSetCharCallback(handle, &windowCharInputCallback);
        glfwSetCursorPosCallback(handle, &windowCursorInputCallback);
        glfwSetCursorEnterCallback(handle, &windowCursorEnterCallback);
        glfwSetMouseButtonCallback(handle, &windowMouseBtnInputCallback);
        glfwSetScrollCallback(handle, &windowScrollInputCallback);
    }
    void release () {
        platform.unregisterWindow( id );
        if (handle) {
            glfwDestroyWindow( handle );
            handle = null;
        }
    }
    private void collectEvents (IEventProducer evp) {
        evp.processEvents( windowEvents );
        windowEvents.length = 0;
    }
    private void updateWindowTitle () {
        glfwSetWindowTitle(handle, showWindowFPS ?
            format("%s %s", config.title, windowFpsString).toStringz :
            config.title.toStringz
        );
    }
    IPlatformWindow setTitle ( string title ) {
        config.title = title;
        return updateWindowTitle, this;
    }
    IPlatformWindow setTitle ( const(string) title ) {
        config.title = title;
        return updateWindowTitle, this;
    }
    IPlatformWindow setTitle ( const(char)* title, size_t title_len = 0 ) {
        return setTitle( title_len ? 
            title[0..title_len] : 
            title[0 .. strlen(title)] 
        );
    }
    IPlatformWindow setTitleFPSVisible (bool visible) {
        showWindowFPS = visible;
        return updateWindowTitle, this;
    }
    IPlatformWindow setTitleFPS (double fps) {
        windowFpsString = format( windowFpsFormat, lastWindowFps = fps );
        return updateWindowTitle, this;
    }
    IPlatformWindow setTitleFPSFormat (string fmt) {
        windowFpsString = format( windowFpsFormat = fmt, lastWindowFps );
        return this;
    }

    bool shouldClose () { return glfwWindowShouldClose(handle) != 0; }
    IPlatformWindow setShouldClose (bool close = true) {
        glfwSetWindowShouldClose(handle, close);
        return this;
    }
    IPlatformWindow onClose (void delegate(SbWindow) nothrow dg) {
        closeAction = dg;
        glfwSetWindowCloseCallback(handle, &windowCloseCallback);
        return this;
    }

    IPlatformWindow setResizable (bool resizable) {
        if (resizable != config.resizable) {
            config.resizable = resizable;
            glfwSetWindowResizable(handle, resizable);
        }
    }



    IPlatformWindow setWindowSize ( vec2i size ) {
        onWindowSizeChanged( size.x, size.y );
        return this;
    }
    IPlatformWindow setScreenScale ( SbScreenScale option ) {
        autodetectScreenScale = option == SbScreenScale.AUTODETECT_RESOLUTION;
        final switch (option) {
            case SbScreenScale.FORCE_SCALE_1X: forcedScaleFactor = vec2(1, 1);       break;
            case SbScreenScale.FORCE_SCALE_2X: forcedScaleFactor = vec2(0.5, 0.5);   break;
            case SbScreenScale.FORCE_SCALE_4X: forcedScaleFactor = vec2(0.25, 0.25); break;
            case SbScreenScale.CUSTOM_SCALE:   autodetectScreenScale = true;         break;
            case SbScreenScale.AUTODETECT_RESOLUTION: break;
        }
        config.screenScaleOption = option;
        onWindowSizeChanged( state.windowSize.x, state.windowSize.y );
        return this;
    }
    IPlatformWindow setScreenScale ( vec2 customScale ) {
        autodetectScreenScale = false;
        forcedScaleFactor = customScale;

        config.screenScaleOption = SbScreenScale.CUSTOM_SCALE;
        config.customScale       = customScale;
        onWindowSizeChanged( state.windowSize.x, state.windowSize.y );
        return this;
    }
    void swapState () {
        state = nextState;
    }

    // Window callbacks (onWindowSizeChanged is also called by internal state setting code)
    private void onWindowSizeChanged ( int width, int height ) nothrow @safe {
        nextState.windowSize = vec2i(width, height);
        nextState.aspectRatio = cast(double)width / cast(double)height;

        if (autodetectScreenScale) {
            nextState.scaleFactor = vec2(
                cast(double)nextState.framebufferSize.x / cast(double)nextState.windowSize.x,
                cast(double)nextState.framebufferSize.y / cast(double)nextState.windowSize.y
            );
        } else {
            nextState.scaleFactor = forcedScaleFactor;
            nextState.framebufferSize = vec2i(
                cast(int)( nextState.windowSize.x * forcedScaleFactor.x ),
                cast(int)( nextState.windowSize.y * forcedScaleFactor.y ),
            );
        }
    }
    private void onFrameBufferSizeChanged ( int width, int height ) nothrow @safe{
        if (autodetectScreenScale) {
            nextState.framebufferSize = vec2i(width, height);
            nextState.scaleFactor = vec2(
                cast(double)nextState.framebufferSize.x / cast(double)nextState.windowSize.x,
                cast(double)nextState.framebufferSize.y / cast(double)nextState.windowSize.y
            );
        }
    }
    // Called when window "damaged" and any persistent elements (eg. UI?) needs to be fully re-rendered
    private void onWindowNeedsRefresh () nothrow @safe {
        windowEvents ~= SbEvent(SbWindowRefreshEvent(this));
    }
    // Called when window gains / loses input focus
    private void onInputFocusChanged (bool hasFocus) nothrow @safe {
        windowEvents ~= SbEvent(SbWindowFocusChangedEvent(this, hasFocus));
    }
    // Called when cursor enters / exits window
    private void onCursorFocusChanged (bool hasFocus) nothrow @safe {
        windowEvents ~= SbEvent(SbWindowMouseoverChangedEvent(this, hasFocus));
    }
    // Input callback: mouse motion
    private void onCursorInput ( double xpos, double ypos ) nothrow @safe {
        windowEvents ~= SbEvent(SbMouseMoveEvent( vec2(xpos, ypos), lastMousePos ));
        lastMousePos.x = xpos; lastMousePos.y = ypos;
    }
    // Input callback: mouse wheel / trackpad scroll motion
    private void onScrollInput ( double xoffs, double yoffs ) nothrow @safe {
        windowEvents ~= SbEvent(SbScrollInputEvent( vec2(xoffs, yoffs) ));
    }
    // Input callback: mouse button press state changed
    private void onMouseButtonInput ( int button, int action, int mods ) nothrow @safe {
        windowEvents ~= SbEvent(SbMouseButtonEvent( button, action, mods ));
    }
    // Input callback: keyboard key press state changed
    private void onKeyInput( int key, int scancode, int action, int mods ) nothrow @safe {
        windowEvents ~= SbEvent(SbKeyEvent( key, scancode, action, mods ));
    }
    // Input callback: text input (key pressed as unicode codepoint)
    private void onCharInput ( dchar chr ) nothrow @safe {
        windowEvents ~= SbEvent(SbRawCharEvent( chr ));
    }
}

// GLFW Callbacks
private SbWindow getWindow (GLFWwindow* handle) nothrow @trusted {
    return cast(SbWindow)glfwGetWindowUserPointer(handle);
}
//private auto doWindowCallback(string name)(GLFWwindow* handle) {
//    auto window = handle.getWindow();
//    mixin("if (window."~name~") window."~name~"(window);");
//}
extern(C) private void windowCloseCallback (GLFWwindow* handle) nothrow {
    //handle.doWindowCallback!"closeAction";
    auto window = handle.getWindow;
    if (window.closeAction)
        window.closeAction(window);
}
extern(C) private void windowSizeCallback (GLFWwindow* handle, int width, int height) nothrow @safe {
    handle.getWindow.onWindowSizeChanged( width, height );
}
extern(C) private void windowFramebufferSizeCallback (GLFWwindow* handle, int width, int height) nothrow @safe {
    handle.getWindow.onFrameBufferSizeChanged( width, height );
}
extern(C) private void windowFocusCallback (GLFWwindow* handle, int focused) nothrow @safe {
    handle.getWindow.onInputFocusChanged( focused != 0 );
}
extern(C) private void windowRefreshCallback (GLFWwindow* handle) nothrow @safe {
    handle.getWindow.onWindowNeedsRefresh();
}
extern(C) private void windowKeyInputCallback (GLFWwindow* handle, int key, int scancode, int action, int mods) nothrow @safe {
    handle.getWindow.onKeyInput(key, scancode, action, mods);
}
extern(C) private void windowCharInputCallback (GLFWwindow* handle, uint codepoint) nothrow @safe {
    handle.getWindow.onCharInput( cast(dchar)codepoint );
}
extern(C) private void windowCursorInputCallback (GLFWwindow* handle, double xpos, double ypos) nothrow @safe {
    handle.getWindow.onCursorInput( xpos, ypos );
}
extern(C) private void windowCursorEnterCallback (GLFWwindow* handle, int entered) nothrow @safe {
    handle.getWindow.onCursorFocusChanged( entered != 0 );
}
extern(C) private void windowMouseBtnInputCallback (GLFWwindow* handle, int button, int action, int mods) nothrow @safe {
    handle.getWindow.onMouseButtonInput( button, action, mods );
}
extern(C) private void windowScrollInputCallback (GLFWwindow* handle, double xoffs, double yoffs) nothrow @safe {
    handle.getWindow.onScrollInput( xoffs, yoffs );
}




































