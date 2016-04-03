
module gsb.core.window;
import derelict.glfw3.glfw3;
import gl3n.linalg;

import std.exception;
import std.math;

import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.gamepad;
import gsb.core.uievents;
import gsb.core.uimanager;

public __gshared Window g_mainWindow = null;

private void setMainWindow (Window window) {
    assert(!g_mainWindow);
    g_mainWindow = window;
    UIComponentManager.registerEventSource(window.m_eventCollector);
}
private void unsetMainWindow (Window window) {
    assert(g_mainWindow == window);
    g_mainWindow = null;
    UIComponentManager.unregisterEventSource(window.m_eventCollector);
}



// Wraps GLFWwindow and monitor stuff.
class Window {
private:
    GLFWwindow * m_window = null;
    bool m_hasOwnership = true;
    vec2i m_framebufferSize;  // window size in scaled pixels   (2.0x screen size if retina)
    vec2i m_screenSize;       // window size in unscaled pixels (0.5x framebuffer size if retina)
    vec2  m_screenScale;      // screen scaling factor -- either 1.0 (standard / old monitors), or 2.0 (retina)
    EventCollector m_eventCollector;
    bool hasManuallySetScreenScale = false;

public:
    @property GLFWwindow* handle () { return m_window; }

    void setScreenScale (vec2 scale) {
        hasManuallySetScreenScale = true;

        if (scale.x == 0) scale.x = 1;
        if (scale.y == 0) scale.y = 1;
        m_screenScale = scale;

        auto screenSize = vec2i(
            cast(int)(m_framebufferSize.x / scale.x),
            cast(int)(m_framebufferSize.y / scale.y));

        updateScreenScale(screenSize, m_framebufferSize);
        assert(scale == m_screenScale);
    }
    void clearScreenScale () {
        hasManuallySetScreenScale = false;
        updateScreenScale(m_screenSize, m_framebufferSize);
    }

    @property auto pixelDimensions () { return m_framebufferSize; }
    @property auto screenDimensions () { return m_screenSize; }
    @property auto screenScale () { return m_screenScale; }

    @property mat4 screenSpaceTransform (bool transposed = true) {
        auto inv_scale_x = +1.0 / g_mainWindow.screenDimensions.x * 2.0;
        auto inv_scale_y = -1.0 / g_mainWindow.screenDimensions.y * 2.0;
        auto matrix = mat4.identity()
            .scale(inv_scale_x, inv_scale_y, 1.0)
            .translate(-1.0, 1.0, 0.0);
        if (transposed)
            matrix.transpose();
        return matrix;
    }

    // Event signals:
    Signal!(float, float) onScreenSizeChanged;
    Signal!(float, float) onFramebufferSizeChanged;
    Signal!(float, float) onScreenScaleChanged;

    // State changing methods
    void setTitle (string title) {
        glfwSetWindowTitle(m_window, title.ptr);
    }

