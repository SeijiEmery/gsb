module sb.taskgraph.tests.taskqueue_test;
import core.thread;
import core.atomic;
import std.stdio;
import std.format;
import std.datetime;
import std.conv;
import std.exception: enforce;
import std.file: exists, mkdirRecurse;
import std.path: dirName, chainPath;
import std.array;


// If enabled, all test functions will be run in parallel.
// This is faster, but may change performance of benchmark tests.
// Note: as a consequense of this, enforce should be used in tests,
// not assert (enforce is recoverable + threadsafe; assert just kills
// the program, which defeats the point of running in parallel)
immutable bool RUN_TESTS_PARALLEL = true;

// Local log directory (relative to executable run dir)
immutable string LOG_DIR = "tq-test-logs";

class Logger {
    File logFile;
    bool writeToStdout;

    this (string logPath, bool writeToStdout = false) {
        this.logFile = File(logPath, "w");
        this.writeToStdout = writeToStdout;
    }
    void write (string msg) {
        logFile.writeln(msg);
        if (writeToStdout)
            stdout.writeln(msg);
    }
    void write (Args...)(Args args) if (__traits(compiles, format(args))) {
        logFile.writefln(args);
        if (writeToStdout)
            stdout.writefln(args);
    }
}

void testTaskSemantics (Logger log) {
    import sb.taskgraph.impl.task;

    shared uint foo = 0;
    shared bool t1_didRun = false, t1_didPostrun = false;
    shared bool t2_didRun = false, t2_didPostRun = false;

    auto t1 = SbTask({
        atomicOp!"+="(foo, 2 + 2); 
        atomicStore(t1_didRun, true);
    }, (ref SbTask task) {
        enforce(task.finished_ok, "Task completed successfully");
        atomicStore(t1_didPostrun, true);
    });
    auto t2 = SbTask({
        atomicStore(t2_didRun, true);
        throw new Exception("Foo!");
    }, (ref SbTask task) {
        atomicStore(t2_didPostRun, true);
        enforce(task.finished_with_error, "Task threw exception + recovered");
    });

    // test t1 init state + tryClaim()
    enforce(t1.unclaimed && !t1.finished, "bad init state");
    enforce(t1.tryClaim, "task not claimable?!");
    enforce(!t1.unclaimed && !t1.finished, "bad state after claim");
    enforce(!t1.tryClaim, "task is already claimed; tryClaim should not succeed!");

    // Test t1 tryRun() + post run state
    auto t1_err = t1.tryRun;
    enforce(!t1_err, "t1 should not throw");
    enforce(!t1.unclaimed && t1.finished && t1.finished_ok && !t1.finished_with_error,
        "bad state after tryRun!");
    enforce(!t1.tryClaim, "t1 should still not be claimable");

    // test atomic variables to make sure that the delegates passed
    // to t1 actually ran
    enforce(t1_didRun, "t1 didn't actually run?!");
    enforce(t1_didPostrun, "t1 no post run?!");
    enforce(atomicLoad(foo) == 4, format("bad result for foo: %s", foo));

    // reset + test claim
    t1.reset();
    enforce(t1.unclaimed && !t1.finished, "bad state after reset");
    enforce(t1.tryClaim, "t1 should be claimable after reset");
    enforce(!t1.unclaimed);

    // test tryRun() after reset
    atomicStore(t1_didRun, false);
    atomicStore(t1_didPostrun, false);

    auto t1_err2 = t1.tryRun();
    enforce(!t1_err2, "t1.tryRun should not throw");
    enforce(t1_didRun && t1_didPostrun, "t1 should run again...");

    // check state (again)
    enforce(t1_didRun, "t1 didn't actually run?!");
    enforce(t1_didPostrun, "t1 no post run?!");
    enforce(atomicLoad(foo) == 8, format("bad result for foo: %s", foo));


    // Test t2 init state + claim
    enforce(t2.unclaimed && t2.tryClaim && !t2.unclaimed);
    enforce(!t2.tryClaim && !t2.finished);

    // Test t2 run (should throw)
    auto err = t2.tryRun();
    enforce(err, "t2 should throw!");
    enforce(!t2.unclaimed && t2.finished && t2.finished_with_error && !t2.finished_ok);
    enforce(atomicLoad(t2_didRun) && atomicLoad(t2_didPostRun));
}
void testTaskQueueSemantics (Logger log) {

}
void testProducerConsumerQueue (Logger log) {
    import sb.taskgraph.impl.task;
    import sb.taskgraph.impl.task_queue;

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
            log.write("Enter thread %s", id);
            assert(!running, format("Thread %s already running!", id));
            running = true;
            try {
                while (!shouldDie) {
                    doRun(this);
                }
            } catch (Throwable e) {
                log.write("Thread %s crashed: %s", id, e);
            }
            log.write("Exit thread %s run-count %s", id, runCount);
            running = false;
        }
    }

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
        log.write("%s | %s tasks: %s", sw.peek.to!Duration, taskCount, queue.dumpState());
    }
    void produceItem (ThreadWorker thread) {
        if (!atomicLoad(mayRun)) return;

        uint taskId = atomicOp!"+="(taskCount, 1);
        auto task = SbTask({
            // ...
        });
        auto taskref = queue.insertTask(task);
        enforce(taskref !is null, format("null task returned from queue.insert! threadId %s", thread.id));
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
                log.write("Error executing task: %s", err);
            }
        }
    }
    void checkItems () {
        bool allOk = true;

        import std.algorithm;
        auto npt = threads[0..NUM_PRODUCERS].map!"a.runCount".reduce!"a+b";
        auto nct = threads[NUM_PRODUCERS..(NUM_PRODUCERS+NUM_CONSUMERS)].map!"a.runCount".reduce!"a+b";
        log.write("tasks produced: %s\ntasks consumed: %s", npt, nct);

        foreach (i, tasks; producedTasks) {
            uint numNotRunTasks = 0;
            foreach (task; tasks) {
                if (task && !task.finished) {
                    numNotRunTasks++;
                }
            }
            if (numNotRunTasks) {
                allOk = false;
                log.write("%s / %s tasks on thread %s not run!",
                    numNotRunTasks, tasks.length, i);
            }
        }
        log.write(allOk ? "All tasks run" : "Not all tasks run!");
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
            log.write("Waiting on thread %s", thread.id);
            while (thread.isRunning) {}
            log.write("Thread %s killed (%s)", thread.id, sw2.peek.to!Duration);
        }
    }
}

