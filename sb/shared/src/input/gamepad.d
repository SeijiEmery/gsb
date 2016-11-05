module sb.input.gamepad;

enum SbGamepadButton : ubyte {
    A = 0, B, X, Y, 
    DPAD_UP, DPAD_DOWN, DPAD_LEFT, DPAD_RIGHT,
    LTRIGGER, RTRIGGER, LBUMPER, RBUMPER,
    LSTICK, RSTICK, START, SELECT, HOME
}
public auto immutable BUTTON_A = SbGamepadButton.A;
public auto immutable BUTTON_B = SbGamepadButton.B;
public auto immutable BUTTON_X = SbGamepadButton.X;
public auto immutable BUTTON_Y = SbGamepadButton.Y;
public auto immutable BUTTON_DPAD_UP = SbGamepadButton.DPAD_UP;
public auto immutable BUTTON_DPAD_DOWN = SbGamepadButton.DPAD_DOWN;
public auto immutable BUTTON_DPAD_LEFT = SbGamepadButton.DPAD_LEFT;
public auto immutable BUTTON_DPAD_RIGHT = SbGamepadButton.DPAD_RIGHT;
public auto immutable BUTTON_LTRIGGER = SbGamepadButton.LTRIGGER;
public auto immutable BUTTON_RTRIGGER = SbGamepadButton.RTRIGGER;
public auto immutable BUTTON_LBUMPER = SbGamepadButton.LBUMPER;
public auto immutable BUTTON_RBUMPER = SbGamepadButton.RBUMPER;
public auto immutable BUTTON_LSTICK = SbGamepadButton.LSTICK;
public auto immutable BUTTON_RSTICK = SbGamepadButton.RSTICK;
public auto immutable BUTTON_START = SbGamepadButton.START;
public auto immutable BUTTON_SELECT = SbGamepadButton.SELECT;
public auto immutable BUTTON_HOME = SbGamepadButton.HOME;

enum SbGamepadAxis : ubyte {
    LX = 0, LY, RX, RY, LTRIGGER, RTRIGGER, DPAD_X, DPAD_Y, TRIGGERS, BUMPERS, HATS,
}
public auto immutable AXIS_LX = SbGamepadAxis.LX;
public auto immutable AXIS_LY = SbGamepadAxis.LY;
public auto immutable AXIS_RX = SbGamepadAxis.RX;
public auto immutable AXIS_RY = SbGamepadAxis.RY;
public auto immutable AXIS_LTRIGGER = SbGamepadAxis.LTRIGGER;
public auto immutable AXIS_RTRIGGER = SbGamepadAxis.RTRIGGER;
public auto immutable AXIS_DPAD_X = SbGamepadAxis.DPAD_X;   // fake axes for dpad
public auto immutable AXIS_DPAD_Y = SbGamepadAxis.DPAD_Y;
public auto immutable AXIS_TRIGGERS = SbGamepadAxis.TRIGGERS; // combined LT + RT axes
public auto immutable AXIS_BUMPERS = SbGamepadAxis.BUMPERS;   // fake axes for LB/RB + LS/RS
public auto immutable AXIS_HATS = SbGamepadAxis.HATS;


enum SbGamepadProfile {
    NO_PROFILE = 0,
    UNKNOWN_PROFILE,
    XBOX_PROFILE,
    //DUALSHOCK_3_PROFILE,
    DUALSHOCK_4_PROFILE
};

struct SbGamepadProfileData {
    SbGamepadButton[] buttons; //size_t NUM_BUTTONS;
    SbGamepadAxis[]   axes;    //size_t NUM_AXES;
    double          LAXIS_DEADZONE;
    double          RAXIS_DEADZONE;
    double          TRIGGER_DEADZONE;
    bool FLIP_LY;
    bool FLIP_RY;
    bool CLAMP_TRIGGERS_TO_0_1;
}

