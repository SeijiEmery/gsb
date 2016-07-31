module sb.events.input_events;
public import sb.keybindings;
import gl3n.linalg;

//
// Sb input definitions
//
struct SbGamepadDevice {
    uint   id;
    string name;
    uint num_buttons;
    uint num_axes;
}
alias SbGamepadDeviceRef = const(SbGamepadDevice)*;

immutable auto SB_MAX_MOUSE_BUTTONS = 16; // max mouse buttons...
immutable auto SB_MAX_GAMEPAD_BUTTONS = 20;
immutable auto SB_MAX_GAMEPAD_AXES    = 10;

enum SbGamepadButton { A, B, X, Y, }

//
// Input Events
//

struct SbMouseMoveEvent { vec2 pos, delta; }
struct SbScrollEvent    { vec2 delta;      }
struct SbKeyEvent {
    SbKey key;
    bool  pressed;
}
struct SbRawCharEvent {
    dchar chr;
}

struct SbMouseButtonEvent {
    uint  button;
    bool  pressed;
    ubyte clicks = 1;
}
struct SbGamepadButtonEvent {
    SbGamepadDeviceRef device;
    SbGamepadButton button;
    bool            pressed;
}
struct SbGamepadConnectionEvent {
    SbGamepadDeviceRef device;
    bool            connected;
}
struct SbGamepadAxisEvent {
    SbGamepadDeviceRef device;
    float[]         axes;
}

//
// Per-frame input state
//

struct SbKBMState {
    vec2 cursorPos, cursorDelta;
    vec2 scrollDelta;

    SbPressState[ SB_MAX_MOUSE_BUTTONS ] buttons;
    SbPressState[ SbKey.max ]            keys;
}
struct SbGamepadState {
    SbGamepadDeviceRef device;

    float       [ SB_MAX_GAMEPAD_AXES ]    axes;
    SbPressState[ SB_MAX_GAMEPAD_BUTTONS ] buttons;
}

// Encapsulates press state for various buttons + keys w/ 4 states:
// – pressed: button/key down + changed from up state
// – released: button/key up  + changed from down state
// – down: button/key down (includes pressed)
// – up:   button/key up   (includes released)
// 
// pressCount: used by mouse buttons to signal single / double / triple clicks.
//  – single cick:  pressed && pressCount == 1
//  - double click: pressed && pressCount == 2
//  - nth    click: pressed && pressCount == n
//
// Single / double / etc detection is provided by MKDevice and may be configured
// using MKDeviceSettings (see IPlatform / MKDevice)
//
struct SbPressState {
    import std.bitmanip;
    mixin(bitfields!(
        bool, "st_pressed", 1,
        bool, "st_changed", 1,
        uint, "st_pressCount", 6
    ));

    this (bool pressed, bool changed, uint pressCount = 1) {
        this.st_pressed = pressed;
        this.st_changed = changed;
        this.st_pressCount = pressCount;
    }
public:
    @property bool pressed  () nothrow @safe { return st_pressed && st_changed; }
    @property bool released () nothrow @safe { return !st_pressed && st_changed; }
    @property bool up       () nothrow @safe { return st_pressed; }
    @property bool down     () nothrow @safe { return !st_pressed; } 
    @property uint pressCount () nothrow @safe { return st_pressed ? st_pressCount : 0; } 
}
