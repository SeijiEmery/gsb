module gsb.core.task.task;

alias TaskDelegate     = void delegate();
alias TaskCompletionDg = void delegate(Task, Duration);
alias TaskErrorDg      = void delegate(Task, Throwable);

enum  TaskState : ubyte {
    WAITING = 0, RUNNING, ERROR, COMPLETED
}
private immutable MAX_TASK_DEPS = 16;

class Task {
    TaskDelegate dg;
    ushort    priority = 0;
    TaskState status;
    Task[MAX_TASK_DEPS] deps;
}

struct TaskCompletionListener {
    private TaskCompletionDg dg;
    private Task task;
    private bool removed = false;

    public void detach () { removed = true; }
}
struct TaskErrorListener {
    private TaskErrorDg dg;
    private Task task;
    private bool removed = false;

    public void detach () { removed = true; }
}

class TaskListenerStore {
    TaskCompletionListener[] onCompleteListeners;
    TaskErrorListener[]      onErrorListeners;
    Mutex mutex;

    this () {
        mutex = new Mutex();
    }
    auto onComplete (Task task, TaskCompletionDg dg) {
        synchronized (mutex.write) {
            onCompleteListeners ~= TaskCompletionListener(dg, task);
            auto x = &onCompleteListeners[$-1];
            onCompleteListeners.sort();
            return x;
        }
    }
    auto onError (Task task, TaskErrorDg dg) {
        synchronized (mutex.write) {
            onErrorListeners ~= TaskErrorListener(dg, task);
            auto x = &onErrorListeners[$-1];
            onErrorListeners.sort();
            return x;
        }
    }
    void fireCompletionListeners (Task task, Duration duration, bool detachListeners = false) {
        if (detachListeners)
            fireAndDetachListeners(onCompleteListeners, task, duration);
        else
            fireListeners(onCompleteListeners, task, duration);
    }
    void fireErrorListeners (Task task, Throwable err, bool detachListeners = false) {
        if (detachListeners)
            fireAndDetachListeners(onErrorListeners, task, err);
        else
            fireListeners(onErrorListeners, task, err);
    }
    private void fireAndDetachListeners (Listener, Args...)(ref Listener[] listeners, Task task, Args args) {
        synchronized (mutex.write) {
            bool removed = false;
            for (auto i = listeners.length; i --> 0; ) {
                if (listeners[i].task == task)
                    listeners[i].dg(task, args);

                if (listeners[i].task == task || listener.removed) {
                    removed = true;
                    listeners[i] = move(listeners[$-1]);
                    --listeners.length;
                }
            }
            if (removed)
                listeners.sort();
        }
    }
    private void fireListeners (Listener, Args...)(ref Listener[] listeners, Task task, Args args) {
        bool needsCleanup = false;
        synchronized (mutex.read) {
            foreach (listener; listeners) {
                if (listener.removed)
                    needsCleanup = true;
                else if (listener.task == task)
                    listener.dg(task, args);
            }
        }
        if (needsCleanup) {
            synchronized (mutex.write) {
                cleanupListeners(listeners);
            }
        }
    }
    private void cleanupListeners (Listener)(ref Listener[] listeners) {
        for (auto i = listeners.length; i --> 0; ) {
            if (listeners[i].removed) {
                listeners[i] = move(listeners[$-1]);
                --listeners.length;
            }
        }
        listeners.sort();
    }
}

