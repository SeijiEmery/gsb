module sb.events.window_events;
import gl3n.linalg;

struct SbWindowNeedsRefreshEvent {
    string window;
}
struct SbWindowResizeEvent {
    string window;
    vec2i prevSize, newSize;
}
struct SbWindowRescaleEvent {
    string window;
    vec2 prevScale, newScale;
}
struct SbWindowFocusChangeEvent {
    string   window;
    bool     hasFocus;
}
struct SbWindowMouseoverEvent {
    string   window;
    bool     hasMouseover;
}

struct SbWindowState {
    string window;
    vec2i size,  prevSize;
    vec2  scale, prevScale;

    bool  hasMouseFocus; // (mouseover)
    bool  hasInputFocus;
    bool  needsRefresh = false;
}

