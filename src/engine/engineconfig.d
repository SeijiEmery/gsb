module gsb.engine.engineconfig;


// Log timing info for each frame. Useful when SHOW_TASK_WORKER_LOGGING is
// enabled, but will swamp logs.
public immutable bool SHOW_PER_FRAME_TASK_LOGGING = false;

// Log timing info for startup + shutdown; clearly delineates when init ends and
// when shutdown begins.
public immutable bool SHOW_INIT_TASK_LOGGING      = true;

// Log run info for each task that gets executed: the task's name (if it has one),
// file, line number, and which thread it was executed on. Very useful for debugging,
// but will completely swamp logs.
public immutable bool SHOW_TASK_WORKER_LOGGING    = false;

// Log main thread + gl thread sync messages -- useful for determining exactly when
// each runs, whether they're truly async or just interleaved (as they are now), and
// for ensuring that they stay synchronized (each has an integer frameId).
// Swamps logs since messages get printed every frame.
public immutable bool SHOW_MT_GL_SYNC_LOGGING     = false;
