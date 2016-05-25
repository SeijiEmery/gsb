module gsb.core.task.task;

alias TaskDelegate     = void delegate();
alias TaskCompletionDg = void delegate(Task, Duration);
alias TaskErrorDg      = void delegate(Task, Throwable);

enum  TaskStatus : ubyte {
    WAITING = 0, RUNNING, ERROR, COMPLETE
}
private immutable MAX_TASK_DEPS = 16;

class Task {
    TaskDelegate dg;
    ushort    priority = 0;
    TaskStatus status;

    TaskMetadata metadata;
    Task[MAX_TASK_DEPS] prereqs;

    this (TaskDelegate dg, ushort priority, TaskStatus status, Task[] prereqs, TaskMetadata metadata) {
        enforce(prereqs.length < MAX_TASK_DEPS, format("%s > %s! (%s)", prereqs.length, MAX_TASK_DEPS, metadata));

        this.dg = dg;
        this.priority = priority;
        this.status   = status;
        this.metadata = metadata;
        this.prereqs[0..prereqs.length] = prereqs;
    }
    void reset () {
        status = TaskStatus.WAITING;
    }

    // returns TaskStatus.COMPLETE if all prereqs are complete, TaskStatus.ERROR if any prereq failed,
    // or TaskStatus.WAITING otherwise (tasks are a mix of COMPLETE / RUNNING / WAITING)
    final TaskStatus prereqState () {
        bool complete = true;
        foreach (prereq; prereqs) {
            if (prereq) {
                switch (prereq.status) {
                    case TaskStatus.ERROR: return TaskStatus.ERROR;
                    case TaskStatus.COMPLETED: continue;
                    default: complete = false;
                }
            }
        }
        return complete ?
            TaskStatus.COMPLETE :
            TaskStatus.WAITING;
    }
    bool canRun () {
        assert(status == TaskStatus.WAITING);
        return prereqState == TaskStatus.COMPLETE;
    }
}
struct TaskMetadata {
    string file;
    uint   line;
    string prettyFunc;
    string taskName;
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

