module sb.taskgraph.taskqueue;
//
// Public taskqueue interface. 
// Implemented in sb.taskgraph.impl.task_queue.
//
public import sb.taskgraph.impl.task;

ITaskQueue sbCreateTaskQueue ();
interface ITaskQueue {
    // Create + push task onto queue
    void pushTask (void delegate() action);
    void pushTask (void delegate() action, void delegate(ref SbTask) postAction);

    // Fetch and run a task (returning true / false for success).
    // Take care to ONLY call this from an appropriate thread / location.
    bool      fetchAndRunTask ();

    // Release all inactive (empty) segments; should bring free_mem_usage stat to 0
    void      purgeInactiveSegments ();

    // Debugging / introspection
    SbTaskQueueStats getStats ();
    string           getStringDump ();

    // Set task error handling func (default behavior is to just rethrow on error)
    void setErrorHandler (void delegate(SbTaskRef, Throwable));
}
void insertTask (Args...)(ITaskQueue queue, Args args) if (__traits(compiles, SbTask(args))) {
    queue.insertTask(SbTask(args));
}

// TaskQueue stats
struct SbTaskQueueStats {
    // Estimated memory usage of taskqueue, in bytes.
    // Should be fairly accurate.
    size_t mem_usage;
    size_t active_mem_usage;  // memory used for active task segments (pending, etc)
    size_t free_mem_usage;    // memory used for empty task segments (may be freed w/ purge())

    // Segment stats

    // total # segments
    uint   num_segments;

    // # of insert-locked segments (should be 1)
    uint   num_insert_locked_segments;

    // # of segments containing unacquired tasks
    uint   num_fetch_locked_segments;

    // # of segments containing that contain acquired, but not fully run tasks
    // (either not yet run, or run in progress)
    uint   num_run_locked_segments;

    // # of free (non-locked, unused) segments 
    // (will be retained + recycled instead of allocating new segments)
    uint   num_free_segments;

    // Task stats
    uint num_free_insert_slots;      // # free task slots in insert head
    uint num_pending_acquire_tasks;  // # of non-acquired tasks
    uint num_pending_run_tasks;      // # of acquired, but still running tasks
}



