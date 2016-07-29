module sb.platform.platform_impl;
import sb.platform.platform_interface;
import sb.events;
import sb.gl;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;
import std.exception: enforce;
import gl3n.linalg;
import std.format;
import std.string: toStringz;
import core.stdc.string: strlen;

extern(C) IPlatform sbCreatePlatformContext (IGraphicsLib graphicsLib, SbPlatformConfig config) {
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
    IGraphicsContext m_graphicsContext = null;

    SbWindow[string] m_windows;
    SbWindow         m_mainWindow;
    SbTime           m_time;
final:
    this (IGraphicsLib graphicsLib, SbPlatformConfig config) { 
        m_config = config;
        m_graphicsLib = graphicsLib;
    }
    override void init () {
        // preload gl + glfw
        DerelictGLFW3.load();
        m_graphicsLib.preInit();

        enforce( glfwInit(), "failed to initialize glfw" );
    }
    override void initGL () {
        m_graphicsLib.initOnThread();
        if (m_mainWindow)
            glfwMakeContextCurrent(m_mainWindow.handle);
        m_graphicsContext = m_graphicsLib.getContext;
        m_graphicsContext.beginFrame();
    }
    override void teardown () {
        foreach (name, window; m_windows) {
            window.release();
        }
        glfwTerminate();
        m_graphicsLib.teardown();
    }
    override IGraphicsContext getGraphicsContext () { 
        assert(m_graphicsContext, "GL not initialized!");
        return m_graphicsContext; 
    }
    override IPlatformWindow createWindow (string id, SbWindowConfig config) {
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
        return window;
    }
    override IPlatformWindow getWindow (string id) {
        return id in m_windows ? m_windows[id] : null;
    }
    private void unregisterWindow (string id) {
        if (id in m_windows) {
            if (m_windows[id] == m_mainWindow)
                m_mainWindow = null;

            m_windows.remove(id);
        }
    }
    override void swapFrame () {
        if (m_mainWindow) {
            m_graphicsContext.endFrame();
            m_time.endFrame();

            glfwSwapBuffers( m_mainWindow.handle );

            m_time.beginFrame();
            m_graphicsContext.beginFrame();
        }
    }
    override void pollEvents () {
        glfwPollEvents();
        //eventImpl.beginFrame();
        foreach (_, window; m_windows) {
            //window.collectEvents( eventImpl.eventProducer );
            window.collectEvents();
            window.swapState();
        }
        pollGamepads();
        //eventImpl.dispatchEvents();
    }
    private void pollGamepads () {
        // TODO: integrate existing glfw gamepad impl
    }


    // Raw input callbacks (we force a bunch of stuff to "call home" from window obj => shared platform obj)
    // We're gonna assume that said callbacks never get called from more than one thread (this is up to glfw),
    // and the point of this is, if we ever support more than one window and actually _care_ about what order
    // the events come in, we'll have enough info (more than enough) to determine what events happened when,
    // in which proper sequence, and affecting which windows across any given frame.
    //
    // For the time being we don't really care, since > 1 window is out of the question, but when/if we do
    // add multi-window / multi-monitor full-screen support, and decide to maybe use a more complex input
    // / event model, then the infrastructure to do it already exists :)

    private void pushRawInput ( SbWindow window, RawMouseBtnInput input ) nothrow @safe {

    }
    private void pushRawInput ( SbWindow window, RawKeyInput input ) nothrow @safe {

    }
    private void pushRawInput ( SbWindow window, RawCharInput input ) nothrow @safe {

    }

    // Unused, but possibly useful redundant callbacks. Focus + mouse motion events are already handled
    // in SbWindow / SbWindowState, but these give us some extra context for the above events, if we
    // need it or something... 
    private void notifyInputFocusChanged (SbWindow window, bool hasFocus) nothrow @safe {}
    private void notifyCursorFocusChanged (SbWindow window, bool hasFocus) nothrow @safe {}
    private void notifyCursorInput (SbWindow window, double x, double y) nothrow @safe {}
}

struct RawMouseBtnInput { int btn, action, mods; }
struct RawKeyInput      { int key, scancode, action, mods; }
struct RawCharInput     { dchar chr; }
alias RawInputEvent = Algebraic!(RawMouseBtnInput, RawKeyInput, RawCharInput);

