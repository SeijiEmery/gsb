module gsb.engine.graphics_thread;
import gsb.engine.engineconfig;
import gsb.engine.threads;
import gsb.engine.engine;

import gsb.coregl;
import derelict.opengl3.gl3;
import derelict.glfw3.glfw3;

import gsb.gl.graphicsmodule;
import gsb.core.slate2d;
import gsb.core.text;

import gsb.core.window;
import gsb.core.uimanager;
import gsb.core.stats;
import gsb.core.log;

import std.exception: enforce;
import std.concurrency;
import std.format;


private auto todstr(inout(char)* cstr) {
    import core.stdc.string: strlen;
    return cstr ? cstr[0 .. strlen(cstr)] : "";
}

class GraphicsThread : EngineThread {
    public Engine engine;
    private GlSyncPoint.GSP glSync;

    this (Engine engine, GlSyncPoint.GSP glSync) {
        super(EngineThreadId.GraphicsThread);

        this.engine = engine;
        this.glSync = glSync;
    }

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

    override void init () {
        // setup log, thread stats, and write message
        log = g_graphicsLog = new Log("graphics-thread");
        log.write("Launched graphics thread");
        setupThreadStats("graphics-thread");

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
    }
    override void runNextTask () {
        glSync.waitNextFrame();
        static if (SHOW_MT_GL_SYNC_LOGGING)
            log.write("GTHREAD FRAME BEGIN");
        threadStats.timedCall("frame", {
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
        if (running) {
            static if (SHOW_MT_GL_SYNC_LOGGING)
                log.write("GTHREAD FRAME END");
            threadStats.timedCall("swapBuffers", {
                glSync.notifyFrameComplete();
                glfwSwapBuffers(engine.mainWindow.handle);
            });
        }
    }
    override void atExit () {
        log.write("Exiting graphics thread");
    }
}
