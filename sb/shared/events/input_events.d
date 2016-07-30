module sb.events.input_events;
import gl3n.linalg;

struct SbMouseMoveEvent {
    vec2 pos, lastPos;
}
struct SbMouseButtonEvent {
    int button, action, mods;
}

struct SbMousePressEvent {
    uint button, pressCount = 1;
}
struct SbMouseDownEvent {
    uint button;
}
struct SbMouseUpEvent {
    uint button;
}


struct SbScrollInputEvent {
    vec2 delta;
}
struct SbKeyEvent {
    int key, scancode, mods;
    bool pressed;
}
struct SbRawCharEvent {
    dchar chr;
}
struct SbGamepadButtonEvent {
    int device, button, action;
}
struct SbGamepadAxisEvent {
    int device; float[] rawAxes;
}
struct SbGamepadConnectionEvent {
    int device, connected;
}

//struct MouseEvent {
//    float[2] pos,    prevPos;
//    float    scroll, prevScroll;
//    uint     buttonMask, prevButtonMask;
//}
//enum MouseButtonMask {
//    BUTTON_1 = 0x1, LEFT = 0x1,
//    BUTTON_2 = 0x2, RIGHT = 0x2,
//    BUTOTN_3 = 0x4, MIDDLE = 0x4,
//    BUTTON_4 = 0x8,
//    BUTTON_5 = 0x10,
//    BUTTON_6 = 0x20,
//    BUTTON_7 = 0x40,
//    BUTTON_8 = 0x80,
//}

//struct KeyEvent {
//    uint  keycode; 
//    dchar chr;
//    uint  modifiers;
//}
//enum KbModifierMask {
//    CTRL = 0x1, CMD = 0x2, META = 0x2, ALT = 0x4, SHIFT = 0x8,
//}
//struct KeyTextEvent {
//    string str;
//}

//struct GamepadConnectionEvent {}
//struct GamepadDisconnectionEvent {}
//struct GamepadButtonEvent {}
//struct GamepadAxisEvent   {}

