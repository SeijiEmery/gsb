
module gsb.core.gamepad;
import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.uimanager;
import gsb.core.uievents;

import Derelict.glfw3.glfw3;


GamepadManager!(GLFW_JOYSTICK_LAST+1)* g_gamepadManager = null;

private class GamepadInputManager : IEventCollector {
    GamepadManager!(GLFW_JOYSTICK_LAST+1) mgr;
    UIEvent[] localEvents;
    ISlot[] slots;
    uint sinceLastPoll = 0;
    immutable uint POLL_EVERY = 300;

    this () {
        mgr.onDeviceDetected.connect((const(GamepadState)* state) {
            localEvents ~= GamepadConnectedEvent.create(state.id, state.profile, state.name, state.naxes, state.nbuttons);
        });
        mgr.onDeviceRemoved.connect((const(GamepadState)* state) {
            localEvents ~= GamepadDisconnectedEvent.create(state.id, state.profile, state.name, state.naxes, state.nbuttons);
        });
        mgr.onGamepadButtonPressed.connect((int id, GamepadButton button) {
            localEvents ~= GamepadButtonEvent.create(id, button, true);
        });
        mgr.onGamepadButtonReleased.connect((int id, GamepadButton button) {
            localEvents ~= GamepadButtonEvent.create(id, button, false);
        });
        mgr.onGamepadAxesUpdate.connect((int id, float[] axes) {
            localEvents ~= GamepadAxisEvent.create(id, axes[0..NUM_GAMEPAD_AXES]);
        });
        g_gamepadManager = &mgr;
    }
    ~this () {
        if (g_gamepadManager == &mgr)
            g_gamepadManager = null;
    }

    UIEvent[] getEvents () {
        localEvents.length = 0;
        if (sinceLastPoll == 0 || mgr.wantsConnectionsResent) {
            sinceLastPoll = POLL_EVERY - 1;
            mgr.updateDeviceList();
        } else {
            --sinceLastPoll;
        }
        mgr.update();
        return localEvents;
    }
}
static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerEventSource(
            new GamepadInputManager());
    });
}







// Directly ported from GLSandbox (c++ version)
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

// Okay, I'm duplicating this twice and the aliasing could cause bugs, but having to
// write GamepadButton.BUTTON_DPAD_RIGHT everywhere is not cool, and I _also_ need enum
// namespaces for the rest of the codebase...
enum GamepadButton : ubyte {
    BUTTON_A = 0, BUTTON_B, BUTTON_X, BUTTON_Y,
    BUTTON_DPAD_UP, BUTTON_DPAD_DOWN, BUTTON_DPAD_LEFT, BUTTON_DPAD_RIGHT,
    BUTTON_LTRIGGER, BUTTON_RTRIGGER, BUTTON_LBUMPER, BUTTON_RBUMPER,
    BUTTON_LSTICK, BUTTON_RSTICK,
    BUTTON_START, BUTTON_SELECT, BUTTON_HOME
};
enum GamepadAxis : ubyte {
    AXIS_LX = 0, AXIS_LY, AXIS_RX, AXIS_RY, AXIS_LTRIGGER, AXIS_RTRIGGER, AXIS_DPAD_X, AXIS_DPAD_Y
};

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
            GamepadButton.BUTTON_X,  // square
            GamepadButton.BUTTON_A,  // x
            GamepadButton.BUTTON_B,  // circle
            GamepadButton.BUTTON_Y,  // triangle
            GamepadButton.BUTTON_LBUMPER,
            GamepadButton.BUTTON_RBUMPER,
            GamepadButton.BUTTON_LTRIGGER, // ds4 actually has triggers aliased as buttons, apparently
            GamepadButton.BUTTON_RTRIGGER,
            GamepadButton.BUTTON_START,
            GamepadButton.BUTTON_SELECT, // share button
            GamepadButton.BUTTON_LSTICK,
            GamepadButton.BUTTON_RSTICK,
            GamepadButton.BUTTON_HOME,
            GamepadButton.BUTTON_SELECT, // center button
            GamepadButton.BUTTON_DPAD_UP,
            GamepadButton.BUTTON_DPAD_RIGHT,
            GamepadButton.BUTTON_DPAD_DOWN,
            GamepadButton.BUTTON_DPAD_LEFT,
        ],
        [
            GamepadAxis.AXIS_LX,
            GamepadAxis.AXIS_LY,
            GamepadAxis.AXIS_RX,
            GamepadAxis.AXIS_RY,
            GamepadAxis.AXIS_LTRIGGER,
            GamepadAxis.AXIS_RTRIGGER
        ],
        //0, 0, 0,
        0.06, 0.06, 0.0,    // deadzones (left, right, triggers)
        false, false, true // flip LY, flip RY, clamp triggers to [0,1] (ds4 uses [0,1])
    );
    static immutable auto XboxController = ProfileData (
        [
            GamepadButton.BUTTON_DPAD_UP,
            GamepadButton.BUTTON_DPAD_DOWN,
            GamepadButton.BUTTON_DPAD_LEFT,
            GamepadButton.BUTTON_DPAD_RIGHT,
            GamepadButton.BUTTON_START,
            GamepadButton.BUTTON_SELECT,
            GamepadButton.BUTTON_LSTICK,
            GamepadButton.BUTTON_RSTICK,
            GamepadButton.BUTTON_LBUMPER,
            GamepadButton.BUTTON_RBUMPER,
            GamepadButton.BUTTON_HOME,
            GamepadButton.BUTTON_A,
            GamepadButton.BUTTON_B,
            GamepadButton.BUTTON_X,
            GamepadButton.BUTTON_Y
        ],
        [
            GamepadAxis.AXIS_LX,
            GamepadAxis.AXIS_LY,
            GamepadAxis.AXIS_RX,
            GamepadAxis.AXIS_RY,
            GamepadAxis.AXIS_LTRIGGER,
            GamepadAxis.AXIS_RTRIGGER
        ],
        //0, 0, 0,
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
    ubyte[NUM_GAMEPAD_BUTTONS] lastButtons;
}

