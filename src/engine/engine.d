module gsb.engine.engine;
import gsb.engine.engineconfig;
import gsb.engine.engine_interface;
import gsb.engine.threads;
import gsb.core.task;
import gsb.core.log;
import gsb.core.window;
import gsb.core.uievents;

import gsb.engine.graphics_thread;
import gsb.utils.signals;
import gsb.utils.sampler: FramerateSampler;

import core.sync.mutex;
import core.sync.condition;

import derelict.glfw3.glfw3;
import gsb.core.uimanager;
import gsb.core.slate2d;
import gsb.gl.graphicsmodule;
import gsb.core.text;
import gsb.core.stats;
import std.format;
import std.datetime;
import core.time;
import std.conv;

class GlSyncPoint {
    uint engineFrame = 0;
    uint glFrame     = 0;
    Mutex mutex;

    Mutex engineMutex, glMutex;
    Condition  engineNextFrameCv;
    Condition  glNextFrameCv;
    this () {
        mutex = new Mutex();
        engineNextFrameCv = new Condition(engineMutex = new Mutex());
        glNextFrameCv     = new Condition(glMutex     = new Mutex());
    }
    private static bool shouldWait (uint a, uint b) {
        return a < uint.max && b < uint.max ?
            a > b :
            a < b;
    }
    unittest {
        assert(!shouldWait(0,0));
        assert(!shouldWait(0,1));
        assert( shouldWait(1,0));
        assert(!shouldWait(1,1));

        assert(!(uint.max < uint.max) && uint.max > 0);

        assert(!shouldWait(uint.max, uint.max));
        assert(!shouldWait(uint.max, 0));
        assert( shouldWait(0,        uint.max));
    }

    class ESP {
        void notifyFrameComplete () {
            //assert(!shouldWait(engineFrame, glFrame));
            //synchronized (mutex) { ++engineFrame; }
            //engineNextFrameCv.notify();
            synchronized (engineMutex) {
                ++engineFrame;
                engineNextFrameCv.notify();
            }
        }
        void waitNextFrame () {
            //mutex.lock();
            static if (SHOW_MT_GL_SYNC_LOGGING)
                log.write("SHOULD WAIT? %s (%s,%s)", shouldWait(engineFrame, glFrame), engineFrame, glFrame);
            
            synchronized (glMutex) {
                while (shouldWait(engineFrame, glFrame)) {
                    static if (SHOW_MT_GL_SYNC_LOGGING)
                        log.write("WAITING FOR GL THREAD: %d > %d", engineFrame, glFrame);
                    glNextFrameCv.wait();
                }
            }
            static if (SHOW_MT_GL_SYNC_LOGGING)
                log.write("STARTING FRAME %d (%d)", engineFrame, glFrame);
        }
        @property auto currentFrame () { return engineFrame; }
    }
    class GSP {
        void notifyFrameComplete () {
            assert(!shouldWait(glFrame, engineFrame));
            synchronized (glMutex) {
                ++glFrame;
                glNextFrameCv.notify();
            }
        }
        void waitNextFrame () {
            synchronized (engineMutex) {
                while (shouldWait(glFrame, engineFrame)) {
                    engineNextFrameCv.wait();
                }
            }
        }
        @property auto currentFrame () { return glFrame; }
    }
}

private struct EngineTime {
    private StopWatch engineTimer;
    private Duration  initTime;
    private FrameTime ft;
    private FramerateSampler!128 framerateSampler;

    void beginInit () {
        engineTimer.start();
    }
    void onEndInit () {
        initTime = engineTimer.peek.to!Duration;
        engineTimer.reset();
    }
    void onFrameEnd () {
        auto dt = engineTimer.peek; engineTimer.reset();

        ft.dt = dt.to!("seconds", double);
        ft.time += ft.dt;

        framerateSampler.addSample( ft.dt );
        ft.framerate = framerateSampler.getFramerate(1.0); // get framerate over 1 sec
    }

    // Window framerate hack
    private immutable double WINDOW_UPDATE_INTERVAL = 100e-3; // 100 ms
    private double timeToNextUpdate = 0;
    void setWindowFramerate (Window window) {
        import derelict.glfw3.glfw3;
        if ((timeToNextUpdate -= ft.dt) < 0) {
            timeToNextUpdate = WINDOW_UPDATE_INTERVAL;
            window.setTitle(format("GLSandbox -- %s (%s)\0", ft.framerate, framerateSampler.current));
        }
    }
}

