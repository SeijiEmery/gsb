module gsb.engine.graphics_thread;
import gsb.engine.engine;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;

import gsb.coregl;             // this is a mess... xD
import gsb.gl.graphicsmodule;
import gsb.gl.algorithms;
import gsb.gl.debugrenderer;
import gsb.text.textrenderer;

import gsb.core.window;
import gsb.core.frametime;
import gsb.core.uimanager;
import gsb.core.stats;
import gsb.core.log;

import std.exception: enforce;
import std.concurrency;
import std.format;
import core.thread;


private auto todstr(inout(char)* cstr) {
    import core.stdc.string: strlen;
    return cstr ? cstr[0 .. strlen(cstr)] : "";
}

class GraphicsThread : Thread {
    public Engine engine;
    private GlSyncPoint.GSP glSync;
    private bool keepRunning = true;

    this (Engine engine, GlSyncPoint.GSP glSync) {
        this.engine = engine;
        this.glSync = glSync;
        super(&runGraphicsThread);
    }
    void kill () { keepRunning = false; }
    void awaitDeath () {}

    // should be called exactly once by engine and on the main thread,
    // and before runGraphicsThread is called.
    void preInitGL () {
        assert(!engine.mainWindow, "Invalid call to preInitGL()");

        // preload gl + glfw
        DerelictGLFW3.load();
        DerelictGL3.load();

        auto success = glfwInit();
        enforce(success, format("Failed to initialize glfw"));

        // create window
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, true);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

        g_mainWindow = engine.mainWindow = new Window (
            glfwCreateWindow(800, 600, "GL Sandbox", null, null), false
        );
        enforce(engine.mainWindow, format("Failed to create glfw window"));
    }

    // should be called exactly once by the engine and on the graphics thread,
    // after preInitGL is called.
    private void runGraphicsThread () {
        try {
            // setup log, thread stats, and write message
            log = g_graphicsLog = new Log("graphics-thread");
            log.write("Launched graphics thread");
            setupThreadStats("graphics-thread");
            g_graphicsFrameTime.init();

            // finish gl init
            glfwMakeContextCurrent(engine.mainWindow.handle);
            glfwSwapInterval(1);
            DerelictGL3.reload();

            log.write("Running GLSandbox");
            log.write("Renderer: %s", todstr(glGetString(GL_RENDERER)));
            log.write("Opengl version: %s", todstr(glGetString(GL_VERSION)));

            // setup initial gl state
            glState.enableDepthTest(true, GL_LESS);
            glState.enableTransparency(true);

            // and enter gthread main loop
            runGraphicsMainLoop();

        } catch (Throwable e) {
            log.write("Thread terminated: %s", e);
        }
    }

    // should be called only from graphics thread.
    private void runGraphicsMainLoop () {
        while (keepRunning) {
            glSync.waitNextFrame();
            threadStats.timedCall("frame", {
                g_graphicsFrameTime.updateFromRespectiveThread();

                glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
                threadStats.timedCall("GraphicsComponents.updateAndRender", {
                    GraphicsComponentManager.updateFromGraphicsThread();
                });
                threadStats.timedCall("DebugRenderer.render", {
                    DebugRenderer.renderFromGraphicsThread();
                });
                threadStats.timedCall("TextRenderer.renderFragments", {
                    TextRenderer.instance.renderFragments();
                });
                DynamicRenderer.signalFrameEnd();
            });
            threadStats.timedCall("swapBuffers", {
                glSync.notifyFrameComplete();
                glfwSwapBuffers(engine.mainWindow.handle);
            });
        }
    }
}
