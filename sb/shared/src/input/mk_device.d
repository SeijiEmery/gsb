module sb.input.mk_device;
import sb.events;
import gl3n.linalg;
import std.bitmanip;
import std.math: isNaN;
import std.format;

immutable uint SB_MAX_MOUSE_BUTTONS = 16;
immutable uint SB_NUM_KEYS          = 256;

enum MKPressAction : ubyte { RELEASED = 0, PRESSED = 1 }

struct MKInputFrame {
    double    dt;
    SbEvent[] events;
    vec2      mousePos, mouseDelta, scrollDelta;
    SbPressState[SB_MAX_MOUSE_BUTTONS] mouseBtnState;
    SbPressState[SB_NUM_KEYS]          keyState;

    auto ref buttons () { return mouseBtnState; }
    auto ref keys    () { return keyState;      }
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
    void registerMouseBtn ( double timestamp, uint btn, bool pressed ) nothrow @safe {
        omp(timestamp, btn, pressed);
    }
    // Register key press. For performance reasons, we don't take timestamps as we
    // don't presently have a need to record double / tripple tapping key actions
    // (this could change)
    void registerKeyAction ( SbKey key, bool pressed ) nothrow @safe {
        okp(key, pressed);
    }
    void registerMouseMotion ( vec2 newPos ) nothrow @safe {
        nextMousePos = newPos;
    }
    void registerMouseMotionDelta ( vec2 delta ) nothrow @safe {
        nextMousePos += delta;
    }
    void registerMouseScrollDelta ( vec2 delta ) nothrow @safe {
        scrollDelta += delta;
    }
    void registerCharInput ( dchar chr ) nothrow @trusted {
        events ~= SbEvent(SbRawCharEvent( chr ));
    }

    // Swap state + fetch last input frame; takes an external timestamp.
    void fetchInputFrame (IEventProducer eventList, ref SbKBMState state) {
        state.cursorDelta = vec2(
            (nextMousePos.x - state.cursorPos.x) * settings.mouse_sensitivity_x,
            (nextMousePos.y - state.cursorPos.y) * settings.mouse_sensitivity_y,
        );
        if ( nextMousePos != state.cursorPos ) {
            eventList.pushEvent(SbMouseMoveEvent( state.cursorPos, state.cursorDelta ));
        }
        state.cursorPos = nextMousePos;

        if (scrollDelta.x || scrollDelta.y) {
            scrollDelta.x *= settings.scroll_sensitivity_x;
            scrollDelta.y *= settings.scroll_sensitivity_y;
            eventList.pushEvent(SbScrollEvent( scrollDelta ));
        }
        state.scrollDelta = scrollDelta;
        scrollDelta = vec2(0, 0);

        state.buttons[0..$] = buttonState[0..$];
        state.keys   [0..$] = keyState[0..$];

        foreach (ref key; keyState)
            key.st_changed = false;

        foreach (ref btn; buttonState)
            btn.st_changed = false;

        foreach (event; events)
            eventList.pushEvent( event );
        events.length = 0;
    }

private:
    SbPressState [ SB_MAX_MOUSE_BUTTONS ] buttonState;
    double [ SB_MAX_MOUSE_BUTTONS ]       buttonTimestamps;
    SbPressState [ SbKey.max+1 ]            keyState;

    vec2 nextMousePos, scrollDelta;
    SbEvent[] events;

    //private struct PressInfo {
    //    bool pressed, lastPressed;
    //    uint pressCount  = 0, lastPressCount = 0;  
    //    double lastPress = double.nan;
    //}
    //PressInfo[ SB_MAX_MOUSE_BUTTONS ] buttonState;
    //bool     [ SB_NUM_KEYS ]          keyPressState, dirtyKeyState;

    private void omp (double t, uint btn, bool pressed) nothrow @trusted {
        if (btn >= SB_MAX_MOUSE_BUTTONS) { 
            import std.stdio;
            import std.exception; 
            assumeWontThrow( writefln("Invalid mouse button: %s > %s", btn, SB_MAX_MOUSE_BUTTONS) );
            return;
        }
        if (pressed == buttonState[btn].st_pressed)
            return;

        if (pressed) {
            buttonState[btn].st_pressed = true;
            buttonState[btn].st_changed = true;

            auto pressCount = buttonState[btn].st_pressCount;
            auto t0 = buttonTimestamps[btn]; 
            buttonTimestamps[btn] = t;

            if (pressCount == 0 || (t - t0) < settings.mouse_extraClickThreshold) {
                if (pressCount < settings.mouse_maxConsecutiveClicks) {
                    ++pressCount;
                } else {
                    final switch (settings.mouse_extraClickBehavior) {
                        case MKExtraClickBehavior.IGNORE: 
                            buttonState[btn].st_pressed = false;
                            return;
                        case MKExtraClickBehavior.REPEAT: break;
                        case MKExtraClickBehavior.WRAP:   pressCount = 1; break;
                        case MKExtraClickBehavior.IGNORE_1_THEN_WRAP:
                            buttonState[btn].st_pressCount = 0;
                            return;
                        case MKExtraClickBehavior.IGNORE_1_THEN_REPEAT:
                            if (++pressCount != settings.mouse_maxConsecutiveClicks+1)
                                return;
                    }
                }
            } else {
                pressCount = 1;
            }
            buttonState[btn].st_pressCount = pressCount;
            events ~= SbEvent(SbMouseButtonEvent( btn, pressed, cast(ubyte)pressCount ));

        } else {
            events ~= SbEvent( SbMouseButtonEvent( btn, pressed, cast(ubyte)buttonState[btn].st_pressCount ));
            buttonState[btn].st_pressed = pressed;

            if (t - buttonTimestamps[btn] < settings.mouse_extraClickThreshold) {
                // Took < T time to mouse up, so extend double click timer to end of mouse up
                buttonTimestamps[btn] = t;
            } else {
                // Exceeded timer, so reset click count
                buttonState[btn].st_pressCount = 0;
            }
        }
    }
    private void okp ( SbKey key, bool pressed ) nothrow @trusted {
        if (pressed != keyState[ key ].st_pressed) {
            keyState[ key ].st_pressed = pressed;
            keyState[ key ].st_changed = true;
            events ~= SbEvent(SbKeyEvent( key, pressed ));
        }
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
    auto   mouse_extraClickBehavior   = MKExtraClickBehavior.REPEAT;

    // Mouse sensitivity, etc
    double mouse_sensitivity_x = 1.0;
    double mouse_sensitivity_y = 1.0;

    double scroll_sensitivity_x = 1.0;
    double scroll_sensitivity_y = 1.0;
}





//
// TODO: Unit tests TBD.
//
