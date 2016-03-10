module gsb.core.frametime;
import Derelict.glfw3.glfw3;

private struct TimeState {
    @property double current () { return _currentTime; }
    @property double dt      () { return _deltaTime;   }
    @property ulong  frameCount () { return _frameCount; }

    void init () {
        synchronized {
            _currentTime = glfwGetTime();
            _frameCount  = 0;
        }
    }
    void updateFromRespectiveThread () {
        synchronized {
            double curTime = glfwGetTime();
            _deltaTime   = _currentTime - curTime;
            _currentTime = curTime;
            ++_frameCount;
        }
    }
    // Use this if reading from another thread (ie. stats) -- TimeState properties are not synchronized!
    TimeState syncRead () {
        synchronized {
            return TimeState(_currentTime, _deltaTime, _frameCount);
        }
    }
    private double _currentTime = 0.0, _deltaTime = 0.0;
    private ulong  _frameCount  = 0;
}

// Interfaces for dealing with per-frame time (these are updated exactly once per frame by their respective thread.
// Locking + synchronization should not be an issue, since it's (in theory) invalid for any thread to be working / reading
// and writing / updating, which is only supposed to be done inbetween frames. For reads from other threads we provide
// a syncRead method, since reading properties could give weird results if the read happened to occur during a frame update.
public __gshared TimeState g_eventFrameTime;
public __gshared TimeState g_graphicsFrameTime;

// Aliases for convenience
public @property double g_eventTime    () { return g_eventFrameTime.current; }
public @property double g_eventDt      () { return g_eventFrameTime.dt; }
public @property double g_graphicsTime () { return g_graphicsFrameTime.current; }
public @property double g_graphicsDt   () { return g_graphicsFrameTime.dt; }

