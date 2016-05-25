

enum TaskStatus {
    WAITING, RUNNING, COMPLETE, ERROR
}

alias TaskDelegate = void delegate();
class BasicTask {
    TaskDelegate dg;
    TaskStatus   status;
    bool         active = true;
    short        priority = 0;
    union {
        Duration duration;
        Throwable err;
    }

    this (TaskDelegate dg, short priority = 0) { 
        this.dg = dg; 
        this.priority = priority;
    }
    void exec () {
        assert(stats == TaskStatus.RUNNING);
        try {
            Stopwatch sw; sw.start();
            dg();
            sw.stop();
            status = TaskStatus.COMPLETE;
            duration = sw.peek.to!Duration;
        } catch (Throwable e) {
            status = TaskStatus.ERROR;
            err = e;
        }
    }
    @property bool canRun () { return active && status == TaskStatus.WAITING; }
    auto aquire () {
        return canRun ?
            status = TaskStatus.RUNNING, this :
            null;
    }
    void reset () {
        status = TaskStatus.WAITING;
    }
    void remove () {
        active = false;
    }
}

class DependentTask : BasicTask {
    BasicTask[] prereqs;
    TaskStatus  prereqStatus;

    this (TaskDelegate dg, BasicTask[] prereqs) {
        super(dg);
        this.prereqs = prereqs;
        foreach (prereq; prereqs)
            ++prereq.priority;
    }
    void remove () {
        super.remove();
        foreach (prereq; prereqs)
            --prereq.priority;
    }
    @property bool canRun () {
        if (!super.canRun)
            return false;

        // check prereq status:
        // - any ERROR    => ERROR
        // - all COMPLETE => COMPLETE
        // - otherwise    => WAITING
        if (prereqStatus == TaskStatus.WAITING) {
            prereqStatus = TaskStatus.COMPLETE;
            foreach (prereq; prereqs) {
                if (prereq.active && prereq.status == TaskStatus.ERROR)
                    return prereqStatus = TaskStatus.ERROR, false;
                if (prereq.active && prereqStatus != TaskStatus.COMPLETE)
                    return prereqStatus = TaskStatus.WAITING, false;
            }
        }

        // otherwise, canRun true iff prereq status == COMPLETE (not ERROR or WAITING)
        return prereqStatus == TaskStatus.COMPLETE;
    }
    void reset () {
        super.reset();
        prereqStatus = TaskStatus.WAITING;
    }
}

class TimedTask : DependentTask {
    Stopwatch sw;
    Duration  interval;

    this (TaskDelegate dg, BasicTask[] prereqs, Duration interval) {
        super(dg, prereqs);
        sw.start();
        this.interval = interval;
    }
    @property bool canRun () {
        return super.canRun && sw.peek.to!Duration >= interval;
    }
}

enum TaskType { ASYNC, FRAME, IMMED };

private void swapDelete (T)(ref T[] range, uint i) {
    range[i] = range[$-1];
    --range.length;
}
private void swapDeleteAll (string pred, T)(ref T[] range) {
    for (auto i = range.length; i --> 0; ) {
        auto a = range[i];
        mixin("if (%s) swapDelete(range, i)");
    }
}



class TaskGraph {
    BasicTask[] frameTasks;
    BasicTask[] asyncTasks;
    BasicTask[] immedTasks;
    Mutex mutex;

