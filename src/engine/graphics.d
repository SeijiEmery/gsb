module gsb.engine.graphics;

struct GraphicsThreadManager {

    // should be called exactly once by engine and on the main thread,
    // and before runGraphicsThread is called.
    void preInitGL () {
        assert(!mainWindow, "Invalid call to preInitGL()");

        // preload gl + glfw
        DerelictGLFW3.load();
        DerelictGL3.load();

        bool success = glfwInit();
        enforce(success, format("Failed to initialize glfw"));

        // create window
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, true);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

        g_mainWindow = mainWindow = new Window (
            glfwCreateWindow(800, 600, "GL Sandbox", null, null), false
        );
        enforce(mainWindow, format("Failed to create glfw window"));
    }

    // should be called exactly once by the engine, on the main thread,
    // and after preInitGL is called.
    void runGraphicsThread (ref ThreadManager.GThreadContext threadCtx) {
        try {
            threadCtx.running = true;

            // setup log, thread stats, and write message
            log = g_graphicsLog = new Log("graphics-thread");
            log.write("Launched graphics thread");
            setupThreadStats("graphics-thread");
            g_graphicsFrameTime.init();

            // finish gl init
            glfwMakeContextCurrent(mainWindow.handle);
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
            threadCtx.notifyTerminatedWithError(e);
        }
    }

    // should be called only from graphics thread.
    private void runGraphicsMainLoop (ref ThreadManager.GThreadContext threadCtx) {
        while (threadCtx.running) {
            recieve(
                (ClientMessage.KillRequest _) { threadCtx.running = false; },
                (ClientMessage.NextFrame frameInfo) {
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
                        threadStats.timedCall("send threadSync message", {
                            send(GraphicsMessage.ReadyForNextFrame(frameInfo));
                        });
                    });
                    threadStats.timedCall("swapBuffers", {
                        glfwSwapBuffers(mainWindow.handle);
                    });
                },
                (Variant v) { log.write("Unhandled event: %s", v); } 
            );
        }
        threadCtx.notifyThreadTermOk();
    }
}
