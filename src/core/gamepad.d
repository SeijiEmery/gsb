
module gsb.core.gamepad;
import gsb.core.log;
import gsb.core.pseudosignals;
import Derelict.glfw3.glfw3;

// Directly ported from GLSandbox (c++ version)
alias GamepadButton = ubyte;
enum : ubyte {
    BUTTON_A = 0,
    BUTTON_B,
    BUTTON_X,
    BUTTON_Y,
    BUTTON_DPAD_UP,
    BUTTON_DPAD_DOWN,
    BUTTON_DPAD_LEFT,
    BUTTON_DPAD_RIGHT,
    BUTTON_LTRIGGER, // triggers can be treated as buttons
    BUTTON_RTRIGGER,
    BUTTON_LBUMPER,
    BUTTON_RBUMPER,
    BUTTON_LSTICK,
    BUTTON_RSTICK,
    BUTTON_START,
    BUTTON_SELECT,
    BUTTON_HOME
};
immutable size_t NUM_GAMEPAD_BUTTONS = 17;
    

alias GamepadAxis = ubyte;
enum : ubyte {
    AXIS_LX = 0,
    AXIS_LY,
    AXIS_RX,
    AXIS_RY,
    AXIS_LTRIGGER,
    AXIS_RTRIGGER,
    AXIS_DPAD_X,    // dpad can be interpreted as separate buttons or a 2d axis
    AXIS_DPAD_Y
};
immutable size_t NUM_GAMEPAD_AXES = 8;

enum GamepadProfile {
    NO_PROFILE = 0,
    UNKNOWN_PROFILE,
    XBOX_PROFILE,
    DUALSHOCK_3_PROFILE,
    DUALSHOCK_4_PROFILE
};

protected struct ProfileData {
    GamepadButton[] buttons; //size_t NUM_BUTTONS;
    GamepadAxis[]   axes;    //size_t NUM_AXES;
    double          LAXIS_DEADZONE;
    double          RAXIS_DEADZONE;
    double          TRIGGER_DEADZONE;
    bool FLIP_LY;
    bool FLIP_RY;
    bool CLAMP_TRIGGERS_TO_0_1;
}

protected struct GamepadProfiles {
    static immutable auto Dualshock4 = ProfileData (
        [
            BUTTON_X,  // square
            BUTTON_A,  // x
            BUTTON_B,  // circle
            BUTTON_Y,  // triangle
            BUTTON_LBUMPER,
            BUTTON_RBUMPER,
            BUTTON_LTRIGGER, // ds4 actually has triggers aliased as buttons, apparently
            BUTTON_RTRIGGER,
            BUTTON_START,
            BUTTON_SELECT, // share button
            BUTTON_LSTICK,
            BUTTON_RSTICK,
            BUTTON_HOME,
            BUTTON_SELECT, // center button
            BUTTON_DPAD_UP,
            BUTTON_DPAD_RIGHT,
            BUTTON_DPAD_DOWN,
            BUTTON_DPAD_LEFT,
        ],
        [
            AXIS_LX,
            AXIS_LY,
            AXIS_RX,
            AXIS_RY,
            AXIS_LTRIGGER,
            AXIS_RTRIGGER
        ],
        0.06, 0.06, 0.0,    // deadzones (left, right, triggers)
        false, false, false // flip LY, flip RY, clamp triggers to [0,1] (ds4 uses [0,1])
    );
    static immutable auto XboxController = ProfileData (
        [
            BUTTON_DPAD_UP,
            BUTTON_DPAD_DOWN,
            BUTTON_DPAD_LEFT,
            BUTTON_DPAD_RIGHT,
            BUTTON_START,
            BUTTON_SELECT,
            BUTTON_LSTICK,
            BUTTON_RSTICK,
            BUTTON_LBUMPER,
            BUTTON_RBUMPER,
            BUTTON_HOME,
            BUTTON_A,
            BUTTON_B,
            BUTTON_X,
            BUTTON_Y
        ],
        [
            AXIS_LX,
            AXIS_LY,
            AXIS_RX,
            AXIS_RY,
            AXIS_LTRIGGER,
            AXIS_RTRIGGER
        ],
        0.19, 0.19, 0.1,   // deadzones (left, right, triggers)
        false, false, true // flip LY, flip RY, clamp triggers to [0,1] (xbox controllers use [-1,1])
    );
}

