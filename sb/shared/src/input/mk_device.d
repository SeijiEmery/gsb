module sb.input.mk_device;
immutable uint SB_MAX_MOUSE_BUTTONS = 16;
immutable uint SB_NUM_KEYS          = 256;

enum MKPressState : ubyte { UP, DOWN, PRESSED, RELEASED }

struct MKInputFrame {
    double    dt;
    SbEvent[] eventList;
    vec2      mousePos, mouseDelta, scrollDelta;
    MKPressState[SB_MAX_MOUSE_BUTTONS] mouseBtnState;
    MKPressState[SB_NUM_KEYS]          keyState;

    @auto ref buttons () { return mouseBtnState; }
    @auto ref keys    () { return keyState;      }
}

struct MKPressState {
private:
    mixin(bitfields!(
        bool, 1, "st_pressed",
        bool, 1, "st_changed",
        uint, 6, "st_pressCount"
    ));

    this (bool pressed, bool changed, uint pressCount = 1) {
        this.st_pressed = pressed;
        this.st_changed = changed;
        this.st_pressCount = pressCount;
    }
public:
    @property bool pressed  () { return st_pressed && st_changed; }
    @property bool released () { return !st_pressed && st_changed; }
    @property bool up       () { return st_pressed; }
    @property bool down     () { return !st_pressed; }
    @property uint pressCount () { return st_pressed ? st_pressCount : 0; }
}


// Mouse / Keyboard "device" implemented as a FSM that takes simple inputs and produces
// sophisticated SbEvent outputs suitable for a video game or game editor (detects double 
// clicks, complex key presses, etc).
//
// Used to transform simple, platform-based inputs into more complex ones (eg. glfw does
// not have very sophisticated input detection), but _also_ enables the "trivial" emulation
// of a mouse + keyboard device (or multiple mouse + keyboard device(s)), and is designed
// w/ unit testing in mind (and ditto for gamepad_device.d).
//
class MKInputDevice {
    // Settings stored as swappable, maybe-eventually-editor-editable PoD.
    public MKInputSettings settings;

final:
    // Register mouse button press w/ an external timestamp
    void registerMouseBtn ( double timestamp, uint btn, MKPressAction action ) {
        omp(timestamp, btn, action != MKPressAction.RELEASED);
    }
    // Register key press. For performance reasons, we don't take timestamps as we
    // don't presently have a need to record double / tripple tapping key actions
    // (this could change)
    void registerKeyAction ( int key, int scancode, MKPressAction action ) {
        okp(key, scancode, action != MKPressAction.RELEASED);
    }
    void registerMouseMotion ( vec2 newPos ) {
        nextMousePos = newPos;
    }
    void registerMouseMotionDelta ( vec2 delta ) {
        nextMousePos += delta;
    }
    void registerMouseScrollDelta ( vec2 delta ) {
        mouseCumulativeScrollDelta += delta;
    }

    // Swap state + fetch last input frame; takes an external timestamp.
    void fetchInputFrame (double timestamp, ref MKInputFrame frame) {
        if (nextMousePos != lastMousePos) {
            auto delta = nextMousePos - lastMousePos;
            delta.x *= settings.mouse_sensitivity_x;
            delta.y *= settings.mouse_sensitivity_y;
            eventList ~= SbMouseMoveEvent( lastMousePos, lastMousePos + delta );
        }
        if (mouseCumulativeScrollDelta.x || mouseCumulativeScrollDelta.y) {
            mouseCumulativeScrollDelta.x *= settings.scroll_sensitivity_x;
            mouseCumulativeScrollDelta.y *= settings.scroll_sensitivity_y;
            eventList ~= SbScrollInputEvent( mouseCumulativeScrollDelta );
        }

        frame.dt = isNaN( lastFrameTime ) ? 16e-3 : timestamp - lastFrameTime;
        frame.events[0..eventList.length] = eventList[0..$];
        frame.mousePos     = nextMousePos;
        frame.mouseDelta   = vec2(
            (nextMousePos.x - lastMousePos.x) * settings.mouse_sensitivity_x,
            (nextMousePos.y - lastMousePos.y) * settings.mouse_sensitivity_y);
        frame.scrollDelta  = mouseCumulativeScrollDelta;
        frame.mouseBtnState = buttonState;
        frame.keyState      = nextKeysPressed;

        foreach (i; 0 .. SB_MAX_MOUSE_BUTTONS) {
            frame.mouseBtnState[i] = MKPressState(
                buttonState[i].pressed,
                buttonState[i].pressed != buttonState[i].lastPressed,
                buttonState[i].pressCount,
            );
            buttonState[i].lastPressed = buttonState[i].pressed;
        }
        foreach (i; 0 .. SB_NUM_KEYS) {
            frame.keyState[i] = MKPressState(
                nextKeysPressed[i],
                nextKeysPressed[i] != lastKeysPressed[i]
            );
        }
        nextKeysPressed = lastKeysPressed;
    }

private:
    double    lastFrameTime = double.nan;
    SbEvent[] eventList;
    vec2      lastMousePos, nextMousePos;
    vec2      mouseCumulativeScrollDelta;

