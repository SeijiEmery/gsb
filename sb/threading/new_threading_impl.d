module sb.threading.engine_threads;

interface IThreadManager {
    SbThreadStatus getStatus (SbThreadId);

    void launchThread (SbThreadId);
    void enterThread  (SbThreadId);

    void setWorkerCount (uint);
    uint getWorkerCount ();

    void pushTask (SbTaskType, void delegate() action);
}

enum SbTaskType { 
    ASYNC,      // task runs async, low priority
    THIS_FRAME, // task blocks next frame, high priority
    MT_ONLY,    // ditto, but must be run on the main thread (not a worker thread)
    GT_ONLY,    // run only on graphics thread
}

module sb.threading.impl.engine_threads;
import sb.taskgraph.taskqueue;

private class ThreadManager : IThreadManager {
    ITaskQueue[SbTaskType.max]  taskQueues;

    // Number of pending, non-executed tasks by type
    shared int asyncTaskCount = 0;    // ASYNC
    shared int mtFrameTaskCount = 0;  // THIS_FRAME, MT_ONLY
    shared int gtFrameTaskCount = 0;  // GT_ONLY

    // Current frame count on main / graphics threads; used for synchronization
    shared uint mtCurrentFrame = 0;
    shared uint gtCurrentFrame = 0;

final:
    void pushTask (SbTaskType type, void delegate() action) {
        final switch (type) {
            case SbTaskType.ASYNC: atomicOp!"+="(asyncTaskCount, 1); break;
            case SbTaskType.THIS_FRAME:
            case SbTaskType.MT_ONLY: atomicOp!"+="(mtFrameTaskCount, 1); break;
            case SbTaskType.GT_ONLY: atomicOp!"+="(gtFrameTaskCount, 1); break;
        }
        taskQueues[type].insertTask(action);
    }
    private bool runTask (SbTaskType type)() {
        if (taskQueues[type].fetchAndRunTask()) {
            final switch (type) {
                case SbTaskType.ASYNC: atomicOp!"-="(asyncTaskCount, 1); break;
                case SbTaskType.THIS_FRAME:
                case SbTaskType.MT_ONLY: atomicOp!"-="(mtFrameTaskCount, 1); break;
                case SbTaskType.GT_ONLY: atomicOp!"-="(gtFrameTaskCount, 1); break;
            }
            return true;
        }
        return false;
    }
    bool mt_tryAdvanceFrame (ref uint currentLocalFrame) {
        auto curFrame = atomicLoad(mtCurrentFrame);
        if (currentLocalFrame != curFrame) {
            currentLocalFrame  = curFrame;
            return true;
        }
        if (atomicLoad(mtFrameTaskCount) <= 0) {
            if (cas(&mtFrameTaskCount, curFrame, curFrame+1)) {
                currentLocalFrame = curFrame+1;
                return true;
            }
        }
        return false;
    }
}

class ThreadWorker {
    ThreadManager mgr;
    uint localFrameId = 0;

    // direct message sending (run X on thread Y, implemented in addition to sbTask)
    void delegate()[]        messageQueue;
    void delegate(Exception) messageErrorHandler;
    Mutex                    messageMutex;

    shared bool shouldDie = false;
    shared SbThreadStatus threadStatus;

    void delegate(ThreadWorker) initThread;
    void delegate(ThreadWorker) shutdownThread;
    void delegate(ThreadWorker, Throwable) onThreadError = null;
    Throwable error = null;

    final private bool runLocalMessages () {
        if (messageQueue.length) {
            synchronized (messageMutex) {
                foreach (message; messageQueue) {
                    try {
                        message();
                    } catch (Exception e) {
                        messageErrorHandler(e);
                    }
                }
                messageQueue.length = 0;
            }
            return true;
        }
        return false;
    }
    abstract bool runNextTask ();

    final void kill () { atomicStore(shouldDie, true); }
    final void run () {
        bool didShutdown = false;
        this.error = null;
        try {
            atomicStore(threadStatus, SbThreadStatus.INITIALIZING);
            initThread(this);

            atomicStore(threadStatus, SbThreadStatus.RUNNING);
            while (!shouldDie) {
                runNextTask() || maybeWait();
            }
            didShutdown = true;
            shutdownThread(this);

            atomicStore(threadStatus, SbThreadStatus.EXIT_OK);

        } catch (Throwable e) {
            this.error = e;
            atomicStore(threadStatus, SbThreadStatus.EXIT_ERROR);

            if (!didShutdown)
                shutdownThread(this);

            if (onThreadError)
                onThreadError(this, e);
        }
    }
    private void maybeWait () {

    }
    private final bool advanceFrame () {
        onNextFrame(this);
        return true;
    }
}

class MTWorker : ThreadWorker {
    final override bool runNextTask () {
        return runLocalMessages ||
            mgr.runTask!SbTaskType.MT_ONLY || 
            mgr.runTask!SbTaskType.THIS_FRAME ||
            (mgr.mt_tryAdvanceFrame(localFrameId) && advanceFrame(this)) ||
            mgr.runTask!SbTaskType.ASYNC;
    }
}
class WTWorker : ThreadWorker {
    final override bool runNextTask () {
        return runLocalMessages ||
            mgr.runTask!SbTaskType.THIS_FRAME ||
            (mgr.mt_tryAdvanceFrame(localFrameId) && advanceFrame(this)) ||
            mgr.runTask!SbTaskType.ASYNC;
    }
}
class GTWorker : ThreadWorker {
    final override bool runNextTask () {
        return runLocalMessages ||
            mgr.runTask!SbTaskType.GT_ONLY ||
            (mgr.gt_tryAdvanceFrame(localFrameId) && advanceFrame(this));
    }
}

























