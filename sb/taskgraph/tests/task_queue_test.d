module sb.taskgraph.tests.taskqueue_test;
import core.thread;
import core.atomic;
import std.stdio;
import std.format;

class ThreadWorker : Thread {
    bool running = false;
    bool shouldDie = false;
    void delegate(ThreadWorker) doRun;
    uint id;

    this (uint id, void delegate(ThreadWorker) doRun) {
        this.doRun = doRun;
        this.id = id;
        super(&enterThread);
    }
    void kill () { shouldDie = true; }
    //bool isRunning () { return running; }
    void enterThread () {
        assert(!running, format("Thread %s already running!", id));
        running = true;
        try {
            while (!shouldDie) {
                doRun(this);
            }
        } catch (Throwable e) {
            writefln("Thread %s crashed: %s", id, e);
        }
        running = false;
    }
}

void testQueueImpl () {
    import sb.taskgraph.impl.task;
    import sb.taskgraph.impl.task_queue;

    // num producer + consumer threads
    immutable uint NUM_PRODUCERS = 6, NUM_CONSUMERS = 8;

    auto queue = new TaskQueue();
    ITask[NUM_PRODUCERS][] producedTasks;
    ITask[NUM_CONSUMERS][] consumedTasks;
    uint taskCount = 0;
    immutable uint DUMP_TASK_INTERVAL = 1024;
    Stopwatch sw;
    bool mayRun = false;

    void dumpStats () {
        writefln("%s | %s tasks: %s", sw.peek, taskId, queue.dumpState());
    }
    void produceItem (ThreadWorker thread) {
        if (!atomicLoad(mayRun)) return;

        uint taskId = atomicOp!"+="(taskCount, 1);
        auto task = new Task({
            // ...
        });
        producedTasks[thread.id] ~= task;
        queue.insertTask(task);

        if ((taskId % DUMP_TASK_INTERVAL) == DUMP_TASK_INTERVAL - 1) {
            dumpStats();
        }
    }
    void consumeItem (ThreadWorker thread) {
        if (!atomicLoad(mayRun)) return;

        auto cid = thread.id - NUM_PRODUCERS;
        if (auto task = queue.fetchTask) {
            consumedTasks[cid] ~= task;
            if (auto err = task.tryRun) {
                writefln("Error executing task: %s", err);
            }
        }
    }
    void checkItems () {
        bool allOk = true;
        foreach (i, perThreadTasks; producedTasks) {
            uint numNotRunTasks = 0;
            foreach (task; perThreadTasks) {
                if (!task.finished) {
                    numNotRunTasks++;
                }
            }
            if (numNotRunTasks) {
                allOk = false;
                writefln("%s / %s tasks on thread %s not run!",
                    numNotRunTasks, perThreadTasks.length, i);
            }
        }

        writeln(allOk ? "ALL OK" : "ERROR!");
    }

    
    ThreadWorker[] threads;

    // Launch threads
    foreach (uint i; 1 .. (NUM_PRODUCERS + NUM_CONSUMERS)) {
        threads ~= new ThreadWorker(i, i < NUM_PRODUCERS ?
            &produceQueueItem : 
            &consumeQueueItem);
        threads[$-1].start();
    }
    atomicStore(mayRun, true);
    sw.start();

    // Run + report stats
    Thread.sleep( dur!"seconds"(5) );
    atomicStore(mayRun, false);
    sw.stop();
    dumpStats();
    
    // Shutdown threads
    foreach (thread; threads) {
        threads[i].kill();
    }
    foreach (thread; threads) {
        if (thread.isRunning) {
            writefln("Waiting on thread %s", thread.id);
            while (thread.isRunning) {}
            writefln("Thread killed");
        }
    }
    checkItems();
}

void main (string[] args) {
    testQueueImpl();
}

