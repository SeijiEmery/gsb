
module gsb.core.window;
import Derelict.glfw3.glfw3;
import gl3n.linalg;

import std.exception;
import std.math;

import gsb.core.log;

public __gshared Window g_mainWindow = null;

// Wraps GLFWwindow and monitor stuff.
class Window {
    GLFWwindow * m_window;
    bool m_hasOwnership = true;
    private vec2i m_framebufferSize;
    private vec2i m_screenSize;
    private vec2 m_cachedScalingFactor;
    bool m_dirtyScalingFactor = true;
    bool m_framebufferSizeChanged = false;
    bool m_screenSizeChanged = false;

    @property auto pixelDimensions () { return m_framebufferSize; }
    @property auto screenDimensions () { return m_screenSize; }
    @property auto handle () { return m_window; }

    @property vec2 screenScalingFactor () {
        if (m_dirtyScalingFactor) {
            m_dirtyScalingFactor = false;
            m_cachedScalingFactor.x = cast(double)m_framebufferSize.x / cast(double)m_screenSize.x;
            m_cachedScalingFactor.y = cast(double)m_framebufferSize.y / cast(double)m_screenSize.y;
            log.write("Set screen scaling factor to %0.2f, %0.2f", m_cachedScalingFactor.x, m_cachedScalingFactor.y);
        }
        return m_cachedScalingFactor;
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
        //notifyScalingFactorChanged();
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

    void notifyWindowSizeChanged (int width, int height) {
        log.write("Window size changed to %d, %d", width, height);
        m_screenSize.x = width; m_screenSize.y = height;
        m_dirtyScalingFactor = true;
        //writeln("Screen size changed");
        //if (m_framebufferSizeChanged) {
        //    m_framebufferSizeChanged = false;
        //    notifyScalingFactorChanged();
        //} else {
        //    m_screenSizeChanged = true;
        //}
    }
    void notifyFramebufferSizeChanged (int width, int height) {
        log.write("Framebuffer size changed to %d, %d", width, height);
        m_framebufferSize.x = width; m_framebufferSize.y = height;
        m_dirtyScalingFactor = true;

        //writeln("framebuffer size changed");
        //if (m_screenSizeChanged) {
        //    m_screenSizeChanged = false;
        //    notifyScalingFactorChanged();
        //} else {
        //    m_framebufferSizeChanged = true;
        //}
    }

    //void notifyScalingFactorChanged () {
    //    auto sx = cast(double)m_framebufferSize.x / cast(double)m_screenSize.x;
    //    auto sy = cast(double)m_framebufferSize.y / cast(double)m_screenSize.y;

    //    auto epsilon = 0.1;
    //    if (abs(sx - m_cachedScalingFactor.x) > epsilon ||
    //        abs(sy - m_cachedScalingFactor.y) > epsilon)
    //    {
    //        writefln("Set screen scaling factor to %0.2f, %0.2f", sx, sy);
    //        m_cachedScalingFactor.x = sx;
    //        m_cachedScalingFactor.y = sy;
    //    } else {
    //        writefln("Did not change screen scaling factor (%0.2f -> %0.2f, %0.2f -> %0.2f)",
    //            m_cachedScalingFactor.x, sx, m_cachedScalingFactor.y, sy);
    //    }

    //    //foreach (cb; scalingFactorListeners) {
    //    //    writeln("Calling listener...");
    //    //    cb();
    //    //}
    //}

}