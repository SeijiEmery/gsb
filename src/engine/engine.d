module gsb.engine.engine;
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
            log.write("SHOULD WAIT? %s (%s,%s)", shouldWait(engineFrame, glFrame), engineFrame, glFrame);
            
            synchronized (glMutex) {
                while (shouldWait(engineFrame, glFrame)) {
                    log.write("WAITING FOR GL THREAD: %d > %d", engineFrame, glFrame);
                    glNextFrameCv.wait();
                }
            }
            log.write("STARTING FRAME %d (%d)", engineFrame, glFrame);
        }
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
    }
}

class Engine {
    public Signal!(Engine) onInit;
    public Signal!(Engine) onShutdown;

    public TaskGraph     tg;
    public GraphicsThread gthread;
    public Window mainWindow = null;

    GlSyncPoint.ESP  engineSync;
    GlSyncPoint.GSP  glSync;

    this () {
        tg = new TaskGraph();

        auto sp = new GlSyncPoint();
        engineSync = sp.new ESP();
        glSync     = sp.new GSP();
        gthread   = new GraphicsThread(this, glSync);
    }
    void run () {
        log.write("launching gsb");
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
        log.write("terminated gsb");
    }

    private void engine_launchSubsystems () {
        gthread.preInitGL();
        gthread.start();

        g_eventFrameTime.init();
        setupThreadStats("main-thread");

        auto t2 = tg.createTask!"some-other-task"(TaskType.IMMED, () {
            log.write("other task!");
        });
        auto setupLogging = tg.createTask!"setup-logging"(TaskType.IMMED, () {
            g_mainWindow.onScreenScaleChanged.connect(delegate(float x, float y) {
                log.write("WindowEvent: Screen scale changed: %0.2f, %0.2f", x, y); 
            });
            g_mainWindow.onFramebufferSizeChanged.connect(delegate(float x, float y) {
                log.write("WindowEvent: Framebuffer size set to %0.2f, %0.2f", x, y);
            });
            g_mainWindow.onScreenSizeChanged.connect(delegate(float x, float y) {
                log.write("WindowEvent: Window size set to %0.2f, %0.2f", x, y);
            });

            UIComponentManager.onComponentRegistered.connect((UIComponent component, string name) {
                log.write("Registered component %s (active = %s)", name, component.active ? "true" : "false");
            });
            UIComponentManager.onComponentActivated.connect((UIComponent component) {
                log.write("Activated component %s", component.name);
            });
            UIComponentManager.onComponentDeactivated.connect((UIComponent component) {
                log.write("Deactivated component %s", component.name);
            });
            UIComponentManager.onEventSourceRegistered.connect((IEventCollector collector) {
                log.write("Registered event source");
            });
            UIComponentManager.onEventSourceUnregistered.connect((IEventCollector collector) {
                log.write("Unregistered event source");
            });

            GraphicsComponentManager.onComponentLoaded.connect((string name, GraphicsComponent component) {
                log.write("Loaded graphics component %s", name);
            });
            GraphicsComponentManager.onComponentUnloaded.connect((string name, GraphicsComponent component) {
                log.write("Unloaded graphics component %s", name);
            });
            GraphicsComponentManager.onComponentRegistered.connect((string name, GraphicsComponent component) {
                log.write("Registered graphics component %s", name);
            });
        });
        auto loadFonts = tg.createTask!"loadFonts"(TaskType.IMMED, {
            registerDefaultFonts();
        });
        auto initUIMgr = tg.createTask!"init-components"(TaskType.IMMED, [ loadFonts ], {
            UIComponentManager.init();
        });

        // Poll once before starting frame
        glfwPollEvents();

        auto initTasks = [ t2, setupLogging, initUIMgr ];
        tg.createTask!"on-init-complete"(TaskType.IMMED, initTasks, {
            //log.write("Finished init (%s)", initTasks);

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

            auto endFrame = tg.createTask!"end-frame"(TaskType.FRAME, [ textUpdate ], {
                if (glfwWindowShouldClose(mainWindow.handle)) {
                    tg.killWorkers();
                } else {
                    engineSync.notifyFrameComplete();
                }
            });
            auto waitNextFrame = tg.createTask!"wait-for-gthread"(TaskType.FRAME, [ endFrame ], {
                engineSync.waitNextFrame();
            });
            auto pollEvents = tg.createTask!"poll-events"(TaskType.FRAME, [ waitNextFrame ], {
                glfwPollEvents();
            });
        });
    }
    private void engine_runMainLoop () {
        // Engine main loop handled by task graph + per-frame tasks defined above
        tg.run();
    }
    private void engine_shutdownSubsystems () {
        gthread.kill();   engineSync.notifyFrameComplete();
        tg.killWorkers();

        if (gthread.running) {
            log.write("Waiting for graphics thread");
            while (gthread.running) {}
        }
        if (mainWindow.handle)
            glfwDestroyWindow(mainWindow.handle);
        glfwTerminate();
    }
}
