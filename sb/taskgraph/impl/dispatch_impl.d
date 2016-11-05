module sb.taskgraph.impl.dispatch_impl;
import sb.taskgraph.dispatch_interface;
import sb.taskgraph.impl.task_queue;
import std.exception: enforce;
import core.sync.mutex;
import std.format;

private TaskQueue!SbTask[SbQueue.max] defaultQueues;
private TaskQueue!SbTask[SbQueue]     otherQueues;
private uint nextQueue = SbQueue.max;
private Mutex tqMutex;

shared static this () { tqMutex = new Mutex(); }

SbQueue sbCreateTaskQueue (SbQueue hint = SbQueue.NONE) {
    synchronized (tqMutex) {
        if (hint) {
            enforce(hint < SbQueue.max ?
                defaultQueues[hint] is null : hint !in otherQueues,
                format("Queue already exists: %s!", hint));

            if (hint < SbQueue.max)
                defaultQueues[hint] = new TaskQueue!SbTask();
            else
                otherQueues[hint] = new TaskQueue!SbTask();
            return hint;
        } else {
            while (cast(SbQueue)nextQueue in otherQueues)
                ++nextQueue;
            otherQueues[cast(SbQueue)nextQueue] = new TaskQueue!SbTask();
            return cast(SbQueue)nextQueue;
        }
    }
}
bool sbRemoveTaskQueue (SbQueue queue) {
    synchronized (tqMutex) {
        if (queue < SbQueue.max) {
            if (defaultQueues[queue]) {
                defaultQueues[queue] = null;
                return true;
            }
        } else {
            if (queue in otherQueues) {
                otherQueues.remove(queue);
                return true;
            }
        }
        return false;
    }
}
bool sbQueueExists (SbQueue queue) {
    if (queue < SbQueue.max)
        return defaultQueues[queue] !is null;
    return queue in otherQueues;
}
private auto getQueue (SbQueue queue) {
    assert(queue < SbQueue.max ? defaultQueues[queue] : queue in otherQueues,
        format("Invalid queue: %s", queue));
    return queue < SbQueue.max ? defaultQueues[queue] : otherQueues[queue];
}

SbTaskPtr sbPushTask (SbQueue target, void delegate() action) {
    return getQueue(target).insertTask(SbTask(action));
}
SbTaskPtr sbPushTask (SbQueue target, void delegate() action, void delegate(SbTaskPtr) postAction) {
    return getQueue(target).insertTask(SbTask(action, postAction));
}
bool sbExecQueue (SbQueue target) {
    auto task = getQueue(target);
    if (task) {
        auto err = task.tryRun();
        if (err) throw err;
        return true;
    }
    return false;
}


