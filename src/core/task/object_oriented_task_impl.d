module gsb.core.task.task;
import std.datetime: StopWatch, TickDuration, Duration;
import core.sync.mutex: Mutex;
import core.sync.condition;
import core.thread: Thread;
import std.format: format;
import std.conv;
import std.algorithm;
import gsb.utils.signals;
import gsb.core.log;


enum TaskStatus : ushort {
    WAITING, RUNNING, COMPLETE, ERROR
}
enum TaskType : ushort { ASYNC, FRAME, IMMED };

struct TaskOptions {
    //private static struct Option {
        bool recurring = false;
        ushort priority  = 0;

        auto opBinary(string op="|")(const Option rhs) const {
            return TaskOptions(
                recurring || rhs.recurring,
                max(priority, rhs.priority)
            );
        }
    //}
    static private immutable TaskOptions NONE = {};
    static private immutable TaskOptions RECURRING = { recurring: true };

    static auto @property None ()      { return cast(TaskOptions)NONE; }
    static auto @property Recurring () { return cast(TaskOptions)RECURRING; }
    static auto Priority (ushort n) { return TaskOptions(false, n); }
}
unittest {
    assert(TaskOptions.None.recurring == false && TaskOptions.None.priority == 0);
    assert(TaskOptions.Recurring.recurring == true && TaskOptions.Recurring.priority == 0);
    assert(TaskOptions.Priority(10).recurring == false && TaskOptions.Priority(10).priority == 10);

    assert((TaskOptions.None | TaskOptions.Recurring).recurring == true);
    assert((TaskOptions.None | TaskOptions.Priority(12)).recurring == false);
    assert((TaskOptions.None | TaskOptions.Priority(12)).priority == 12);
    assert((TaskOptions.None | TaskOptions.Recurring).priority == 0);

    assert((TaskOptions.Priority(0) | TaskOptions.Priority(12)).priority == 12);
    assert((TaskOptions.Priority(24) | TaskOptions.Priority(12)).priority == 24);
    assert((TaskOptions.Priority(12) | TaskOptions.Priority(24)).priority == 24);
}




struct TaskMetadata {
    string name;
    string file;
    uint   line;
    string toString () {
        return name ?
            format("%s (%s:%d)", name, file, line) :
            format("%s:%d", file, line);
    }
}

alias TaskDelegate = void delegate();
class BasicTask {
    TaskDelegate dg;
    TaskStatus   status;
    TaskType     type;
    bool         active = true;
    bool         recurring = false;
    short        priority = 0;
    union {
        Duration duration;
        Throwable err;
    }
    TaskMetadata metadata;