void runTests (testfuncs...)(const(char)[] logDir) {
    shared uint numTestsPassed = 0;
    void runTestFunc (string testfunc)() {
        auto log = new Logger(logDir.chainPath(testfunc ~ ".txt").array.to!string);
        try {
            mixin(testfunc~"(log);");

            log.writeToStdout = true;
            log.write("PASSED: %s", testfunc);
            atomicOp!"+="(numTestsPassed, 1);
        } catch (Throwable err) {
            log.writeToStdout = true;
            log.write("FAILED: %s\n%s\n", testfunc, err);
        }
    }
    static if (RUN_TESTS_PARALLEL) {
        Thread[] threads;
        foreach (testfunc; testfuncs) {
            threads ~= new Thread({
                runTestFunc!testfunc();
            }).start();
        }
        foreach (thread; threads)
            thread.join();
    } else {
        foreach (testfunc; testfuncs) {
            runTestFunc!testfunc();
        } 
    }
    write(numTestsPassed == testfuncs.length ?
        "All tests passed." :
        format("%s / %s tests passed.", numTestsPassed, testfuncs.length));
    writefln(" logs written to '%s'", logDir);
}
void main (string[] args) {
    auto logDir = args[0].dirName.chainPath(LOG_DIR).array;
    if (!logDir.exists) {
        try {
            mkdirRecurse(logDir);
        } catch (Throwable err) {
            writefln("Could not create log dir '%s':\n%s", logDir, err);
            return;
        }
    }
    runTests!(
        "testTaskSemantics",
        "testTaskQueueSemantics",
        "testProducerConsumerQueue"
    )(logDir);
}