    private struct PressInfo {
        bool pressed, lastPressed;
        uint pressCount  = 0, lastPressCount = 0;  
        double lastPress = double.nan;
    }
    PressInfo[ SB_MAX_MOUSE_BUTTONS ] buttonState;
    bool     [ SB_NUM_KEYS ]          lastKeysPressed,  nextKeysPressed;

    private void omp (double t, uint btn, bool pressed) {
        assert( btn < SB_MAX_MOUSE_BUTTONS, format("mouse button %s > %s", btn, SB_MAX_MOUSE_BUTTONS));

        if (pressed && !mousePressed[btn]) {
            mousePressed[btn] = true;
            buttonState[btn].lastPress = t;
            eventList ~= SbEvent( SbMouseDownEvent(btn) );

            if (!buttonState[btn].pressCount ||
                t - buttonState[btn].lastPress < settings.mouse_extraClickThreshold
            ) {
                if (pressCount < settings.mouse_maxConsecutiveClicks) {
                    ++buttonState[btn].pressCount;
                } else {
                    final switch (settings.mouse_extraClickBehavior) {
                        case MKExtraClickBehavior.IGNORE: return;
                        case MKExtraClickBehavior.WRAP:   
                            buttonState[btn].pressCount = 1; 
                            break;
                        case MKExtraClickBehavior.IGNORE_1_THEN_WRAP:
                            buttonState[btn].pressCount = 0; 
                            return;
                        case MKExtraClickBehavior.REPEAT: break;
                        case MKExtraClickBehavior.IGNORE_1_THEN_REPEAT:
                            if ((buttonState[btn].pressCount += 1) == setting.mouse_maxConsecutiveClicks + 1)
                                return;
                    }
                }
                eventList ~= SbEvent(SbMousePressEvent(btn, buttonState[btn].pressCount));
            } else {
                eventList ~= SbEvent(SbMousePressEvent(btn, buttonState[btn].pressCount = 1));
            }
        } else if (!pressed && mousePressed[btn]) {
            eventList ~= SbEvent( SbMouseUpEvent(btn) );
            if (t - buttonState[btn].lastPress < settings.mouse_extraClickThreshold) {
                buttonState[btn].lastPress = t;
            } else {
                buttonState[btn].pressCount = 0;
            }
        }
    }
    private void okp ( uint key, uint scancode, bool pressed ) {
        eventList ~= SbEvent( SbKeyEvent( key, scancode, pressed ));

        assert(key < SB_NUM_KEYS, 
            format("Key exceeds range: %s (%s %s) > %s", 
                key, cast(dchar)key, scancode, SB_NUM_KEYS));
        nextKeysPressed[ key ] = pressed;
    }
}


// Specifies behavior of mouse clicks after reaching Nth click (eg. allow up to double click => N = 2)
enum MKExtraClickBehavior {
    IGNORE,               // ignore extra clicks beyond N
    WRAP,                 // wrap back to single clicks (and repeat) after N
    REPEAT,               // repeat (continue firing) the last click event
    IGNORE_1_THEN_WRAP,   // ignore the next click, then wrap
    IGNORE_1_THEN_REPEAT, // ignore the next click, then repeat
}

struct MKInputSettings {
    // Threshold, in seconds, within which consecutive mouse clicks
    // are interpreted as double / triple / etc clicks.
    double mouse_extraClickThreshold = 200e-3;

    // Upper bound for Nth click(s) + what to do after reaching N clicks.
    uint   mouse_maxConsecutiveClicks = 3;
    auto   mouse_extraClickBehavior  = MKExtraClickBehavior.REPEAT;

    // Mouse sensitivity, etc
    double mouse_sensitivity_x = 1.0;
    double mouse_sensitivity_y = 1.0;

    double scroll_sensitivity_x = 1.0;
    double scroll_sensitivity_y = 1.0;
}





//
// TODO: Unit tests TBD.
//
