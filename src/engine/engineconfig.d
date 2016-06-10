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

// Log when engine-thread paused / unpaused
public immutable bool SHOW_THREAD_PAUSE_RESUME_LOGGING = false;
// log when engine-thread created / killed
public immutable bool SHOW_THREAD_CREATE_TERM_LOGGING = false;

// test inter-thread messaging at engine startup (minor log flooding).
// If all is well nothing will crash (and should get a lot of "Hello World from X"
// and "ping back" messages; see engine.d).
public immutable bool RUN_THREAD_MESSAGING_SYSTEM_TEST = false;



// Log messages for when instances of subsystems, like UIComponentManagerInstance are created.
public immutable bool SHOW_SINGLETON_LOGGING = false;


// Misc logging: font file loading, gamepadMgr polling, window resize, etc
public immutable bool SHOW_FONT_MGR_LOGGING = false;
public immutable bool SHOW_GAMEPAD_DEVICE_POLLING = false;
public immutable bool SHOW_WINDOW_EVENT_LOGGING = false;
public immutable bool SHOW_BDR_LOGGING = false;


// Log UIComponent messages (registered / created / etc)
public immutable bool SHOW_COMPONENT_REGISTRATION = false;
public immutable bool SHOW_COMPONENT_ACTIVATION   = true;

// Log IEventCollector registration
public immutable bool SHOW_EVENT_SOURCE_LOGGING = false;

// Log GraphicsComponent registration + load/unload
public immutable bool SHOW_GRAPHICS_COMPONENT_LOGGING = false;


// Show gl texture logging
public immutable bool SHOW_GL_TEXTURE_OPERATIONS = true;
public immutable bool SHOW_GL_TEXTURE_BINDING    = false;
public immutable bool SHOW_GL_TEXTURE_RELEASE    = true;
public immutable bool SHOW_GL_TEXTURE_SKIPPED_OPERATIONS = false;