struct SbWindowState {
    // Authoritative window state (mostly set by events)
    vec2i windowSize, framebufferSize;
    vec2  scaleFactor; // 1.0 + 0.5 for retina, and other scale factors for w/e (hacky way to scale ui)
    float aspectRatio;
    bool fullscreen = false;

    void recalcScaleFacor () {
        scaleFactor.x = cast(double)framebufferSize.x / cast(double)windowSize.x;
        scaleFactor.y = cast(double)framebufferSize.y / cast(double)windowSize.y;
    }

    // Raw event state
    vec2 mousePos     = vec2(0, 0);
    vec2 scrollDelta  = vec2(0, 0);

    bool wantsRefresh = false;
    bool hasInputFocus = true;
    bool hasCursorFocus = true;
}
private void swapState (ref SbWindowState a, ref SbWindowState b) {
    a = b;
    b.wantsRefresh = false;

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
    void delegate(IPlatformWindow) nothrow closeAction = null;

    // Window fps, etc
    bool   showWindowFPS   = false;
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
        this.showWindowFPS = config.showFps;
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
    override void release () {
        platform.unregisterWindow( id );
        if (handle) {
            glfwDestroyWindow( handle );
            handle = null;
        }
    }
    override string getName () { return id; }



    private void updateWindowTitle () {
        glfwSetWindowTitle(handle, showWindowFPS ?
            format("%s %s", config.title, windowFpsString).toStringz :
            config.title.toStringz
        );
    }
    override IPlatformWindow setTitle ( string title ) {
        config.title = title;
        return updateWindowTitle, this;
    }
    override IPlatformWindow setTitleFPSVisible (bool visible) {
        showWindowFPS = visible;
        return updateWindowTitle, this;
    }
    override IPlatformWindow setTitleFPS (double fps) {
        windowFpsString = format( windowFpsFormat, lastWindowFps = fps );
        return updateWindowTitle, this;
    }
    override IPlatformWindow setTitleFPSFormat (string fmt) {
        windowFpsString = format( windowFpsFormat = fmt, lastWindowFps );
        return this;
    }

    override bool shouldClose () { return glfwWindowShouldClose(handle) != 0; }
    override IPlatformWindow setShouldClose (bool close = true) {
        glfwSetWindowShouldClose(handle, close);
        return this;
    }
    override IPlatformWindow onClosed (void delegate(IPlatformWindow) nothrow dg) {
        closeAction = dg;
        glfwSetWindowCloseCallback(handle, &windowCloseCallback);
        return this;
    }

    // NOT SUPPORTED BY GLFW...
    //IPlatformWindow setResizable (bool resizable) {
    //    if (resizable != config.resizable) {
    //        config.resizable = resizable;
    //        glfwSetWindowResizable(handle, resizable);
    //    }
    //}
    override IPlatformWindow setWindowSize ( vec2i size ) {
        onWindowSizeChanged( size.x, size.y );
        return this;
    }

    private void collectEvents (/*IEventProducer evp*/) {
        if (state.scaleFactor != nextState.scaleFactor)
            windowEvents ~= SbEvent(SbWindowRescaleEvent(id, state.scaleFactor, nextState.scaleFactor));
        if (state.windowSize != nextState.windowSize)
            windowEvents ~= SbEvent(SbWindowResizeEvent(id, state.windowSize, nextState.windowSize));

        if (state.mousePos != nextState.mousePos)
            windowEvents ~= SbEvent(SbMouseMoveEvent( nextState.mousePos, state.mousePos ));
        if (state.scrollDelta.x || state.scrollDelta.y)
            windowEvents ~= SbEvent(SbScrollInputEvent( state.scrollDelta ));

        import std.stdio;
        foreach (event; windowEvents)
            writefln("%s", event);
        //evp.processEvents( windowEvents );
        windowEvents.length = 0;
    }
    override IPlatformWindow setScreenScale ( SbScreenScale option ) {
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
    override IPlatformWindow setScreenScale ( vec2 customScale ) {
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
    private void onWindowSizeChanged ( int width, int height ) nothrow {
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
    private void onFrameBufferSizeChanged ( int width, int height ) nothrow {
        if (autodetectScreenScale) {
            nextState.framebufferSize = vec2i(width, height);
            nextState.scaleFactor = vec2(
                cast(double)nextState.framebufferSize.x / cast(double)nextState.windowSize.x,
                cast(double)nextState.framebufferSize.y / cast(double)nextState.windowSize.y
            );
        }
    }

    // Called when window "damaged" and any persistent elements (eg. UI?) needs to be fully re-rendered
    private void onWindowNeedsRefresh () nothrow {
        nextState.wantsRefresh = true;
        windowEvents ~= SbEvent(SbWindowNeedsRefreshEvent( id ));
    }
    // Called when window gains / loses input focus
    private void onInputFocusChanged (bool hasFocus) nothrow {
        nextState.hasInputFocus = hasFocus;
        windowEvents ~= SbEvent(SbWindowFocusChangeEvent( id, hasFocus ));
        platform.notifyInputFocusChanged( this, hasFocus );
    }
    // Called when cursor enters / exits window
    private void onCursorFocusChanged (bool hasFocus) nothrow {
        nextState.hasCursorFocus = hasFocus;
        windowEvents ~= SbEvent(SbWindowMouseoverEvent( id, hasFocus ));
        platform.notifyCursorFocusChanged( this, hasFocus );
    }
    // Input callback: mouse motion
    private void onCursorInput ( double xpos, double ypos ) nothrow {
        nextState.mousePos = vec2(xpos, ypos);
        platform.notifyCursorInput( this, xpos, ypos );
    }
    // Input callback: mouse wheel / trackpad scroll motion
    private void onScrollInput ( double xoffs, double yoffs ) nothrow {
        nextState.scrollDelta += vec2(xoffs, yoffs);
    }
    // Input callback: mouse button press state changed
    private void onMouseButtonInput ( int button, int action, int mods ) nothrow {
        windowEvents ~= SbEvent(SbMouseButtonEvent( button, action, mods ));
        platform.pushRawInput( this, RawMouseBtnInput( button, action, mods ));
    }
    // Input callback: keyboard key press state changed
    private void onKeyInput( int key, int scancode, int action, int mods ) nothrow {
        windowEvents ~= SbEvent(SbKeyEvent( key, scancode, action, mods ));
        platform.pushRawInput( this, RawKeyInput( key, scancode, action, mods ));
    }
    // Input callback: text input (key pressed as unicode codepoint)
    private void onCharInput ( dchar chr ) nothrow {
        windowEvents ~= SbEvent(SbRawCharEvent( chr ));
        platform.pushRawInput( this, RawCharInput( chr ));
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
extern(C) private void windowSizeCallback (GLFWwindow* handle, int width, int height) nothrow {
    handle.getWindow.onWindowSizeChanged( width, height );
}
extern(C) private void windowFramebufferSizeCallback (GLFWwindow* handle, int width, int height) nothrow {
    handle.getWindow.onFrameBufferSizeChanged( width, height );
}
extern(C) private void windowFocusCallback (GLFWwindow* handle, int focused) nothrow {
    handle.getWindow.onInputFocusChanged( focused != 0 );
}
extern(C) private void windowRefreshCallback (GLFWwindow* handle) nothrow {
    handle.getWindow.onWindowNeedsRefresh();
}
extern(C) private void windowKeyInputCallback (GLFWwindow* handle, int key, int scancode, int action, int mods) nothrow {
    handle.getWindow.onKeyInput(key, scancode, action, mods);
}
extern(C) private void windowCharInputCallback (GLFWwindow* handle, uint codepoint) nothrow {
    handle.getWindow.onCharInput( cast(dchar)codepoint );
}
extern(C) private void windowCursorInputCallback (GLFWwindow* handle, double xpos, double ypos) nothrow {
    handle.getWindow.onCursorInput( xpos, ypos );
}
extern(C) private void windowCursorEnterCallback (GLFWwindow* handle, int entered) nothrow {
    handle.getWindow.onCursorFocusChanged( entered != 0 );
}
extern(C) private void windowMouseBtnInputCallback (GLFWwindow* handle, int button, int action, int mods) nothrow {
    handle.getWindow.onMouseButtonInput( button, action, mods );
}
extern(C) private void windowScrollInputCallback (GLFWwindow* handle, double xoffs, double yoffs) nothrow {
    handle.getWindow.onScrollInput( xoffs, yoffs );
}

