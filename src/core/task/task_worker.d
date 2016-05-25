module gsb.task.task_worker;
import gsb.task.task;

class TimedTask {

}

private class TaskStore {
    TaskListenerStore listeners;
    Task[] tasks;
    //Task[] waitingTasks;
    Mutex mutex;

    this () {
        listeners = new TaskListenerStore();
        mutex     = new Mutex();
    }
    Task createTask (TaskDelegate dg, Task[] prereqs, TaskMetadata metadata) {
        return pushTask( new Task(dg, 0, TaskStatus.WAITING, prereqs, metadata), prereqs );
    }
    void runTask (Task task) {
        try {
            StopWatch sw; sw.start();
            task.dg();
            sw.stop();
            onTaskComplete(task, sw.peek.to!Duration);
        } catch (Throwable e) {
            onTaskError(task, e);
        }
    }

    Task fetchNextTask () {
        synchronized (mutex) {
            foreach (task; tasks) {
                if (task.status == TaskStatus.WAITING && task.canRun) {
                    task.status = TaskStatus.RUNNING;
                    return task;
                }
            }
        }
        return null;
    }
    private void onTaskComplete (Task task, Duration dur) {
        task.status = TaskStatus.COMPLETED;
        task.duration = dur;
        listeners.fireCompletionListeners(task, dur);
    }
    private void onTaskError    (Task task, Throwable err) {
        task.status = TaskStatus.ERROR;
        task.error  = err;
        listeners.fireErrorListeners(task, err);
    }
    private void removeTask (Task task) {
        foreach (prereq; task.prereqs)
            --prereq.priority;

        foreach (other; tasks) {
            foreach (i, prereq; other.prereqs) {
                if (task == prereq) {
                    other.prereqs[i] = null;
                }
            }
        }
    }
    private auto pushTask (Task task, Task[] prereqs) {
        synchronized (mutex) {
            foreach (prereq; prereqs)
                ++prereq.priority;

            if (prereqs.length) {
                waitingTasks ~= task;
            
            } else {
                tasks ~= task;
                if (task.priority)
                    tasks.sort!"a.priority"();
            }
        }
        return task;
    }
}