    /+public void setupDefaultEventLogging () {
        onScreenScaleChanged.connect((float x, float y) {
            log.write("WindowEvent: Screen scale changed: %0.2f, %0.2f", x, y);
        });
        onFramebufferSizeChanged.connect((float x, float y) {
            log.write("WindowEvent: Framebuffer size set to %0.2f, %0.2f", x, y);
        });
        onScreenSizeChanged.connect((float x, float y) {
            log.write("WindowEvent: Window size set to %0.2f, %0.2f", x, y);
        });
        onKeyPressed.connect((KeyPress evt) {
            log.write(evt.mods ?
                format("KeyEvent: %s pressed (modifiers %s)", formatGlfwKey(evt.key), formatGlfwModifiers(evt.mods)) :
                format("KeyEvent: %s pressed", formatGlfwKey(evt.key)));
        });      
        onKeyReleased.connect((KeyPress evt) {
            log.write(evt.mods ?
                format("KeyEvent: %s released (modifiers %s)", formatGlfwKey(evt.key), formatGlfwModifiers(evt.mods)) :
                format("KeyEvent: %s released", formatGlfwKey(evt.key)));
        });
        onTextInput.connect((dchar[] text) {
            log.write("TextEvent: \"%s\"", text);
        });
        onMouseMoved.connect((vec2 pos) {
            log.write("MouseEvent: pos %0.2f, %0.2f", pos.x, pos.y);
        });
        onScrollInput.connect((vec2 scroll) {
            log.write("ScrollEvent: %0.2f, %0.2f", scroll.x, scroll.y);
        });
        onMouseButtonPressed.connect((MouseButton evt) {
            try {
            log.write(evt.mods ?
                format("MouseEvent: %s pressed (modifiers %s)", formatGlfwMouseButton(evt.button), formatGlfwModifiers(evt.mods)) :
                format("MosueEvent: %s pressed", formatGlfwMouseButton(evt.button)));
            } catch (Throwable e) {
                log.write("Error! %s", e);
            }
        });
        onMouseButtonReleased.connect((MouseButton evt) {
            log.write(evt.mods ?
                format("MouseEvent: %s released (modifiers %s)", formatGlfwMouseButton(evt.button), formatGlfwModifiers(evt.mods)) :
                format("MosueEvent: %s released", formatGlfwMouseButton(evt.button)));
        });

        onGamepadDetected.connect((const(GamepadState)* gamepad) {
            log.write("Connected %s gamepad '%s' (slot %d, %d axes, %d buttons)",
                gamepad.profile, gamepad.name, gamepad.id, gamepad.naxes, gamepad.nbuttons);
        });
        onGamepadRemoved.connect((const(GamepadState)* gamepad) {
            log.write("Disconnected %s gamepad '%s' (slot %d, %d axes, %d buttons)",
                gamepad.profile, gamepad.name, gamepad.id, gamepad.naxes, gamepad.nbuttons);
        });
        onGamepadButtonPressed.connect((GamepadButton btn) {
            log.write("Gamepad button %s pressed", to!string(btn));
        });
        onGamepadButtonReleased.connect((GamepadButton btn) {
            log.write("Gamepad button %s released", to!string(btn));
        });
        onGamepadAxesUpdate.connect((float[] axes) {
            string[NUM_GAMEPAD_AXES] results; uint n = 0;
            foreach (m; __traits(allMembers, GamepadAxis)) {
                auto v = axes[mixin("GamepadAxis."~m)];
                if (v != 0) {
                    results[n++] = format("%s %0.2f", m, v);
                }
            }
            if (n > 0) {
                log.write("Gamepad input: %s", results[0..n].join(", "));
            }
        });
    }+/

    // Basic ctor. In the future, would like to have this driven by a config file instead.
    this (int width, int height) {
        m_window = glfwCreateWindow(width, height, "GLSandbox", glfwGetPrimaryMonitor(), null);
        if (!m_window)
            throw new Error("Failed to create glfw window");
        this();   
    }
    this (GLFWwindow * existing, bool hasOwnership = true) {
        m_window = existing;
        m_hasOwnership = hasOwnership;
        this();
    }
    private this () {
        glfwSetWindowUserPointer(m_window, cast(void*)this);
        m_eventCollector = new EventCollector(m_window);

        if (!g_mainWindow || g_mainWindow == this)
            setMainWindow(this);
    }
    ~this () {
        if (m_hasOwnership && m_window)
            glfwDestroyWindow(m_window);
        if (g_mainWindow == this) {
            g_mainWindow = null;
        }
    }

    private static EventCollector getCollector (GLFWwindow* window) nothrow {
        return (cast(Window)glfwGetWindowUserPointer(window)).m_eventCollector;
    }

    private void updateScreenScale (vec2i screenSize, vec2i framebufferSize) {
        log.write("Updating screen scale");

        vec2 newScale;
            double scale_x = cast(double)framebufferSize.x / cast(double)screenSize.x;
            double scale_y = cast(double)framebufferSize.y / cast(double)screenSize.y;

            // Sanity check screen scale; we only support two scales: 1.0 (standard), 2.0 (retina)
            assert(approxEqual(scale_x, 1.0) || approxEqual(scale_x, 2.0));
            assert(approxEqual(scale_y, 1.0) || approxEqual(scale_y, 2.0));

            newScale = vec2(round(scale_x), round(scale_y));

        bool sizeChanged = screenSize != m_screenSize;
        bool scaleChanged = newScale  != m_screenScale;
        bool fbChanged    = framebufferSize != m_framebufferSize;

        if (!hasManuallySetScreenScale) {
            m_screenScale = vec2(round(scale_x), round(scale_y));
            m_screenSize  = screenSize;
        } else {
            m_screenSize = vec2i(
                cast(int)(cast(double)framebufferSize.x / m_screenScale.x),
                cast(int)(cast(double)framebufferSize.y / m_screenScale.y));
        }
        m_framebufferSize = framebufferSize;

        // Still want our old code to work, and some stuff needs to operate outside of the UIEvent system
        if (scaleChanged) onScreenScaleChanged.emit(cast(float)newScale.x, cast(float)newScale.y);
        if (sizeChanged) onScreenSizeChanged.emit(cast(float)screenSize.x, cast(float)screenSize.y);
        if (fbChanged) onFramebufferSizeChanged.emit(cast(float)framebufferSize.x, cast(float)framebufferSize.y);

        log.write("changed: %d, %d, %d", scaleChanged, sizeChanged, fbChanged);
    }

