module gsb.engine.engine;
import gsb.core.task;
import gsb.core.log;
import gsb.core.window;

import gsb.engine.graphics_thread;
import gsb.utils.signals;
import core.sync.mutex;
import core.sync.condition;

import derelict.glfw3.glfw3;
import gsb.core.uimanager;
import gsb.gl.debugrenderer;
import gsb.gl.graphicsmodule;
import gsb.text.textrenderer;


class GlSyncPoint {
    uint engineFrame = 0;
    uint glFrame     = 0;
    Mutex mutex;
    Condition  engineNextFrameCv;
    Condition  glNextFrameCv;
    this () {
        mutex = new Mutex();
        engineNextFrameCv = new Condition(new Mutex());
        glNextFrameCv     = new Condition(new Mutex());
    }
    private static bool shouldWait (uint a, uint b) {
        return b != uint.max ?
            a > b :
            b < a;
    }
    unittest {
        assert(!shouldWait(0,0));
        assert(!shouldWait(0,1));
        assert( shouldWait(1,0));
        assert(!shouldWait(1,1));
        assert(!shouldWait(uint.max, uint.max));
        assert(!shouldWait(uint.max, 0));
        assert( shouldWait(0,        uint.max));
    }

    class ESP {
        void notifyFrameComplete () {
            assert(!shouldWait(engineFrame, glFrame));
            synchronized (mutex) { ++engineFrame; }
            engineNextFrameCv.notify();
        }
        void waitNextFrame () {
            mutex.lock();
            while (shouldWait(engineFrame, glFrame)) {
                mutex.unlock();
                glNextFrameCv.wait();
            }
            ++engineFrame;
            mutex.unlock();
        }
    }
    class GSP {
        void notifyFrameComplete () {
            assert(!shouldWait(glFrame, engineFrame));
            synchronized (mutex) { ++glFrame; }
            glNextFrameCv.notify();
        }
        void waitNextFrame () {
            mutex.lock();
            while (shouldWait(glFrame, engineFrame)) {
                mutex.unlock();
                engineNextFrameCv.wait();
            }
            ++glFrame;
            mutex.unlock();
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
        auto t1 = tg.createTask!"launch-gl"(TaskType.IMMED, () {
            gthread.preInitGL();
            gthread.start();
        });
        auto t2 = tg.createTask!"some-other-task"(TaskType.IMMED, () {
            log.write("other task!");
        });

        auto initTasks = [ t1, t2 ];
        tg.createTask!"on-init-complete"(TaskType.IMMED, initTasks, {
            log.write("Finished init (%s)", initTasks);

            // Register per-frame events:
            auto updateComponents = tg.createTask!"UIComponents.update"(TaskType.FRAME, [], {
                log.write("Running task: UIComponents.update");
                UIComponentManager.updateFromMainThread();
                DebugRenderer.mainThread_onFrameEnd();
            });
            auto updateGraphicsComponents = tg.createTask!"GraphicsComponents.update"(TaskType.FRAME, [], {
                log.write("Running task: GraphicsComponents.update");
                GraphicsComponentManager.updateFromMainThread();
            });
            auto textUpdate = tg.createTask!"render-text"(TaskType.FRAME, [ updateComponents, updateGraphicsComponents ], {
                log.write("Running task: textRenderer.update");
                TextRenderer.instance.updateFragments();
            });

            tg.onFrameExit.connect({
                log.write("ending frame");
                engineSync.notifyFrameComplete();

                tg.createTask!"seppuku"(TaskType.FRAME, [ textUpdate ], {
                    throw new Exception("We're done");
                });
            });
            tg.onFrameEnter.connect({
                engineSync.waitNextFrame();
                log.write("starting frame");

                glfwPollEvents();
            });
        });
    }
    private void engine_runMainLoop () {
        // Engine main loop handled by task graph + per-frame tasks defined above
        tg.run();
    }
    private void engine_shutdownSubsystems () {
        gthread.kill();
        tg.killWorkers();
        
        gthread.awaitDeath();
        tg.awaitWorkerDeath();

        if (mainWindow.handle)
            glfwDestroyWindow(mainWindow.handle);
        glfwTerminate();
    }
}
