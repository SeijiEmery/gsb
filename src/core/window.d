
module gsb.core.window;
import Derelict.glfw3.glfw3;
import gl3n.linalg;

import std.exception;
import std.math;

import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.gamepad;

public __gshared Window g_mainWindow = null;

string formatGlfwKey (int key) {
    switch (key) {
        case GLFW_KEY_UNKNOWN: return "<Unknown Key>";
        case GLFW_KEY_ESCAPE:  return "<Esc>";
        case GLFW_KEY_ENTER:   return "<Enter>";
        case GLFW_KEY_TAB:     return "<Tab>";
        case GLFW_KEY_BACKSPACE: return "<Backspace>";
        case GLFW_KEY_INSERT:    return "<Insert>";
        case GLFW_KEY_DELETE:    return "<Delete>";
        case GLFW_KEY_LEFT: return "<Left Arrow>";
        case GLFW_KEY_RIGHT: return "<Right Arrow>";
        case GLFW_KEY_UP: return "<Up Arrow>";
        case GLFW_KEY_DOWN: return "<Down Arrow>";
        case GLFW_KEY_PAGE_UP: return "<PageUp>";
        case GLFW_KEY_PAGE_DOWN: return "<PageDown>";
        case GLFW_KEY_HOME: return "<Home>";
        case GLFW_KEY_END: return "<End>";
        case GLFW_KEY_LEFT_SHIFT: case GLFW_KEY_RIGHT_SHIFT:
            return "<Shift>";
        case GLFW_KEY_LEFT_CONTROL: case GLFW_KEY_RIGHT_CONTROL:
            return "<Ctrl>";
        case GLFW_KEY_LEFT_ALT: case GLFW_KEY_RIGHT_ALT:
            return "<Alt>";
        case GLFW_KEY_LEFT_SUPER: case GLFW_KEY_RIGHT_SUPER:
            version(OSX) return "<Cmd>";
            else         return "<Meta>";
        case GLFW_KEY_KP_DECIMAL: key = '.'; break;
        default: break;
    }
    if (key >= GLFW_KEY_F1 && key <= GLFW_KEY_F25)
        return format("<F%d>", key - GLFW_KEY_F1 + 1);

    return format("<Key %c>", cast(dchar)key);
}

string formatGlfwModifiers (int mod) {
    string result = "";
    if (mod & GLFW_MOD_SHIFT)
        result = "SHIFT";
    if (mod & GLFW_MOD_CONTROL)
        result.length ? result ~= " | CTRL" : result = "CTRL";
    if (mod & GLFW_MOD_ALT)
        result.length ? result ~= " | ALT" : result = "ALT";
    if (mod & GLFW_MOD_SUPER) {
        version(OSX) result.length ? result ~= " | CMD" : result = "CMD";
        else         result.length ? result ~= " | META" : result = "META";
    }
    return result;
}

string formatGlfwMouseButton (int button) {
    switch (button) {
        case GLFW_MOUSE_BUTTON_LEFT: return "MOUSE_LMB";
        case GLFW_MOUSE_BUTTON_RIGHT: return "MOUSE_RMB";
        case GLFW_MOUSE_BUTTON_MIDDLE: return "MOUSE_MMB";
        default:
            if (button >= 0 && button <= GLFW_MOUSE_BUTTON_LAST)
                return format("MOUSE_BTN_%d", (button+1));
            return format("<INVALID MOUSE BUTTON (%d)>", button);
    }
}


// Wraps GLFWwindow and monitor stuff.
class Window {
private:
    GLFWwindow * m_window = null;
    bool m_hasOwnership = true;
    vec2i m_framebufferSize;
    vec2i m_screenSize;
    vec2 m_scalingFactors;
    GamepadManager!(GLFW_JOYSTICK_LAST+1) gamepadMgr;

public:
    // Public properties:
    @property GLFWwindow* handle () { return m_window; }
    @property vec2i pixelDimensions () { return m_framebufferSize; }
    @property vec2i screenDimensions () { return m_screenSize; }
    @property vec2 screenScale () { 
        assert(!(m_scalingFactors.x.isNaN() || m_scalingFactors.y.isNaN()));
        return m_scalingFactors; 
    }

    // Event signals:
    Signal!(float, float) onScreenSizeChanged;
    Signal!(float, float) onFramebufferSizeChanged;
    Signal!(float, float) onScreenScaleChanged;

    struct KeyPress {
        int key, mods;
    }
    struct MouseButton {
        int button, mods;
    }

    // Keyboard input callbacks
    Signal!(KeyPress) onKeyPressed;
    Signal!(KeyPress) onKeyReleased;
    Signal!(dchar[])   onTextInput;

    // Mouse input callbacks
    Signal!(vec2)  onMouseMoved;
    Signal!(vec2)  onScrollInput;
    Signal!(MouseButton) onMouseButtonPressed;
    Signal!(MouseButton) onMouseButtonReleased;

