module gsb.engine.engine;
import gsb.core.task;
import gsb.core.log;

//import gsb.engine.thread_mgr;
import gsb.engine.graphics_thread;
//import gsb.engine.event_thread;
import gsb.utils.signals;
//import std.concurrency;
//import std.stdio;

interface IEngine {}
//private void launchGraphicsThread ( shared Engine engine ) {
//    engine.graphicsMgr.runGraphicsThread();
//}

class Engine : IEngine {
    public Signal!(Engine) onInit;
    public Signal!(Engine) onShutdown;

    public TaskGraph     tg;
    public GraphicsThread gthread;

    this () {
        tg = new TaskGraph();
        gthread = new GraphicsThread();
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
            auto pollEvents = tg.createTask!"poll-events"(TaskType.FRAME, {
                glfwPollEvents();
            });
            auto updateComponents = tg.createTask!"UIComponents.update"(TaskType.FRAME, [ pollEvents ], {
                UIComponentManager.updateFromMainThread();
                DebugRenderer.mainThread_onFrameEnd();
            });
            auto updateGraphicsComponents = tg.createTask!"GraphicsComponents.update"(TaskType.FRAME, [ pollEvents ], {
                GraphicsComponentManager.updateFromMainThread();
            });
            auto textUpdate = tg.createTask!"render-text"(TaskType.FRAME, [ updateComponents, updateGraphicsComponents ], {
                TextRenderer.instance.updateFragments();
            });

            tg.onFrameExit.connect({
                log.write("ending frame");
                graphicsMgr.signalNextFrame();
            });
            tg.onFrameEnter.connect({
                log.write("starting frame");
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
    }
}
