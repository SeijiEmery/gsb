
interface IAction {
    void terminate ();

    @property SbTag tags ();
    @property void  tags (SbTag);

    ActionStatus status ();
    Throwable    error  ();  // non-null iff status == ERROR
}
enum ActionStatus { PENDING, RUNNING, ERROR, COMPLETE }

alias SbActionDelegate  = void delegate();
alias SbActionPredicate = bool delegate(SbAppContext);

struct SbTag { 
    ulong tags;
}


struct SbAttrib (T) {
    this (T value);
    this (T delegate() getter, void delegate(T) setter);

    T    get ();
    void set ();

    Signal!(T) onChanged;
}


enum SbThreadId : ubyte {
    ANY = 0, // any worker, including main thread, but excluding GL_THREAD
    MAIN_THREAD = 1,
    GL_THREAD   = 2,
    WORKER_1, WORKER_2, WORKER_3, WORKER_4, WORKER_5, WORKER_6, WORKER_7, WORKER_8, 
    WORKER_9, WORKER_10, WORKER_11, WORKER_12, WORKER_13, WORKER_14, WORKER_15
}
enum RunType : ubyte { ONCE, EACH_FRAME, INTERVAL, COND };

struct RunSemantics {
    SbThreadId targetThread = SbThreadId.ANY;
    SbRunType  runType      = SbRunType.ONCE;
}

struct FrameInfo {
    Duration appTime;
    double   time, dt;

    vec2i    windowSize;
    vec2     screenScale;
}


struct TimingStats { 
    uint count = 0; 
    double average, min, max;
}
interface IStatsCollection {
    void terminate ();

    @property void numSamples (uint);
    @property uint numSamples ();

    TimingStats lastSample ();
    TimingStats sampleRange (int, int);
    void iterSamples (int, int, void delegate(double));
}

struct SbEvent {}
alias  SbEventFilter = bool delegate(ref SbEvent);

interface IEventListener {
    void terminate();

    @property SbEventFilter filter ();
    @property void filter (SbEventFilter);
}

void gsb_atInit (void delegate(SbAppContext));

/// Application-level god-object.
/// Provides access to sandbox subsystems in a thread-safe manner, and will (hopefully)
/// eliminate global state from gsb.
///
class SbAppContext {
public:
    IAction schedule (RunSemantics, SbActionDelegate,  SbTag tag = SbTag.None);
    IAction schedule (RunSemantics, SbActionPredicate, SbActionDelegate, SbTag tag = SbTag.None);
    IAction schedule (RunSemantics, Duration,  SbActionDelegate, SbTag tag = SbTag.None);
    IAction schedule (RunSemantics, IAction[], SbActionDelegate, SbTag tag = SbTag.None);

    IStatsCollection collectStats (IAction);
    IStatsCollection collectStats (IAction[]);
    IStatsCollection collectStats (SbTag);

    void dispatchEvent (RunSemantics, SbEvent);
    IEventListener listenEvents (SbEvent, SbEventFilter);

    FrameInfo   getFrameInfo ();
    WindowInfo  getWindowInfo ();

    ref SbInputState getInputState ();

    @property SbFsContext fs ();
    @property SbGlContext gl ();
}

struct SbInputState {
    SbKeyboardState keys;
    SbMouseState    mouse;
    SbGamepadState[NUM_GAMEPADS] gamepads;
}

/// Will provide restricted, module-specific access to the gsb app context.
/// – Should follow restriction that all subsystem access be fully sandboxed, and all
/// resource use (registered actions, gl, fs, and ui resources, etc) be tagged or otherwise
/// monitored so they can be _unregistered_ / deleted at module exit.
/// – Should facilitate the easy creation of ui, and gl/client code execution as IActions
/// under strict control of the scheduling + monitoring actions.
/// - Should permit the following behavior:
///   - A module may be loaded, unloaded, or paused at any time
///   - Multiple instances of the same module may be running at once (but usually only one)
///   - Serialization should permit partial/complete state transfer from one running module
///     to another (hot-swapping).
///   - Reloading the same module multiple times over should not cause memory/resource leaks
///     or performance degredation.
///
class SbModuleContext {
    SbAppContext appContext;
    alias this appContext;    
}

class SbFsContext {
    IAction loadFile (string path, FsFileLoadDelegate, FsErrorDelegate);
    IAction loadFiles (string[] paths, FsFileLoadDelegate, FsErrorDelegate);
    IAction loadFiles (string[] basePaths, bool delegate(string) pred,
        FsFileLoadDelegate, FsErrorDelegate);

    bool exists (string path);

    string resolvePath (string path);
    void   makePathRecursive (string path);

    void createDefaultFile (string path, ubyte[] delegate());
    void createDefaultFiles (string path, ubyte[] delegate(string));
}

class SbGlContext {
    GlShaderHandle shader ();
    GlTextureHandle texture ();
}

enum ShaderType { VERTEX, FRAGMENT }
class GlShaderHandle {
    GlShaderHandle glversion (string);
    GlShaderHandle fromFile  (ShaderType type, string path);
    GlShaderHandle src       (ShaderType type, string contents);
    GlShaderRef    get ();
}
alias GlShaderRef = RefCounted!GlShader;
struct GlShader {

}

class GlTextureHandle {
    GlTextureHandle fromFile (string path);
    GlTextureRef    get ();
}
alias GlTextureRef = RefCounted!GlTexture;
struct GlTexture {

}
























