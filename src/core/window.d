
module gsb.core.window;
import Derelict.glfw3.glfw3;
import gl3n.linalg;

import std.stdio;
import std.exception;

public __gshared Window g_mainWindow = null;

// Wraps GLFWwindow and monitor stuff.
class Window {
    GLFWwindow * m_window;
    bool m_hasOwnership = true;
    private vec2i m_framebufferSize;
    private vec2i m_screenSize;

    @property auto pixelDimensions () { return m_framebufferSize; }
    @property auto screenDimensions () { return m_screenSize; }
    @property double screenScalingFactor () { return 1.0; }
    @property auto handle () { return m_window; }

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

        Window * self = &this;
        glfwSetWindowUserPointer(m_window, cast(void*)this);
        glfwSetWindowSizeCallback(m_window, &windowSizeCallback);
        glfwSetFramebufferSizeCallback(m_window, &windowFramebufferSizeCallback);

        int w, h;
        glfwGetWindowSize(m_window, &w, &h);
        m_screenSize.x = w; m_screenSize.y = h;

        glfwGetFramebufferSize(m_window, &w, &h);
        m_framebufferSize.x = w; m_framebufferSize.y = h;
    }
    ~this () {
        if (m_hasOwnership && m_window)
            glfwDestroyWindow(m_window);
        if (g_mainWindow == this)
            g_mainWindow = null;
    }

    void setTitle (string title) {
        glfwSetWindowTitle(m_window, title.ptr);
    }

    extern (C) static void windowSizeCallback (GLFWwindow * window, int width, int height) nothrow {
        auto ptr = cast(Window)glfwGetWindowUserPointer(window);
        if (!ptr) {
            assumeWontThrow(writeln("null user data pointer!"));
        } else {
            ptr.onWindowSizeChanged(width, height);
        }
    }
    extern (C) static void windowFramebufferSizeCallback (GLFWwindow * window, int width, int height) nothrow {
        Window ptr = cast(Window)glfwGetWindowUserPointer(window);
        if (!ptr) {
            assumeWontThrow(writeln("null user data pointer!"));
        } else {
            ptr.onFramebufferSizeChanged(width, height);
        }
    }

    void onWindowSizeChanged (int width, int height) nothrow {
        m_screenSize.x = width; m_screenSize.y = height;
    }
    void onFramebufferSizeChanged (int width, int height) nothrow {
        m_framebufferSize.x = width; m_framebufferSize.y = height;
    }
}