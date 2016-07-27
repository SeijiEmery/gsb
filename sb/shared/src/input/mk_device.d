module sb.input.mk_device;

immutable uint SB_MAX_MOUSE_BUTTONS = 16;
immutable uint SB_NUM_KEYS          = 256;

enum MKPressAction { RELEASED = 0, PRESSED }

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

    // Swap state + fetch last input frame; takes an external timestamp.
    MKInputFrame fetchInputFrame (double timestamp) {

    }

private:
    struct PressInfo {
        uint pressCount  = 0;  
        double lastPress = double.nan;
    }
    PressInfo[ SB_MAX_MOUSE_BUTTONS ] buttonState;
    bool     [ SB_MAX_MOUSE_BUTTONS ] mousePressed;
    bool     [ SB_NUM_KEYS ]          lastKeysPressed,  nextKeysPressed;

    SbEvent[] eventList;

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
