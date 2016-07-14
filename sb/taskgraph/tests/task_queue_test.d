module sb.taskgraph.tests.taskqueue_test;
import core.thread;
import core.atomic;
import std.stdio;
import std.format;
import std.datetime;
import std.conv;

class ThreadWorker : Thread {
    shared bool running = false;
    shared bool shouldDie = false;
    void delegate(ThreadWorker) doRun;
    uint id;
    uint runCount;

    this (uint id, void delegate(ThreadWorker) doRun) {
        this.doRun = doRun;
        this.id = id;
        super(&enterThread);
    }
    void kill () { shouldDie = true; }
    //bool isRunning () { return running; }
    void enterThread () {
        writefln("Enter thread %s", id);
        assert(!running, format("Thread %s already running!", id));
        running = true;
        try {
            while (!shouldDie) {
                doRun(this);
            }
        } catch (Throwable e) {
            writefln("Thread %s crashed: %s", id, e);
        }
        writefln("Exit thread %s run-count %s", id, runCount);
        running = false;
    }
}

void testQueueImpl () {
    import sb.taskgraph.impl.task;
    import sb.taskgraph.impl.task_queue;

    // num producer + consumer threads
    immutable uint NUM_PRODUCERS = 2, NUM_CONSUMERS = 2;

    auto queue = new TaskQueue!SbTask();
    SbTask*[][NUM_PRODUCERS] producedTasks;
    SbTask*[][NUM_CONSUMERS] consumedTasks;
    shared uint taskCount = 0;
    immutable uint DUMP_TASK_INTERVAL = 1024;
    StopWatch sw;
    shared bool mayRun = false;
    ThreadWorker[] threads;

    void dumpStats () {
        writefln("%s | %s tasks: %s", sw.peek.to!Duration, taskCount, queue.dumpState());
    }
    void produceItem (ThreadWorker thread) {
        if (!atomicLoad(mayRun)) return;

        uint taskId = atomicOp!"+="(taskCount, 1);
        auto task = SbTask({
            // ...
        });
        auto taskref = queue.insertTask(task);
        if (taskref is null)
            writefln("NULL TASK! threadid %s", thread.id);
        else
            producedTasks[thread.id] ~= taskref;
        thread.runCount++;

        if ((taskId % DUMP_TASK_INTERVAL) == DUMP_TASK_INTERVAL - 1) {
            dumpStats();
        }
    }
    void consumeItem (ThreadWorker thread) {
        if (!atomicLoad(mayRun)) return;

        auto cid = thread.id - NUM_PRODUCERS;
        if (auto task = queue.fetchTask) {
            thread.runCount++;
            consumedTasks[cid] ~= task;
            if (auto err = task.tryRun) {
                writefln("Error executing task: %s", err);
            }
        }
    }
    void checkItems () {
        bool allOk = true;

        import std.algorithm;
        auto npt = threads[0..NUM_PRODUCERS].map!"a.runCount".reduce!"a+b";
        auto nct = threads[NUM_PRODUCERS..(NUM_PRODUCERS+NUM_CONSUMERS)].map!"a.runCount".reduce!"a+b";
        writefln("tasks produced: %s\ntasks consumed: %s", npt, nct);

        foreach (i, tasks; producedTasks) {
            uint numNotRunTasks = 0;
            foreach (task; tasks) {
                if (task && !task.finished) {
                    numNotRunTasks++;
                }
            }
            if (numNotRunTasks) {
                allOk = false;
                writefln("%s / %s tasks on thread %s not run!",
                    numNotRunTasks, tasks.length, i);
            }
        }
        writeln(allOk ? "ALL OK" : "ERROR!");
    }

    // Launch threads
    foreach (uint i; 0 .. (NUM_PRODUCERS + NUM_CONSUMERS)) {
        threads ~= new ThreadWorker(i, i < NUM_PRODUCERS ?
            &produceItem : 
            &consumeItem);
        threads[$-1].start();
    }
    atomicStore(mayRun, true);
    sw.start();

    // Run + report stats
    Thread.sleep( dur!"seconds"(1) );
    atomicStore(mayRun, false);
    sw.stop();
    dumpStats();
    
    // Shutdown threads
    foreach (thread; threads) {
        thread.kill();
    }
    checkItems();
    foreach (thread; threads) {
        if (thread.isRunning) {
            StopWatch sw2; sw2.start();
            writefln("Waiting on thread %s", thread.id);
            while (thread.isRunning) {}
            writefln("Thread %s killed (%s)", thread.id, sw2.peek.to!Duration);
        }
    }
    writefln("EXIT");
    
}

void main (string[] args) {
    testQueueImpl();
}