    class EventCollector : IEventCollector {
    private:
        UIEvent[] events, nextFrameEvents;

        // retained / new state
        vec2i newScreenSize, newFramebufferSize;
        vec2  lastMousePos, newMousePos;

        dchar[] text;

    public:
        protected this (GLFWwindow* window) {
            glfwSetWindowSizeCallback(window,      &screenSizeCallback);
            glfwSetFramebufferSizeCallback(window, &framebufferSizeCallback);

            int w, h;
            glfwGetWindowSize(window, &w, &h);      newScreenSize = vec2i(w, h);
            glfwGetFramebufferSize(window, &w, &h); newFramebufferSize = vec2i(w, h);
            updateScreenScale(newScreenSize, newFramebufferSize);

            glfwSetKeyCallback(window, &keyCallback);
            glfwSetCharCallback(window, &textCallback);
            glfwSetCursorPosCallback(window, &mousePosCallback);
            glfwSetMouseButtonCallback(window, &mouseButtonCallback);
            glfwSetScrollCallback(window, &scrollCallback);
        }

        // Called once per frame by the ui event manager. Returns our collected events, and updates the
        // state held by the window, mouse, and keyboard objects.
        override UIEvent[] getEvents () {
            import std.algorithm.mutation: swap;
            synchronized {
                swap(events, nextFrameEvents);
                events.length = 0;

                // check if window size or scale changed
                if (m_screenSize != newScreenSize || m_framebufferSize != newFramebufferSize) {
                    auto lastScale = m_screenScale;
                    auto lastSize  = m_screenSize;

                    updateScreenScale(newScreenSize, newFramebufferSize);
                    nextFrameEvents ~= WindowResizeEvent.create(
                        m_screenSize, lastSize,
                        m_screenScale, lastScale
                    );

                    newScreenSize = m_screenSize;
                    newFramebufferSize = m_framebufferSize;
                }

                // check + update mouse
                if (lastMousePos != newMousePos) {
                    nextFrameEvents ~= MouseMoveEvent.create(newMousePos, lastMousePos);
                    lastMousePos = newMousePos;
                }

                if (text.length)
                    nextFrameEvents ~= TextEvent.create(text);
                text.length = 0;
            }
            return nextFrameEvents;
        }

    private:
        extern (C) static void screenSizeCallback (GLFWwindow * window, int width, int height) nothrow {
            getCollector(window).windowSizeChanged(width, height);
        }
        void windowSizeChanged (int width, int height) nothrow {
            synchronized { newScreenSize = vec2i(width, height); }
        }

        extern (C) static void framebufferSizeCallback (GLFWwindow * window, int width, int height) nothrow {
            getCollector(window).framebufferSizeChanged(width, height);
        }
        void framebufferSizeChanged (int width, int height) nothrow {
            synchronized { newFramebufferSize = vec2i(width, height); }
        }

        extern (C) static void keyCallback (GLFWwindow* window, int key, int scancode, int action, int mods) nothrow {
            getCollector(window).keyPressed(key, scancode, action, mods);
        }
        void keyPressed (int key, int scancode, int action, int mods) nothrow {
            synchronized {
                events ~= KeyboardEvent.createFromGlfwValues(key, scancode, action, mods);
            }
        }

        extern (C) static void textCallback (GLFWwindow* window, uint codepoint) nothrow {
            getCollector(window).textInput(cast(dchar)codepoint);
        }
        void textInput (dchar chr) nothrow {
            if (chr < 20)
                return;

            synchronized { text ~= chr; }
        }

        extern (C) static void mousePosCallback (GLFWwindow* window, double xpos, double ypos) nothrow {
            getCollector(window).mouseMoved(xpos, ypos);
        }
        void mouseMoved (double x, double y) nothrow {
            synchronized { newMousePos = vec2(x, y); }
        }

        extern (C) static void mouseButtonCallback (GLFWwindow* window, int button, int action, int mods) nothrow {
            getCollector(window).mouseButton(button, action, mods);
        }
        void mouseButton (int button, int action, int mods) nothrow {
            synchronized { 
                events ~= MouseButtonEvent.createFromGlfwValues(button, action, mods);
            }
        }

        extern (C) static void scrollCallback (GLFWwindow* window, double xdelta, double ydelta) nothrow {
            getCollector(window).scroll(xdelta, ydelta);
        }
        void scroll (double x, double y) nothrow {
            synchronized { events ~= ScrollEvent.create(vec2(x, y)); }
        }
    }
}




