struct GamepadManager (size_t NUM_STATES = GLFW_JOYSTICK_LAST + 1) {
    private GamepadState[NUM_STATES] states;
    //private GamepadState             lastState; // shared, combined version of all the above states

    Signal!(const(GamepadState)*) onDeviceDetected;
    Signal!(const(GamepadState)*) onDeviceRemoved;

    Signal!(int, GamepadButton) onGamepadButtonPressed;
    Signal!(int, GamepadButton) onGamepadButtonReleased;
    Signal!(int, float[])       onGamepadAxesUpdate;

    private bool wantsConnectionsResent = false;

    // Poll every device slot to determine what is connected and what isn't (emits onDeviceConnected/Removed)
    // Only call this every N frames, since glfwJoystickPresent(), etc., has quite a bit of overhead.
    void updateDeviceList () {
        import std.conv;

        if (wantsConnectionsResent) 
            log.write("Resending connection events");
        else
            log.write("Scanning for devices...");
        
        foreach (int i; 0 .. states.length) {
            bool active = glfwJoystickPresent(i) != 0;
            if (active && (states[i].profile == GamepadProfile.NO_PROFILE || wantsConnectionsResent)) {
                int naxes, nbuttons;
                glfwGetJoystickAxes(i, &naxes);
                glfwGetJoystickButtons(i, &nbuttons);

                states[i].id      = i;
                states[i].profile = guessProfile(naxes, nbuttons);
                states[i].name    = glfwGetJoystickName(i).to!string();
                states[i].naxes   = naxes;
                states[i].nbuttons = nbuttons;
                states[i].buttons[0..NUM_GAMEPAD_BUTTONS] = 0;
                states[i].lastButtons[0..NUM_GAMEPAD_BUTTONS] = 0;
                states[i].axes[0..NUM_GAMEPAD_AXES] = 0;
                onDeviceDetected.emit(&states[i]);
            }
            else if (!active && states[i].profile != GamepadProfile.NO_PROFILE) {
                onDeviceRemoved.emit(&states[i]);
                states[i].profile = GamepadProfile.NO_PROFILE;
            }
        }
        wantsConnectionsResent = false;
    }

    void resendConnectionEvents () {
        wantsConnectionsResent = true;
        //foreach (int i; 0 .. states.length) {
        //    bool active = glfwJoystickPresent(i) != 0;
        //    if (active && states[i].profile != GamepadProfile.NO_PROFILE) {
        //        onDeviceDetected.emit(&states[i]);
        //        log.write("Resending connection %d", i);
        //    }
        //}
    }

    // Call this once every frame: polls all attached joysticks + dispatches event signals
    // Note: we support multiple gamepads, but (since we're not doing multiplayer and multiple users would cause
    // a bunch of headaches), all gamepad input is consolidated and treated as "one" gamepad. This has the neat
    // effect that all gamepads are plug + play, and you could potentially plug in several and seamlessly switch
    // between them (and input is blended on a per-axis/button basis).
    void update () {
        import std.math: fabs;

        //float[NUM_GAMEPAD_AXES]    sharedAxes = 0;
        //ubyte[NUM_GAMEPAD_BUTTONS] sharedButtons;

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
                //sharedButtons[profile.buttons[k]] |= buttons[k];
            }

            // Update axes
            foreach (k; 0 .. naxes) {
                state.axes[profile.axes[k]] = axes[k];
            }
            void setAxis (ubyte axis, float value, float deadzone) {
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

            foreach (i; 0 .. NUM_GAMEPAD_BUTTONS) {
                if (state.buttons[i] && !state.lastButtons[i])
                    onGamepadButtonPressed.emit(state.id, cast(GamepadButton)i);
                else if (state.lastButtons[i] && !state.buttons[i])
                    onGamepadButtonReleased.emit(state.id, cast(GamepadButton)i);
            }
            state.lastButtons[0..NUM_GAMEPAD_BUTTONS] = state.buttons[0..NUM_GAMEPAD_BUTTONS];
            onGamepadAxesUpdate.emit(state.id, state.axes);

            //sharedButtons[BUTTON_LTRIGGER] |= state.buttons[BUTTON_LTRIGGER];
            //sharedButtons[BUTTON_RTRIGGER] |= state.buttons[BUTTON_RTRIGGER];

            //// Combine axis values
            //foreach (k; 0 .. NUM_GAMEPAD_AXES) {
            //    if (sharedAxes[k] == 0 && state.axes[k] != 0) {
            //        sharedAxes[k] = state.axes[k];
            //    }
            //}
        }

        //// Check merged state against last state + dispatch events
        //foreach (i; 0 .. NUM_GAMEPAD_BUTTONS) {
        //    if (sharedButtons[i] && !lastState.buttons[i])
        //        onGamepadButtonPressed.emit(cast(GamepadButton)i);
        //    else if (lastState.buttons[i] && !sharedButtons[i])
        //        onGamepadButtonReleased.emit(cast(GamepadButton)i);
        //}
        //onGamepadAxesUpdate.emit(sharedAxes);

        //lastState.axes = sharedAxes;
        //lastState.buttons = sharedButtons;
    }
}
