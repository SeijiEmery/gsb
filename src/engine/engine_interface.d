module gsb.engine.engine_interface;
import gsb.utils.signals;
import gsb.core.task: TaskGraph;

struct FrameTime {
    double   time = 0, dt = 0;
    double   framerate = 60;
}
class IEngine {
public:
    Signal!(IEngine) onInit;
    Signal!(IEngine) onShutdown;
    Signal!(IEngine) onFrameEnter;
    Signal!(IEngine) onFrameExit;

    abstract @property FrameTime currentTime ();
    abstract @property TaskGraph taskGraph ();
}











