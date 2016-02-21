
module gsb.core.window;
import Derelict.glfw3.glfw3;
import gl3n.linalg;

import std.exception;
import std.math;

import gsb.core.log;

public __gshared Window g_mainWindow = null;

// Wraps GLFWwindow and monitor stuff.
class Window {
private:
    GLFWwindow * m_window = null;
    bool m_hasOwnership = true;
    vec2i m_framebufferSize;
    vec2i m_screenSize;
    vec2 m_scalingFactors;

public:
    void setTitle (string title) {
        glfwSetWindowTitle(m_window, title.ptr);
    }

    @property auto handle () { return m_window; }
    @property auto pixelDimensions () { return m_framebufferSize; }
    @property auto screenDimensions () { return m_screenSize; }
    @property auto screenScale () { 
        assert(!(m_scalingFactors.x.isNaN() || m_scalingFactors.y.isNaN()));
        return m_scalingFactors; 
    }

    auto recalcScreenScale () {
        m_scalingFactors.x = cast(double)m_framebufferSize.x / cast(double)m_screenSize.x;
        m_scalingFactors.y = cast(double)m_framebufferSize.y / cast(double)m_screenSize.y;
        return m_scalingFactors;
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
    }
    ~this () {
        if (m_hasOwnership && m_window)
            glfwDestroyWindow(m_window);
        if (g_mainWindow == this)
            g_mainWindow = null;
    }

private:
    extern (C) static void windowSizeCallback (GLFWwindow * window, int width, int height) nothrow {
        auto ptr = cast(Window)glfwGetWindowUserPointer(window);
        if (!ptr) {
            assumeWontThrow(log.write("null user data pointer!"));
        } else {
            assumeWontThrow(ptr.notifyWindowSizeChanged(width, height));
        }
    }
    extern (C) static void windowFramebufferSizeCallback (GLFWwindow * window, int width, int height) nothrow {
        Window ptr = cast(Window)glfwGetWindowUserPointer(window);
        if (!ptr) {
            assumeWontThrow(log.write("null user data pointer!"));
        } else {
            assumeWontThrow(ptr.notifyFramebufferSizeChanged(width, height));
        }
    }

    private void notifyWindowSizeChanged (int width, int height) {
        //log.write("Window size changed to %d, %d", width, height);
        m_screenSize.x = width; m_screenSize.y = height;
    }
    private void notifyFramebufferSizeChanged (int width, int height) {
        //log.write("Framebuffer size changed to %d, %d", width, height);
        m_framebufferSize.x = width; m_framebufferSize.y = height;
    }
}