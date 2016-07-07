module sb.app.impl.app_impl;
import sb.app;
import sb.platform;
import sb.threading;
import sb.fs;
import sb.gl;


class SbApplication : IApplication {
    IThreadContext       threads;
    IThreadEventListener threadListener;
    bool running = false;

    this (SbAppConfig config) {
        try {
            initPlatform (config);
            initThreads  (config);
            initFs       (config);
            // etc...
        } catch (Throwable e) {
            doTeardown();
            throw e;
        }
    }
    private final void doTeardown () {
        try {
            if (platform)
                platform.teardown();
        } catch (Throwable e) {
            writefln("in teardown: %s", e);
        }
    }
    private final void initPlatform (SbAppConfig config) {
        // Create + init platform
        SbPlatformConfig platformConfig = {
            .glVersion = config.glVersion
        };
        platform = sbCreatePlatformContext(platformConfig);
        platform.initMain();
        graphicsContext = platform.createGraphicsContext();
    }
    private final void initThreads (SbAppConfig config) {
        // Create + spawn threads
        threadListener = new ThreadEventHandler();
        threads        = sbCreateThreadContext(threadEventListener);
        threads.bindWorker(SbThreadId.MAIN_THREAD,     mtWorker = new MainThreadWorker());
        threads.bindWorker(SbThreadId.GRAPHICS_THREAD, gtWorker = new GraphicsThreadWorker());
        foreach (i; 0 .. config.numWorkerThreads) {
            threads.bindWorker(cast(SbThreadId)(SbThreadId.WORK_THREAD_0 + i), 
                backgroundWorkers[i] = new BackgroundWorker());
        }
        threads.setFrameWaitPolicy(SbThreadMask.MAIN_THREAD, true);
        threads.setFrameWaitPolicy(SbThreadMask.GRAPHICS_THREAD, true);
    }
    private final void initFs (SbAppConfig config) {
        // Setup fs + begin scanning files
        fs = sbCreateFileContext();
        fs.setPathVar("PROJECT_DIR", config.projectDir);
        fs.setPathVar("APPDATA_DIR", config.appdataDir);
        fs.setPathVar("CACHE_DIR", "${APPDATA_DIR}/cache");

        fs.addResourcePath(SbResourceType.FRAGMENT_SHADER_SRC, "${PROJECT_DIR}/shaders");
        fs.addResourcePath(SbResourceType.VERTEX_SHADER_SRC,   "${PROJECT_DIR}/shaders");
        fs.addResourcePath(SbResourceType.GEOM_SHADER_SRC,     "${PROJECT_DIR}/shaders");
        fs.addResourcePath(SbResourceType.ASSETS_DIR,          "${PROJECT_DIR}/assets");

        fs.addResourcePath(SbResourceType.D_MODULE_SRC,   "${PROJECT_DIR}/modules/src");
        fs.addResourcePath(SbResourceType.D_MODULE_BUILD, "${CACHE_DIR}/build/d/");
        fs.addResourcePath(SbResourceType.D_MODULE_LIB,   "${CACHE_DIR}/lib/d/");

        fs.setResourceExt(SbResourceType.FRAGMENT_SHADER_SRC, "*.fs");
        fs.setResourceExt(SbResourceType.VERTEX_SHADER_SRC, "*.vs");
        fs.setResourceExt(SbResourceType.GEOM_SHADER_SRC, "*.gs");
        fs.setResourceExt(SbResourceType.TEXTURE_ASSET, "*.(jpg|jpeg|png)");
        fs.setResourceExt(SbResourceType.OBJ_ASSET,     "*.obj");
        fs.setResourceExt(SbResourceType.OBJ_MTL_ASSET, "*.mtl");

        fs.setResourceExt(SbResourceType.D_MODULE_SRC,   "*.d");
        fs.setResourceExt(SbResourceType.D_MODULE_BUILD, "*.o");
        fs.setResourceExt(SbResourceType.D_MODULE_LIB,   "*.so");

        fs.setupScanInterval(dur!"seconds"(3), threads);
    }
    // ...

    void run () {
        enforce(!running);
        running = true;

        // Everything setup, so we can just call this: (transfers control to mtWorker)
        threads.enterThread(SbThreadId.MAIN_THREAD);
    }

    private class ThreadEventHandler : IThreadEventListener {
        void onThreadStarted (IThreadContext _, SbThreadId threadId) {
            log.write("Thread started: %s", threadId);
        }
        void onThreadRunning (IThreadContext _, SbThreadId threadId) {
            log.write("Thread running: %s", threadId);
        }
        void onThreadKilled (IThreadContext _, SbThreadId threadId) {
            log.write("Thread killed: %s", threadId);
        }
        void onThreadError (IThreadContext context, SbThreadId threadId, Throwable err) {
            log.write("Thread %s terminated with error: %s", threadId, err);
            context.killAllThreads();
        }
        void onThreadWorkerReplaced (IThreadContext _, SbThreadId threadId, IThreadWorker existing, IThreadWorker replacement) {
            log.write("Warning: thread %s worker replaced!", threadId);
        }
        void onFailedToCreateThread (IThreadContext context, SbThreadId threadId, SbThreadingException err) {
            log.write("Failed to create thread! (%s): %s", threadId, err);
            context.killAllThreads();
        }
        void onUnresponsiveFrame (IThreadContext _, SbThreadId threadId, double duration) {
            log.write("WARNING -- unresponsive frame! (%s, %s seconds)", threadId, duration);
        }
        void onUnresponsiveWorkUnit (IThreadContext _, SbThreadId threadId, double duration) {
            log.write("WARNING -- unresponsive work item! (%s, %s seconds)", threadId, duration);
        }
    }
    private class MainThreadWorker : IThreadWorker {
        void onThreadStart (SbThreadId threadId) {
            assert(threadId == SbThreadId.MAIN_THREAD);

            // Load modules + schedule first frame...
        }
        void onThreadEnd () {}
        bool doThreadWork () {
            // run modules one by one, then call signalFrameDone...?
        }
        void onThreadNextFrame () {
            
        }
    }
    private class BackgroundWorker : IThreadWorker {
        void onThreadStart (SbThreadId threadId) {
            this.threadId = threadId;
        }
        void onThreadEnd () {}
        bool doThreadWork () {
            threads.signalFrameDone(threadId);
            return false;
        }
        void onThreadNextFrame () {}
    }
    private class GraphicsThreadWorker : IThreadWorker {
        bool workDone = false;
        void onThreadStart (SbThreadId threadId) {
            assert(threadId == SbThreadId.GRAPHICS_THREAD);

            // Finish loading GL on graphics thread
            graphicsContext.initGL();
        }
        void onThreadEnd () {}
        bool doThreadWork () {
            if (auto task = graphicsContext.nextFrameTask) {
                task.run();
            } else if (task = graphicsContext.nextAsyncTask) {
                if (!workDone) {
                    workDone = true;
                    threads.signalFrameDone(SbThreadId.GRAPHICS_THREAD);
                }
                task.run();
            } else return false;
            return true;
        }
        void onThreadNextFrame () {
            // swap frame...
            workDone = false;
            graphicsContext.endFrame();
            platform.swapBuffers();
        }
    }
}





