module sb.events.input_events;
public import sb.keybindings;
public import sb.input.gamepad;
import gl3n.linalg;

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
    uint id;
    SbGamepadButton button;
    bool            pressed;
}
struct SbGamepadConnectionEvent {
    uint id;
    bool connected;
    const(SbGamepadProfileData)* profile;
}
struct SbGamepadAxisEvent {
    uint     id;
    float[]  axes;
}

//
// Per-frame input state
//

enum SbMouseButton : uint { 
    LMB = 0, BUTTON_1 = 0,
    RMB = 1, BUTTON_2 = 1,
    MMB = 2, BUTTON_3 = 2,
    BUTTON_4, BUTTON_5, BUTTON_6, BUTTON_7, BUTTON_8, 
    BUTTON_9, BUTTON_10, BUTTON_11, BUTTON_12, BUTTON_13,
    BUTTON_14, BUTTON_15, BUTTON_16
}

struct SbInputState {
    double dt, currentTime;
    SbKBMState kbm; alias kbm this;
    SbGamepadState[] gamepads;
}
struct SbKBMState {
    vec2 cursorPos = vec2(0, 0), cursorDelta = vec2(0, 0);
    vec2 scrollDelta = vec2(0, 0);

    SbPressState[ SbMouseButton.max+1 ] buttons;
    SbPressState[ SbKey.max+1 ]         keys;
}
struct SbGamepadState {
    uint id;
    bool connected = false;
    float       [ SbGamepadAxis.max+1 ]   axes;
    SbPressState[ SbGamepadButton.max+1 ] buttons;
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
    @property bool pressed  () nothrow @safe const { return st_pressed && st_changed; }
    @property bool released () nothrow @safe const { return !st_pressed && st_changed; }
    @property bool down     () nothrow @safe const { return st_pressed; }
    @property bool up       () nothrow @safe const { return !st_pressed; } 
    @property uint pressCount () nothrow @safe const { return st_pressed ? st_pressCount : 0; } 
}