    // Gamepad input callbacks (implemented in gamepad.d)
    @property ref auto onGamepadDetected () { return gamepadMgr.onDeviceDetected; }
    @property ref auto onGamepadRemoved  () { return gamepadMgr.onDeviceRemoved; }
    @property ref auto onGamepadButtonPressed () { return gamepadMgr.onGamepadButtonPressed; }
    @property ref auto onGamepadButtonReleased () { return gamepadMgr.onGamepadButtonReleased; }
    @property ref auto onGamepadAxesUpdate () { return gamepadMgr.onGamepadAxesUpdate; }

    // State changing methods
    void setTitle (string title) {
        glfwSetWindowTitle(m_window, title.ptr);
    }

    // helper fcn...
    auto recalcScreenScale () {
        m_scalingFactors.x = cast(double)m_framebufferSize.x / cast(double)m_screenSize.x;
        m_scalingFactors.y = cast(double)m_framebufferSize.y / cast(double)m_screenSize.y;
        return m_scalingFactors;
    }

    public void setupDefaultEventLogging () {
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
    }

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
        if (!g_mainWindow)
            g_mainWindow = this;

        glfwSetWindowUserPointer(m_window, cast(void*)this);
        glfwSetWindowSizeCallback(m_window, &windowSizeCallback);
        glfwSetFramebufferSizeCallback(m_window, &windowFramebufferSizeCallback);

        int w, h;
        glfwGetWindowSize(m_window, &w, &h);
        m_screenSize.x = w; m_screenSize.y = h;

        glfwGetFramebufferSize(m_window, &w, &h);
        m_framebufferSize.x = w; m_framebufferSize.y = h;

        recalcScreenScale();

        glfwSetKeyCallback(m_window, &keyCallback);
        glfwSetCharCallback(m_window, &charCallback);
        glfwSetCursorPosCallback(m_window, &mousePosCallback);
        glfwSetMouseButtonCallback(m_window, &mouseButtonCallback);
        glfwSetScrollCallback(m_window, &scrollCallback);
    }
    ~this () {
        if (m_hasOwnership && m_window)
            glfwDestroyWindow(m_window);
        if (g_mainWindow == this)
            g_mainWindow = null;
    }

private:
    private static Window getPtr (GLFWwindow* window) nothrow {
        return cast(Window)glfwGetWindowUserPointer(window);
    }
    private void emit (string signal, Args...)(Args args) {
        assumeWontThrow(mixin(signal).emit(args));
    }

    extern (C) static void windowSizeCallback (GLFWwindow * window, int width, int height) nothrow {
        getPtr(window).notifyWindowSizeChanged(width, height);
    }
    extern (C) static void windowFramebufferSizeCallback (GLFWwindow * window, int width, int height) nothrow {
        getPtr(window).notifyFramebufferSizeChanged(width, height);
    }
    private void notifyWindowSizeChanged (int width, int height) nothrow {
        //log.write("Window size changed to %d, %d", width, height);
        m_screenSize.x = width; m_screenSize.y = height;
    }
    private void notifyFramebufferSizeChanged (int width, int height) nothrow {
        //log.write("Framebuffer size changed to %d, %d", width, height);
        m_framebufferSize.x = width; m_framebufferSize.y = height;
    }

    extern (C) static void keyCallback (GLFWwindow* window, int key, int scancode, int action, int mods) nothrow {
        final switch (action) {
            case GLFW_PRESS:   getPtr(window).emit!"onKeyPressed"(KeyPress(key, mods)); break;
            case GLFW_RELEASE: getPtr(window).emit!"onKeyReleased"(KeyPress(key, mods)); break;
            case GLFW_REPEAT: break;
        }
    }

    private dchar[] m_accumulatedText;
    extern (C) static void charCallback (GLFWwindow* window, uint codepoint) nothrow {
        getPtr(window).m_accumulatedText ~= codepoint;
    }
    extern (C) static void mousePosCallback (GLFWwindow* window, double xpos, double ypos) nothrow {
        getPtr(window).emit!"onMouseMoved"(vec2(xpos, ypos));
    }
    extern (C) static void mouseButtonCallback (GLFWwindow* window, int button, int action, int mods) nothrow {
        final switch (action) {
            case GLFW_PRESS:  getPtr(window).emit!"onMouseButtonPressed"(MouseButton(button, mods)); break;
            case GLFW_RELEASE: getPtr(window).emit!"onMouseButtonReleased"(MouseButton(button, mods)); break;
            case GLFW_REPEAT: break;
        }
    }
    extern (C) static void scrollCallback (GLFWwindow* window, double xdelta, double ydelta) nothrow {
        getPtr(window).emit!"onScrollInput"(vec2(xdelta, ydelta));
    }

public:
    private immutable uint UPDATE_FREQUENCY = 60; // update expensive stuff every 60 frames, and regular events every frame
    private uint frameCount = UPDATE_FREQUENCY;

    // Only call this from the main thread! Does additional event polling and processing not covered by glfwPollEvents
    // for stuff that is (mostly) connected to this window instance.
    void runEventUpdates () {
        if (frameCount++ >= UPDATE_FREQUENCY) {
            frameCount = 0;
            gamepadMgr.updateDeviceList();
        }
        gamepadMgr.update();
    }
}




