class Engine : IEngine {
    public TaskGraph     tg;
    public GraphicsThread gthread;
    public Window mainWindow = null;
    private EngineTime time;

    GlSyncPoint.ESP  engineSync;
    GlSyncPoint.GSP  glSync;

    public override @property FrameTime currentTime () { return time.ft; }
    public override @property TaskGraph taskGraph   () { return tg; }

    this () {
        time.beginInit();

        // Setup main thread, task graph, and the task graph runner
        // that will run on this thread.
        gsb_setMainThread(new TGRunner(tg = new TaskGraph()));

        auto sp = new GlSyncPoint();
        engineSync = sp.new ESP();
        glSync     = sp.new GSP();

        // Create + assign graphics thread (see engine.threads)
        gthread = new GraphicsThread(this, glSync);
        gsb_setGraphicsThread(gthread);

        // Set ui_cm
        UIComponentManager.setEngine(this);
    }
    void run () {
        log.write("Launching gsb");
        try {
            engine_launchSubsystems();
            onInit.emit(this);
            engine_runMainLoop();

        } catch (Throwable e) {
            log.write("%s", e);
        }
        try {
            try {
                onShutdown.emit(this);
            } catch (Throwable e) {
                log.write("while signaling shutdown: %s", e);
            }
            engine_shutdownSubsystems();
        } catch (Throwable e) {
            log.write("while shutting down engine: %s", e);
        }
    }

    private auto startInitTasks () {
        BasicTask[] tasks;
        //tasks ~= tg.createTask!"some-other-task"(TaskType.IMMED, () {
        //    log.write("other task!");
        //});
        tasks ~= tg.createTask!"setup-logging"(TaskType.IMMED, () {
            static if (SHOW_WINDOW_EVENT_LOGGING) {
                g_mainWindow.onScreenScaleChanged.connect(delegate(float x, float y) {
                    log.write("WindowEvent: Screen scale changed: %0.2f, %0.2f", x, y); 
                });
                g_mainWindow.onFramebufferSizeChanged.connect(delegate(float x, float y) {
                    log.write("WindowEvent: Framebuffer size set to %0.2f, %0.2f", x, y);
                });
                g_mainWindow.onScreenSizeChanged.connect(delegate(float x, float y) {
                    log.write("WindowEvent: Window size set to %0.2f, %0.2f", x, y);
                });
            }
            static if (SHOW_COMPONENT_REGISTRATION)
                UIComponentManager.onComponentRegistered.connect((UIComponent component, string name) {
                    log.write("Registered component %s (active = %s)", name, component.active ? "true" : "false");
                });
            static if (SHOW_COMPONENT_ACTIVATION) {
                UIComponentManager.onComponentActivated.connect((UIComponent component) {
                    log.write("Activated component %s", component.name);
                });
                UIComponentManager.onComponentDeactivated.connect((UIComponent component) {
                    log.write("Deactivated component %s", component.name);
                });
            }
            static if (SHOW_EVENT_SOURCE_LOGGING) {
                UIComponentManager.onEventSourceRegistered.connect((IEventCollector collector) {
                    log.write("Registered event source");
                });
                UIComponentManager.onEventSourceUnregistered.connect((IEventCollector collector) {
                    log.write("Unregistered event source");
                });
            }
            static if (SHOW_GRAPHICS_COMPONENT_LOGGING) {
                GraphicsComponentManager.onComponentLoaded.connect((string name, GraphicsComponent component) {
                    log.write("Loaded graphics component %s", name);
                });
                GraphicsComponentManager.onComponentUnloaded.connect((string name, GraphicsComponent component) {
                    log.write("Unloaded graphics component %s", name);
                });
                GraphicsComponentManager.onComponentRegistered.connect((string name, GraphicsComponent component) {
                    log.write("Registered graphics component %s", name);
                });
            }
        });
        auto loadFonts = tg.createTask!"loadFonts"(TaskType.IMMED, {
            registerDefaultFonts();
        });
        tasks ~= loadFonts;
        tasks ~= tg.createTask!"init-components"(TaskType.IMMED, [ loadFonts ], {
            UIComponentManager.init();
        });
        return tasks;
    }