    this () {
        mutex = new Mutex();
    }
    auto launch (uint NUM_WORKERS)() {
        auto runner = new TGRunner!NUM_WORKERS(this);
        runner.run();
        runner.kill();
        return this;
    }
final:
    BasicTask fetchNextTask () {
        auto fetchTask (ref BasicTask[] tasks) {
            return tasks.length ?
                reduce!"a ? a : b.aquire"(null, tasks) :
                null;
        }
        synchronized (mutex) {
            return fetchTask(immedTasks) ||
                fetchTask(frameTasks) ||
                fetchTask(asyncTasks);
        }
    }
    TaskStatus nextFrameStatus () {
        foreach (task; frameTasks) {
            if (task.status == TaskStatus.ERROR)
                return TaskStatus.ERROR;
            if (task.status != TaskStatus.COMPLETE)
                return TaskStatus.WAITING;
        }
        return TaskStatus.COMPLETE;
    }
    void enterNextFrame () {
        synchronized (mutex) {
            // cleanup + reset frame tasks
            for (auto i = frameTasks.length; i --> 0; ) {
                if (!frameTasks[i].active) {
                    frameTasks.swapDelete(i);
                } else {
                    frameTasks[i].reset();
                }
            }
            frameTasks.sort!"a.priority";

            // cleanup + resort immed + async tasks
            immedTasks.swapDeleteAll!"!a.active";
            immedTasks.sort!"a.priority";

            asyncTasks.swapDeleteAll!"!a.active";
            asyncTasks.sort!"a.priority";
        }
    }
    private void addTask (TaskType type, BasicTask task) {
        synchronized (mutex) {
            switch (type) {
                case TaskType.ASYNC:
                    asyncTasks ~= task;
                    asyncTasks.sort!"a.priority";
                break;
                case TaskType.IMMED:
                    immedTasks ~= task;
                    immedTasks.sort!"a.priority";
                break;
                case TaskType.FRAME:
                    frameTasks ~= task;
                    frameTasks.sort!"a.priority";
            }
        }
        workerTaskCv.notify();
    }
    private void waitNextTask () {
        workerTaskCv.wait();
    }

    auto createTask (TaskType type, TaskDelegate dg) {
        addTask(type, new BasicTask(dg));
    }
    auto createTask (TaskType type, BasicTask[] prereqs, TaskDelegate dg) {
        addTask(type, new DependentTask(dg, prereqs));
    }
    auto createTask (TaskType type, BasicTask[] prereqs, Duration dur, TaskDelegate dg) {
        addTask(type, new TimedTask(dg, prereqs, dur, dg));
    }
    auto createTask (TaskType type, Duration dur, TaskDelegate dg) {
        addTask(type, new TimedTask(dg, [], dur, dg));
    }

private:
    // Task callbacks
    void notifyFailed (BasicTask task) {
        log.write("Task failed!: %s", task.err);
    }
    void notifyCompleted (BasicTask task) {
        log.write("Task completed in %s", task.duration);
    }

    // TGWorker / TGRunner callbacks
    void notifyWorkerFailed (TGWorker worker, Throwable e) {
        log.write("%s failed! %s", worker.name, e);
    }
    void handleFailedFrame (TGRunner runner) {
        log.write("gsb-frame failed!\nFailed tasks:\n\t%s",
            frameTasks.filter!"a.status == TaskStatus.ERROR"
                .map!((BasicTask task) {
                    return format("Failed task: %s", task.err);
                })
                .reduce!`a ~ "\n\t" ~ b`
        );
        runner.kill();
    }
    void summarizeFrame () {
        log.write("Finished frame");
    }
}

class TGWorker : Thread {
    string name;
    TaskGraph tg;
    bool active = true;

    this (string name, TaskGraph graph) {
        this.name = name;
        tg = graph;
    }
    bool runNextTask () {
        auto task = tg.fetchNextTask();
        if (task) {
            task.exec();
            if (task.status == ERROR)
                tg.notifyFailed(task);
            else
                tg.notifyCompleted(task);
            return true;
        }
        return false;
    }
    void runTasks () {
        while (active) {
            while (runNextTask()) {}
            tg.waitNextTask();
        }
    }
    final void run () {
        try {
            runTasks();
        } catch (Throwable e) {
            tg.notifyWorkerFailed(this, e);
        }
    }
    void kill () {
        active = false;
    }
}

class TGRunner (uint NUM_WORKERS = 6) : TGWorker {
    TGWorker [ NUM_WORKERS ] workers;
    public Signal!void onFrameEnter;
    public Signal!void onFrameExit;

    this (TaskGraph graph) {
        super("TG-RUNNER", graph);
        foreach (i; 0 .. NUM_WORKERS) {
            workers[i] = new TGWorker(format("TG-WORKER %d", i+1), graph).run();
        }
    }
    void kill () {
        super.kill();
        foreach (worker; workers)
            worker.kill();
    }
    void runTasks () {
        while (active) {
            final switch (tg.nextFrameStatus) {
                case TaskStatus.WAITING: {
                    runNextTask();
                } break;
                case TaskStatus.ERROR: {
                    tg.handleFailedFrame(this);
                
                } break;
                case TaskStatus.COMPLETE: {
                    tg.summarizeFrame(); onFrameExit.emit();
                    tg.enterNextFrame(); onFrameEnter.emit();
                } break;
            }
        }
    }
}