    this (TaskMetadata metadata, TaskType type, TaskDelegate dg, bool recurring = false, short priority = 0) {
        this.dg = dg;
        this.type = type;
        this.recurring = recurring;
        this.priority = priority;
        this.metadata = metadata;
    }
    void exec () {
        assert(status == TaskStatus.RUNNING);
        try {
            StopWatch sw; sw.start();
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
    override string toString () {
        return format("[Task %s (priority %d)]", metadata, priority);
    }
}

class DependentTask : BasicTask {
    BasicTask[] prereqs;
    TaskStatus  prereqStatus;

    this (BasicTask[] prereqs, TaskMetadata metadata, TaskType type, TaskDelegate dg, bool recurring, ushort priority)
    {
        super(metadata, type, dg, recurring, priority);
        this.prereqs = prereqs;
        foreach (prereq; prereqs)
            ++prereq.priority;
    }
    override void remove () {
        super.remove();
        foreach (prereq; prereqs)
            --prereq.priority;
    }
    override @property bool canRun () {
        if (!super.canRun)
            return false;

        // check prereq status:
        // - any ERROR    => ERROR
        // - all COMPLETE => COMPLETE
        // - otherwise    => WAITING
        if (prereqStatus == TaskStatus.WAITING) {
            prereqStatus = TaskStatus.COMPLETE;
            foreach (prereq; prereqs) {
                if (prereq.active && prereq.status == TaskStatus.ERROR) {
                    prereqStatus = TaskStatus.ERROR;
                    break;
                }
                else if (prereq.active && prereq.status != TaskStatus.COMPLETE) {
                    prereqStatus = TaskStatus.WAITING;
                    break;
                }
            }
        }

        // otherwise, canRun true iff prereq status == COMPLETE (not ERROR or WAITING)
        return prereqStatus == TaskStatus.COMPLETE;
    }
    override void reset () {
        super.reset();
        prereqStatus = TaskStatus.WAITING;
    }
    override string toString () {
        return format("[Task %s (priority %d, prereqs %d)]", metadata, priority, prereqs.length);
    }
}

class TimedTask : DependentTask {
    StopWatch sw;
    TickDuration interval;

    this (
        TickDuration interval, 
        BasicTask[] prereqs, 
        TaskMetadata metadata, 
        TaskType type, 
        TaskDelegate dg, 
        bool recurring, 
        ushort priority
    ) {
        super(prereqs, metadata, type, dg, recurring, priority);
        sw.start();
        this.interval = interval;
    }
    override @property bool canRun () {
        return super.canRun && sw.peek >= interval;
    }
    override void reset () {
        super.reset();
        sw.reset();
    }
    override string toString () {
        return format("[Timed task %s (priority %d, prereqs %d, duration %d)]",
            metadata, priority, prereqs.length, interval);
    }
}

private void swapDelete (T,Int)(ref T[] range, Int i) {
    range[i] = range[$-1];
    --range.length;
}
private void swapDeleteAll (string pred, T)(ref T[] range) {
    for (auto i = range.length; i --> 0; ) {
        auto a = range[i];
        mixin("if ("~pred~") swapDelete(range, i);");
    }
}
private void sortTasks (ref BasicTask[] tasks) {
    tasks.sort!"a.priority < b.priority";
}


class TaskGraph {
    BasicTask[] frameTasks;
    BasicTask[] asyncTasks;
    BasicTask[] immedTasks;
    Mutex mutex;
    Condition workerTaskCv;
    TGRunner  runner;

    @property auto onFrameExit () { return runner.onFrameExit; }
    @property auto onFrameEnter () { return runner.onFrameEnter; }

    this () {
        mutex = new Mutex();
        workerTaskCv = new Condition(new Mutex());
        runner = new TGRunner(this, 1);
    }
    void run () {
        runner.run();
        runner.kill();
    }
    void killWorkers () { runner.kill(); }
    void awaitWorkerDeath () {}
final:
    // Public task ctors: createTask!([name])( type, [prereqs], [duration], dg, [options] )
    auto createTask (string name = null, string file = __FILE__, uint line = __LINE__)
        (TaskType type, TaskDelegate dg, TaskOptions opts = TaskOptions.None) 
    {
        return addTask(new BasicTask(TaskMetadata(name, file, line), type, dg, opts.recurring, opts.priority));
    }
    auto createTask (string name = null, string file = __FILE__, uint line = __LINE__)
        (TaskType type, BasicTask[] prereqs, TaskDelegate dg, TaskOptions opts = TaskOptions.None)
    {
        return addTask(new DependentTask(prereqs, TaskMetadata(name, file, line), type, dg, opts.recurring, opts.priority));
    }
    auto createTask (string name = null, string file = __FILE__, uint line = __LINE__)
        (TaskType type, TickDuration duration, TaskDelegate dg, TaskOptions opts = TaskOptions.None)
    {
        return addTask(new TimedTask(duration, [], TaskMetadata(name, file, line), type, dg, opts.recurring));
    }
    auto createTask (string name = null, string file = __FILE__, uint line = __LINE__)
        (TaskType type, BasicTask[] prereqs, TickDuration duration, TaskDelegate dg, TaskOptions opts = TaskOptions.None)
    {
        return addTask(new TimedTask(duration, prereqs, TaskMetadata(name, file, line), type, dg, opts.recurring, opts.priority));
    }

    // Internal methods
private:
    BasicTask fetchNextTask () {
        auto fetchTask (ref BasicTask[] tasks) {
            return tasks.length ?
                reduce!"a ? a : b.aquire()"(cast(BasicTask)null, tasks) :
                null;
        }
        synchronized (mutex) {
            auto task = fetchTask(immedTasks);
            if (!task) task = fetchTask(frameTasks);
            if (!task) task = fetchTask(asyncTasks);
            return task;
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
            frameTasks.sortTasks();

            // cleanup + resort immed + async tasks
            immedTasks.swapDeleteAll!"!a.active";
            immedTasks.sortTasks();

            asyncTasks.swapDeleteAll!"!a.active";
            asyncTasks.sortTasks();
        }
    }
    private auto addTask (BasicTask task) {
        synchronized (mutex) {
            final switch (task.type) {
                case TaskType.ASYNC:
                    asyncTasks ~= task;
                    asyncTasks.sortTasks();
                break;
                case TaskType.IMMED:
                    immedTasks ~= task;
                    immedTasks.sortTasks();
                break;
                case TaskType.FRAME:
                    frameTasks ~= task;
                    frameTasks.sortTasks();
            }
        }
        workerTaskCv.notify();
        return task;
    }
    private void waitNextTask () {
        workerTaskCv.wait();
    }

    // Task callbacks
    void notifyFailed (BasicTask task) {
        log.write("%s failed!: %s", task, task.err);
    }
    void notifyCompleted (BasicTask task) {
        log.write("%s completed in %s", task.duration, task);
    }

    // TGWorker / TGRunner callbacks
    void notifyWorkerFailed (TGWorker worker, Throwable e) {
        log.write("%s failed! %s", worker.name, e);
    }
    void handleFailedFrame (TGRunner runner) {
        log.write("gsb-frame failed!\nFailed tasks:\n\t%s",
            frameTasks.filter!((a) => a.status == TaskStatus.ERROR)
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
        super(&run);
        this.name = name;
        tg = graph;
    }
    bool runNextTask () {
        auto task = tg.fetchNextTask();
        if (task) {
            log.write("%s executing task: %s", name, task);
            task.exec();
            if (task.status == TaskStatus.ERROR)
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
        log.write("Starting thread '%s'", name);
        try {
            runTasks();
        } catch (Throwable e) {
            tg.notifyWorkerFailed(this, e);
        }
        log.write("Thread ended: '%s'", name);
    }
    void kill () {
        log.write("Killing thread '%s'", name);
        active = false;
    }
}

class TGRunner : TGWorker {
    TGWorker[] workers;
    public Signal!() onFrameEnter;
    public Signal!() onFrameExit;

    this (TaskGraph graph, uint NUM_WORKERS = 6) {
        super("TG-RUNNER", graph);
        setWorkThreadCount( NUM_WORKERS );
    }
    @property uint numWorkers () { return cast(uint)workers.length; }
    @property uint numWorkers (uint n) {
        return setWorkThreadCount(n), n;
    }

    void setWorkThreadCount (uint n) {
        if (n < workers.length) {
            while (n < workers.length) {
                workers[$-1].kill();
                --workers.length;
            }
        } else if (n > workers.length) {
            foreach (i; 0 .. (n - workers.length)) {
                auto worker = new TGWorker(format("TG-WORKER %d", i+1), tg);
                workers ~= worker;
                worker.start();
            }
        }
    }

    override void kill () {
        super.kill();
        foreach (worker; workers)
            worker.kill();
    }
    override void runTasks () {
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
                case TaskStatus.RUNNING: assert(0);
            }
        }
    }
}

