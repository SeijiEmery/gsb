module sb.input.gamepad_device;
import sb.input.gamepad;
import sb.events;
import std.math;

class GamepadDevice {
public:
    uint id;
    const(SbGamepadProfileData)* profile = null;
    GamepadSettings settings;
    SbGamepadState  state;
final:
    this (uint id, const(SbGamepadProfileData)* profile) {
        this.id = id;
        this.profile = profile;
    }
    void setConnectionState ( bool connected, IEventProducer outEvents ) {
        if (connected != state.connected) {
            state.connected = connected;
            outEvents.pushEvent(SbGamepadConnectionEvent( id, connected, profile ));
        }
    }
    void update ( float[] rawAxes, ubyte[] rawButtons, IEventProducer outEvents ) {
        if (!profile) return;
        import std.stdio;
        import std.format;
        import std.range;
        import std.array;
        import std.algorithm: min, max;

        // Translate inputs
        bool[ SbGamepadButton.max+1 ] pressed = false;

        foreach (k; 0 .. rawButtons.length ) { // min(rawButtons.length, profile.buttons.length)) {
            pressed[profile.buttons[k]] |= cast(bool)rawButtons[k];
        }
        foreach (ref v; state.axes) { v = 0; }
        foreach (k, v; rawAxes) {
            state.axes[profile.axes[k]] += v;
        }

        void setAxis (SbGamepadAxis axis, float value, float deadzone) {
            state.axes[axis] = fabs(value) > deadzone * settings.deadzoneSensitivity[axis] ? value : 0;
        }
        auto clamp01 (float value) { return value * 0.5 + 0.5; }

        // Set left + right trigger inputs w/ deadzones, converting from [-1,1] to [0,1] if necessary
        setAxis(AXIS_LTRIGGER,
            profile.CLAMP_TRIGGERS_TO_0_1 ? clamp01(state.axes[AXIS_LTRIGGER]) : state.axes[AXIS_LTRIGGER],
            profile.TRIGGER_DEADZONE);
        setAxis(AXIS_RTRIGGER,
            profile.CLAMP_TRIGGERS_TO_0_1 ? clamp01(state.axes[AXIS_RTRIGGER]) : state.axes[AXIS_RTRIGGER],
            profile.TRIGGER_DEADZONE);

        // Set left + right stick inputs, applying deadzone + flipping axes if necessary
        setAxis(AXIS_LX, state.axes[AXIS_LX], profile.LAXIS_DEADZONE);
        setAxis(AXIS_LY, settings.flipLY ? -state.axes[AXIS_LY] : state.axes[AXIS_LY], profile.LAXIS_DEADZONE);
        setAxis(AXIS_RX, state.axes[AXIS_RX], profile.RAXIS_DEADZONE);
        setAxis(AXIS_RY, settings.flipRY ? -state.axes[AXIS_RY] : state.axes[AXIS_RY], profile.RAXIS_DEADZONE);

        // Set dpad inputs as an extra simulated axis
        state.axes[AXIS_DPAD_X] = state.axes[AXIS_DPAD_Y] = 0;
        if (pressed[BUTTON_DPAD_LEFT]) state.axes[AXIS_DPAD_X] -= 1.0;
        if (pressed[BUTTON_DPAD_RIGHT]) state.axes[AXIS_DPAD_X] += 1.0;
        if (pressed[BUTTON_DPAD_DOWN]) state.axes[AXIS_DPAD_Y] -= 1.0;
        if (pressed[BUTTON_DPAD_UP]) state.axes[AXIS_DPAD_Y] += 1.0;

        // Add LB/RB and LS/RS axes
        state.axes[AXIS_BUMPERS] = 0;
        if (pressed[BUTTON_LBUMPER]) state.axes[AXIS_BUMPERS] -= 1.0;
        if (pressed[BUTTON_RBUMPER]) state.axes[AXIS_BUMPERS] += 1.0;
        if (pressed[BUTTON_LSTICK]) state.axes[AXIS_HATS] -= 1.0;
        if (pressed[BUTTON_RSTICK]) state.axes[AXIS_HATS] += 1.0;

        // Add combined trigger axis
        state.axes[AXIS_TRIGGERS] = state.axes[AXIS_RTRIGGER] - state.axes[AXIS_LTRIGGER];

        // Update trigger buttons from axes
        // Note: trigger axes are / should always be clamped >= 0.
        pressed[BUTTON_LTRIGGER] = state.axes[AXIS_LTRIGGER] > settings.triggerButtonThreshold;
        pressed[BUTTON_RTRIGGER] = state.axes[AXIS_RTRIGGER] > settings.triggerButtonThreshold;

        // And fire events + finish updating state
        foreach (i; SbGamepadButton.min .. SbGamepadButton.max) {
            if (state.buttons[i].st_pressed != pressed[i]) {
                state.buttons[i].st_pressed = pressed[i];
                state.buttons[i].st_changed = true;
                outEvents.pushEvent(SbGamepadButtonEvent( id, i, pressed[i] ));
            } else {
                state.buttons[i].st_changed = false;
            }
        }
        outEvents.pushEvent(SbGamepadAxisEvent( id, state.axes ));
    }
}

struct GamepadSettings {
    float[ SbGamepadAxis.max+1 ] deadzoneSensitivity = 1.0;
    bool flipLY = false, flipRY = false;
    float triggerButtonThreshold = 0.0;
}