protected GamepadProfile guessProfile (int numAxes, int numButtons) {
    bool match (string profile)() {
        return numAxes == mixin("GamepadProfiles."~profile~".axes.length") &&
            numButtons == mixin("GamepadProfiles."~profile~".buttons.length");
    }
    if (match!"Dualshock4") return GamepadProfile.DUALSHOCK_4_PROFILE;
    if (match!"XboxController") return GamepadProfile.XBOX_PROFILE;
    return GamepadProfile.UNKNOWN_PROFILE;
}

struct GamepadState {
    GamepadProfile profile;
    string         name;
    int            id;
    uint           naxes, nbuttons;

    float[NUM_GAMEPAD_AXES]    axes;
    ubyte[NUM_GAMEPAD_BUTTONS] buttons;
}

struct GamepadManager (size_t NUM_STATES = GLFW_JOYSTICK_LAST + 1) {
    private GamepadState[NUM_STATES] states;
    private GamepadState             lastState; // shared, combined version of all the above states

    Signal!(const(GamepadState)*) onDeviceDetected;
    Signal!(const(GamepadState)*) onDeviceRemoved;

    Signal!(GamepadButton) onGamepadButtonPressed;
    Signal!(GamepadButton) onGamepadButtonReleased;
    Signal!(float[])       onGamepadAxesUpdate;

    // Poll every device slot to determine what is connected and what isn't (emits onDeviceConnected/Removed)
    // Only call this every N frames, since glfwJoystickPresent(), etc., has quite a bit of overhead.
    void updateDeviceList () {
        import std.conv;

        log.write("Polling for devices");

        foreach (int i; 0 .. states.length) {
            bool active = glfwJoystickPresent(i) != 0;
            if (active && states[i].profile == GamepadProfile.NO_PROFILE) {
                int naxes, nbuttons;
                glfwGetJoystickAxes(i, &naxes);
                glfwGetJoystickButtons(i, &nbuttons);

                states[i].id      = i;
                states[i].profile = guessProfile(naxes, nbuttons);
                states[i].name    = glfwGetJoystickName(i).to!string();
                states[i].naxes   = naxes;
                states[i].nbuttons = nbuttons;
                onDeviceDetected.emit(&states[i]);
            }
            else if (!active && states[i].profile != GamepadProfile.NO_PROFILE) {
                onDeviceRemoved.emit(&states[i]);
                states[i].profile = GamepadProfile.NO_PROFILE;
            }
        }
    }