    private void engine_launchSubsystems () {
        gthread.preInitGL();
        gthread.start();

        setupThreadStats("main-thread");

        auto initTasks = startInitTasks();

        // Called before frame tasks
        tg.onFrameEnter.connect({
            // Poll events
            threadStats.timedCall("poll-events", {
                glfwPollEvents();
            });

            // Dispatch engine onEnterFrame actions
            onFrameEnter.emit(this);
        });

        // Called after frame tasks finish.
        tg.onFrameExit.connect({
            // Dispatch engine onEndFrame actions
            onFrameExit.emit(this);

            // Calculate / record dt + framerate
            time.onFrameEnd();
            time.setWindowFramerate(mainWindow);

            static if (SHOW_PER_FRAME_TASK_LOGGING)
                log.write("\n\nFinished frame in %s\n\n", currentTime.dt.seconds);

            if (glfwWindowShouldClose(mainWindow.handle)) {
                gsb_mainThread.kill();
            } else {
                engineSync.notifyFrameComplete();

                perThreadStats["main-thread"].accumulateFrame();
                threadStats.timedCall("wait-for-gl", {
                    engineSync.waitNextFrame();
                });
            }
        });

        // Setup frame tasks
        tg.createTask!"on-init-complete"(TaskType.IMMED, initTasks, {
            time.onEndInit();
            static if (SHOW_INIT_TASK_LOGGING)
                log.write("\n\nFinished init (%d tasks) in %s\n\n", initTasks.length, time.initTime);

            // Register per-frame events:
            auto updateComponents = tg.createTask!"UIComponents.update"(TaskType.FRAME, [], {
                //log.write("Running task: UIComponents.update");
                UIComponentManager.updateFromMainThread( currentTime );
                DebugRenderer.mainThread_onFrameEnd();
            });
            auto updateGraphicsComponents = tg.createTask!"GraphicsComponents.update"(TaskType.FRAME, [], {
                //log.write("Running task: GraphicsComponents.update");
                GraphicsComponentManager.updateFromMainThread( currentTime );
            });
            auto textUpdate = tg.createTask!"render-text"(TaskType.FRAME, [ updateComponents, updateGraphicsComponents ], {
                //log.write("Running task: textRenderer.update");
                TextRenderer.instance.updateFragments();
            });

            // Test messenging system
            static if (RUN_THREAD_MESSAGING_SYSTEM_TEST) {
                gsb_graphicsThread.send({
                    log.write("Hello world! (sent from main thread)");
                    gsb_mainThread.send({
                        log.write("Hello world! (sent from graphics thread?)");
                    });
                });

                void pingBack (uint n, EngineThreadId from) {
                    (cast(EngineThreadId)(gsb_localThreadId - 1)).broadcastMessage({
                        log.write("ping back: %d (sent from %s)", n, from);
                        pingBack(n, gsb_localThreadId);
                    });
                }

                void sayHiRecursive (uint n) {
                    gsb_getWorkThreadId(n).broadcastMessage({
                        log.write("Hello world! (worker %d)", n);
                        sayHiRecursive(n+1);
                        pingBack(n, gsb_localThreadId);
                    });
                }
                sayHiRecursive(0);
            }
        });
        
    }
    private void engine_runMainLoop () {
        // Engine main loop handled by task graph + per-frame tasks defined above
        gsb_runMainThread();
    }
    private void engine_shutdownSubsystems () {
        time.engineTimer.reset();

        log.write("Killing threads");
        foreach (thread; gsb_engineThreads) {
            if (thread)
                thread.kill();
        }
        engineSync.notifyFrameComplete();
        if (gthread.running) {
            log.write("Waiting for graphics thread");
            while (gthread.running) {}
        }
        
        if (mainWindow.handle)
            glfwDestroyWindow(mainWindow.handle);
        glfwTerminate();

        uint threadsStillRunning = 0;
        foreach (thread; gsb_engineThreads) {
            if (thread && thread.running) {
                log.write("Waiting on %s (%s)", thread.engineThreadId, thread.threadStatus);
                ++threadsStillRunning;
            }
        }
        if (threadsStillRunning) {
            log.write("Waiting on %d threads", threadsStillRunning);
            bool keepWaiting () {
                foreach (thread; gsb_engineThreads) {
                    if (thread && thread.running)
                        return true;
                }
                return false;
            }
            while (keepWaiting) {}
        }

        static if (SHOW_INIT_TASK_LOGGING)
            log.write("\n\nShutdown in %s\n\n", time.engineTimer.peek.to!Duration);
    }
}