private struct GamepadProfiles {
    static immutable auto Dualshock4 = SbGamepadProfileData (
        [
            SbGamepadButton.X,  // square
            SbGamepadButton.A,  // x
            SbGamepadButton.B,  // circle
            SbGamepadButton.Y,  // triangle
            SbGamepadButton.LBUMPER,
            SbGamepadButton.RBUMPER,
            SbGamepadButton.LTRIGGER, // ds4 actually has triggers aliased as buttons, apparently
            SbGamepadButton.RTRIGGER,
            SbGamepadButton.SELECT, // share button
            SbGamepadButton.START,
            SbGamepadButton.LSTICK,
            SbGamepadButton.RSTICK,
            SbGamepadButton.HOME,
            SbGamepadButton.SELECT, // center button
            SbGamepadButton.DPAD_UP,
            SbGamepadButton.DPAD_RIGHT,
            SbGamepadButton.DPAD_DOWN,
            SbGamepadButton.DPAD_LEFT,
        ],
        [
            SbGamepadAxis.LX,
            SbGamepadAxis.LY,
            SbGamepadAxis.RX,
            SbGamepadAxis.RY,
            SbGamepadAxis.LTRIGGER,
            SbGamepadAxis.RTRIGGER
        ],
        //0, 0, 0,
        0.06, 0.06, 0.0,    // deadzones (left, right, triggers)
        false, false, true // flip LY, flip RY, clamp triggers to [0,1] (ds4 uses [0,1])
    );
    static immutable auto XboxController = SbGamepadProfileData (
        [
            SbGamepadButton.DPAD_UP,
            SbGamepadButton.DPAD_DOWN,
            SbGamepadButton.DPAD_LEFT,
            SbGamepadButton.DPAD_RIGHT,
            SbGamepadButton.START,
            SbGamepadButton.SELECT,
            SbGamepadButton.LSTICK,
            SbGamepadButton.RSTICK,
            SbGamepadButton.LBUMPER,
            SbGamepadButton.RBUMPER,
            SbGamepadButton.HOME,
            SbGamepadButton.A,
            SbGamepadButton.B,
            SbGamepadButton.X,
            SbGamepadButton.Y
        ],
        [
            SbGamepadAxis.LX,
            SbGamepadAxis.LY,
            SbGamepadAxis.RX,
            SbGamepadAxis.RY,
            SbGamepadAxis.LTRIGGER,
            SbGamepadAxis.RTRIGGER
        ],
        //0, 0, 0,
        0.19, 0.19, 0.1,   // deadzones (left, right, triggers)
        false, false, true // flip LY, flip RY, clamp triggers to [0,1] (xbox controllers use [-1,1])
    );
}

SbGamepadProfile guessGamepadProfile (int numAxes, int numButtons) {
    bool match (string profile)() {
        return numAxes == mixin("GamepadProfiles."~profile~".axes.length") &&
            numButtons == mixin("GamepadProfiles."~profile~".buttons.length");
    }
    if (match!"Dualshock4")     return SbGamepadProfile.DUALSHOCK_4_PROFILE;
    if (match!"XboxController") return SbGamepadProfile.XBOX_PROFILE;
    return SbGamepadProfile.UNKNOWN_PROFILE;
}
const(SbGamepadProfileData)* getProfileData (SbGamepadProfile id) {
    final switch (id) {
        case SbGamepadProfile.DUALSHOCK_4_PROFILE: return &GamepadProfiles.Dualshock4;
        case SbGamepadProfile.XBOX_PROFILE:    return &GamepadProfiles.XboxController;
        case SbGamepadProfile.UNKNOWN_PROFILE: return null;
        case SbGamepadProfile.NO_PROFILE: assert(0);
    }
    assert(0);
}
auto sbFindMatchingGamepadProfile (int numAxes, int numButtons) {
    return getProfileData(guessGamepadProfile(numAxes, numButtons));
} 





