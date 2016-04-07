
module gsb.coregl.batch;
import gsb.core.singleton;
import gsb.core.window;
import gsb.core.stats;
import core.sync.mutex;
import core.sync.condition;
import std.algorithm: swap, sort;
import std.format;

import derelict.glfw3.glfw3: glfwSwapBuffers;
import derelict.opengl3.gl3;

alias GLCommand = void delegate();

class GLBatch {
    const   string name;
    private GLCommand[] commands;

    this (string name) {
        this.name = format("glbatch '%s'", name);
    }

    final void push (GLCommand cmd) { commands ~= cmd;}
    final void push (GLCommand[] cmds) { commands ~= cmds; }
    final void reset () { commands.length = 0; }

    final void run () {
        threadStats.timedCall(name, {
            foreach (cmd; commands) {
                cmd();
            }
        });
    }
}

private struct EndOfFrameTask {
    private uint id = 0;
    public  uint priority;
    private GLCommand cmd;

    private static uint nextId = 1;

    this (GLCommand cmd, uint priority) {
        this.id = nextId++;
        this.priority = priority;
        this.cmd = cmd;
    }
    void run () {
        cmd();
    }
}


class GLCommandBuffer {
    mixin LowLockSingleton;

    private GLBatch[][4] batchLists;
    private uint current = 2;
    private uint next    = 3;
    private uint executing = 1;

    private EndOfFrameTask[] eofTasks;

    private Mutex mutex;
    private Condition cv_onFrameComplete;
    private bool isRunning = false;
    private bool shouldExit = false;

    private bool isWaitingForNextBatch = false;
    private Condition cv_batchSubmit;

    this () {
        mutex = new Mutex();
        cv_onFrameComplete = new Condition(mutex);
        cv_batchSubmit = new Condition(mutex);
    }

    // Add task to be run every frame before glSwapBuffers() gets called.
    // Returns an id to optionally remove said task.
    final auto addEndOfFrameTask (uint priority, GLCommand cmd) {
        synchronized (mutex) {
            auto task = EndOfFrameTask(cmd, priority);
            auto id = task.id;
            eofTasks ~= task;
            eofTasks.sort!"a.priority < b.priority"();
            return id;
        }
    } 
    final auto removeEndOfFrameTask (uint id) {
        foreach (i, task; eofTasks) {
            if (task.id == id) {
                synchronized (mutex) {
                    eofTasks[i] = eofTasks[$-1];
                    if (--eofTasks.length)
                        eofTasks.sort!"a.priority < b.priority"();
                    return;
                }
            }
        }
        throw new Exception(format("No task matching %d", id));
    }

    // Push command batch to be run immediately
    final void pushImmediate (GLBatch batch) {
        synchronized (mutex) {
            batchLists[current] ~= batch;
        }
        if (isWaitingForNextBatch) {
            isWaitingForNextBatch = false;
            cv_batchSubmit.notify();
        }
    }
    // Push command batch to be run next frame
    final void pushNextFrame (GLBatch batch) {
        synchronized (mutex) {
            batchLists[next] ~= batch;
        }
        if (isWaitingForNextBatch) {
            isWaitingForNextBatch = false;
            cv_batchSubmit.notify();
        }
    }
    // End current frame, calling glfwSwapBuffers on the graphics thread.
    // Call this exactly once per frame from the main thread.
    final void swapFrame () {
        if ((next+1) % 4 == executing)
            cv_onFrameComplete.wait();
        synchronized (mutex) {
            current = next;
            next    = (next+1) % 4;
            assert(current == (executing+1) % 4);
        }
    }
    // Kill the running graphics thread from the main thread.
    final void killThread () {
        synchronized (mutex) {
            shouldExit = true;
        }
    }

    // Begin and execute gl run loop; call this once from the graphics thread.
    private final void runGraphicsThread () {
        uint lastIndex;
        synchronized (mutex) {
            isRunning = true;
            lastIndex = current;
        }

        void runFrame () {
            // pre-frame
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            // Run tasks until next frame
            do {
                if (batchLists[lastIndex].length) {
                    assert(batchLists[executing].length == 0);
                    synchronized (mutex) {
                        swap(batchLists[executing], batchLists[lastIndex]);
                    }
                    foreach (batch; batchLists[executing]) {
                        batch.run();
                    }
                    batchLists[executing].length = 0;
                } else if (!shouldExit && lastIndex == current) {
                    mutex.lock();
                    isWaitingForNextBatch = true;
                    cv_batchSubmit.wait();
                }
            } while (!shouldExit && lastIndex == current);

            // post-frame
            if (!shouldExit && eofTasks.length) {
                threadStats.timedCall("postframe", {
                    synchronized (mutex) {
                        foreach (task; eofTasks) {
                            task.run();
                        }
                    }
                });
            }

            // swap buffers, etc
            if (!shouldExit) {
                threadStats.timedCall("swapBuffers", {
                    glfwSwapBuffers(g_mainWindow.handle);
                });
                cv_onFrameComplete.notify();
            }
        }

        while (!shouldExit) {
            threadStats.timedCall("frame", {
                runFrame();
            });
            //threadStats.nextFrame();
        }
        isRunning = shouldExit = false;
    }
}

struct GThreadCommandBufferRunner {
    this (GLCommandBuffer target) {
        this.target = target;
    }
    final void run () {
        assert(target && !target.isRunning);
        target.runGraphicsThread();
    }
    GLCommandBuffer target = null;
}
