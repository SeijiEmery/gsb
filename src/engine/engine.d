module gsb.engine.engine;
import gsb.engine.engineconfig;
import gsb.engine.threads;
import gsb.core.task;
import gsb.core.log;
import gsb.core.window;
import gsb.core.uievents;

import gsb.engine.graphics_thread;
import gsb.utils.signals;
import core.sync.mutex;
import core.sync.condition;

import derelict.glfw3.glfw3;
import gsb.core.uimanager;
import gsb.gl.debugrenderer;
import gsb.gl.graphicsmodule;
import gsb.text.textrenderer;
import gsb.text.font;
import gsb.core.frametime;
import gsb.core.stats;
import std.datetime;
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

class Engine {
    public Signal!(Engine) onInit;
    public Signal!(Engine) onShutdown;

    public TaskGraph     tg;
    public GraphicsThread gthread;
    public Window mainWindow = null;
    private StopWatch engineTime;

    GlSyncPoint.ESP  engineSync;
    GlSyncPoint.GSP  glSync;

    this () {
        engineTime.start();

        // Setup main thread, task graph, and the task graph runner
        // that will run on this thread.
        gsb_setMainThread(new TGRunner(tg = new TaskGraph()));

        auto sp = new GlSyncPoint();
        engineSync = sp.new ESP();
        glSync     = sp.new GSP();

        // Create + assign graphics thread (see engine.threads)
        gthread = new GraphicsThread(this, glSync);
        gsb_setGraphicsThread(gthread);
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
        engineTime.reset();

        gthread.preInitGL();
        gthread.start();

        g_eventFrameTime.init();
        setupThreadStats("main-thread");

        auto initTasks = startInitTasks();

        tg.onFrameEnter.connect({
            engineTime.reset();
            g_eventFrameTime.updateFromRespectiveThread();
            threadStats.timedCall("poll-events", {
                glfwPollEvents();
            });
        });
        tg.createTask!"on-init-complete"(TaskType.IMMED, initTasks, {
            static if (SHOW_INIT_TASK_LOGGING)
                log.write("\n\nFinished init (%d tasks) in %s\n\n", initTasks.length, engineTime.peek.to!Duration);

            // Register per-frame events:
            auto updateComponents = tg.createTask!"UIComponents.update"(TaskType.FRAME, [], {
                //log.write("Running task: UIComponents.update");
                UIComponentManager.updateFromMainThread();
                DebugRenderer.mainThread_onFrameEnd();
            });
            auto updateGraphicsComponents = tg.createTask!"GraphicsComponents.update"(TaskType.FRAME, [], {
                //log.write("Running task: GraphicsComponents.update");
                GraphicsComponentManager.updateFromMainThread();
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
        tg.onFrameExit.connect({
            static if (SHOW_PER_FRAME_TASK_LOGGING)
                log.write("\n\nFinished frame in %s\n\n", engineTime.peek.to!Duration);
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
    }
    private void engine_runMainLoop () {
        // Engine main loop handled by task graph + per-frame tasks defined above
        gsb_runMainThread();
    }
    private void engine_shutdownSubsystems () {
        engineTime.reset();

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
            log.write("\n\nShutdown in %s\n\n", engineTime.peek.to!Duration);
    }
}
