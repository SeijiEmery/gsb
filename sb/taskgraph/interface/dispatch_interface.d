module sb.taskgraph.dispatch_interface;
public import sb.taskgraph.impl.task;

alias SbTaskPtr = SbTask*;
enum SbQueue : uint {
    NONE = 0, ASYNC, PER_FRAME, GT_ONLY, MT_ONLY
}
// create / unregister target queue (must do this for default queues)
SbQueue sbCreateTaskQueue (SbQueue hint = SbQueue.NONE);
bool    sbRemoveTaskQueue (SbQueue);
bool    sbQueueExists     (SbQueue);

// push task onto target queue
SbTaskPtr sbPushTask (SbQueue target, void delegate() action, void delegate(SbTaskPtr) postAction);
SbTaskPtr sbPushTask (SbQueue target, void delegate() action);

// exec one task from target queue; returns true if did work.
// This should ONLY be called from the appropriate thread (eg. SbQueue.GT_ONLY => only call from graphics thread!)
bool sbExecQueue (SbQueue target);
//SbTaskQueueStats sbGetQueueStats (SbTaskQueueId);

