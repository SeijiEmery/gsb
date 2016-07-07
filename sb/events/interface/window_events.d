module sb.events.window_events;

struct WindowResizeEvent {
    uint[2] prevSize;   // scaled
    uint[2] newSize;    // scaled
}
struct WindowRescaleEvent {
    double[2] prevScale;
    double[2] newScale;
}
struct WindowFocusChangeEvent {
    bool hasFocus;      // prevFocus: !hasFocus
}