    // Call this once every frame: polls all attached joysticks + dispatches event signals
    // Note: we support multiple gamepads, but (since we're not doing multiplayer and multiple users would cause
    // a bunch of headaches), all gamepad input is consolidated and treated as "one" gamepad. This has the neat
    // effect that all gamepads are plug + play, and you could potentially plug in several and seamlessly switch
    // between them (and input is blended on a per-axis/button basis).
    void update () {
        import std.math: fabs;

        float[NUM_GAMEPAD_AXES]    sharedAxes;
        ubyte[NUM_GAMEPAD_BUTTONS] sharedButtons;

        foreach (ref state; states) {
            if (state.profile == GamepadProfile.NO_PROFILE || state.profile == GamepadProfile.UNKNOWN_PROFILE)
                continue;

            // Check that we're still connected, since updateDeviceList doesn't get called every frame
            bool active = glfwJoystickPresent(state.id) != 0;
            if (!active) {
                onDeviceRemoved.emit(&state);
                state.profile = GamepadProfile.NO_PROFILE;
                continue;
            }

            // Get profile
            const(ProfileData)* profile = null;
            switch (state.profile) {
                case GamepadProfile.DUALSHOCK_4_PROFILE: profile = &GamepadProfiles.Dualshock4; break;
                case GamepadProfile.XBOX_PROFILE:        profile = &GamepadProfiles.XboxController; break;
                default: break;
            }
            assert(profile != null);

            // Get gamepad data
            int naxes, nbuttons;
            float[] axes    = glfwGetJoystickAxes(state.id, &naxes)[0..state.naxes];
            ubyte[] buttons = glfwGetJoystickButtons(state.id, &nbuttons)[0..state.nbuttons];
            assert(naxes == state.naxes && nbuttons == state.nbuttons);

            // Update buttons
            foreach (k; 0 .. nbuttons) {
                state.buttons[profile.buttons[k]] = buttons[k];
                sharedButtons[profile.buttons[k]] |= buttons[k];
            }

            // Update axes
            foreach (k; 0 .. naxes) {
                state.axes[profile.axes[k]] = axes[k];
            }
            void setAxis (GamepadAxis axis, float value, float deadzone) {
                state.axes[axis] = 
                    fabs(value) > deadzone ? value : 0;
            }
            // Set left + right trigger inputs w/ deadzones, converting from [-1,1] to [0,1] if necessary
            setAxis(AXIS_LTRIGGER,
                profile.CLAMP_TRIGGERS_TO_0_1 ? state.axes[AXIS_LTRIGGER] * 0.5 + 0.5 : state.axes[AXIS_LTRIGGER],
                profile.TRIGGER_DEADZONE);
            setAxis(AXIS_RTRIGGER,
                profile.CLAMP_TRIGGERS_TO_0_1 ? state.axes[AXIS_RTRIGGER] * 0.5 + 0.5 : state.axes[AXIS_RTRIGGER],
                profile.TRIGGER_DEADZONE);

            // Set left + right stick inputs, applying deadzones and flipping axes if necessary
            setAxis(AXIS_LX, state.axes[AXIS_LX], profile.LAXIS_DEADZONE);
            setAxis(AXIS_LY, profile.FLIP_LY ? -state.axes[AXIS_LY] : state.axes[AXIS_LY], profile.LAXIS_DEADZONE);
            setAxis(AXIS_RX, state.axes[AXIS_RX], profile.RAXIS_DEADZONE);
            setAxis(AXIS_RY, profile.FLIP_RY ? -state.axes[AXIS_RY] : state.axes[AXIS_RY], profile.RAXIS_DEADZONE);

            // Set dpad inputs as an extra simulated axis
            setAxis(AXIS_DPAD_X, 
                state.buttons[BUTTON_DPAD_LEFT] ? -1.0 :
                state.buttons[BUTTON_DPAD_RIGHT] ? 1.0 : 0.0, 0.0);
            setAxis(AXIS_DPAD_Y,
                state.buttons[BUTTON_DPAD_DOWN] ? -1.0 :
                state.buttons[BUTTON_DPAD_UP]   ?  1.0 : 0.0, 0.0);

            // Update trigger buttons (triggers should also act as buttons)
            state.buttons[BUTTON_LTRIGGER] = state.axes[AXIS_LTRIGGER] > 0.0;
            state.buttons[BUTTON_RTRIGGER] = state.axes[AXIS_RTRIGGER] > 0.0;

            sharedButtons[BUTTON_LTRIGGER] |= state.buttons[BUTTON_LTRIGGER];
            sharedButtons[BUTTON_RTRIGGER] |= state.buttons[BUTTON_RTRIGGER];

            // Combine axis values
            foreach (k; 0 .. NUM_GAMEPAD_AXES) {
                if (sharedAxes[k] == 0 && state.axes[k] != 0) {
                    sharedAxes[k] = state.axes[k];
                }
            }
        }

        // Check merged state against last state + dispatch events
        foreach (i; 0 .. NUM_GAMEPAD_BUTTONS) {
            if (sharedButtons[i] && !lastState.buttons[i])
                onGamepadButtonPressed.emit(cast(GamepadButton)i);
            else if (lastState.buttons[i] && !sharedButtons[i])
                onGamepadButtonReleased.emit(cast(GamepadButton)i);
        }
        onGamepadAxesUpdate.emit(sharedAxes);

        lastState.axes = sharedAxes;
        lastState.buttons = sharedButtons;
    }
}
