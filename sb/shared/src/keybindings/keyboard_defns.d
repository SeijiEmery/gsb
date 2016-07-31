module sb.keybindings.keyboard_defns;
import derelict.glfw3.glfw3;
import std.format;

// Our internal keycode enum. Uses USB HID bindings so we're
// not bound to glfw, etc., and includes translation from glfw
// key codes w/ glfwKeyToHID.
//
// Incidentally, this is the same format that SDL2 uses, so
// it should be fully compatible if we ever added that as a backend.
//
enum SbKey : ubyte {
    UNKNOWN = 0,
    KEY_A = 0x04,
    KEY_B = 0x05,
    KEY_C = 0x06,
    KEY_D = 0x07,
    KEY_E = 0x08,
    KEY_F = 0x09,
    KEY_G = 0x0A,
    KEY_H = 0x0B,
    KEY_I = 0x0C,
    KEY_J = 0x0D,
    KEY_K = 0x0E,
    KEY_L = 0x0F,
    KEY_M = 0x10,
    KEY_N = 0x11,
    KEY_O = 0x12,
    KEY_P = 0x13,
    KEY_Q = 0x14,
    KEY_R = 0x15,
    KEY_S = 0x16,
    KEY_T = 0x17,
    KEY_U = 0x18,
    KEY_V = 0x19,
    KEY_W = 0x1A,
    KEY_X = 0x1B,
    KEY_Y = 0x1C,
    KEY_Z = 0x1D,

    KEY_1 = 0x1E,
    KEY_2 = 0x1F,
    KEY_3 = 0x20,
    KEY_4 = 0x21,
    KEY_5 = 0x22,
    KEY_6 = 0x23,
    KEY_7 = 0x24,
    KEY_8 = 0x25,
    KEY_9 = 0x26,
    KEY_0 = 0x27,

    KEY_RETURN = 0x28,
    KEY_ESCAPE = 0x29,
    KEY_BACKSPACE = 0x2A,
    KEY_TAB    = 0x2B,
    KEY_SPACE  = 0x2C,

    KEY_MINUS        = 0x2D,
    KEY_EQUALS       = 0x2E,
    KEY_LEFTBRACKET  = 0x2F,
    KEY_RIGHTBRACKET = 0x30,
    KEY_BACKSLASH    = 0x31,
    KEY_NONUSHASH    = 0x32,
    KEY_SEMICOLON    = 0x33,
    KEY_APOSTROPHE   = 0x34,
    KEY_GRAVE        = 0x35,

    KEY_COMMA  = 0x36,
    KEY_PERIOD = 0x37,
    KEY_SLASH  = 0x38,

    KEY_CAPSLOCK = 0x39,
    KEY_F1 = 0x3A,
    KEY_F2 = 0x3B,
    KEY_F3 = 0x3C,
    KEY_F4 = 0x3D,
    KEY_F5 = 0x3E,
    KEY_F6 = 0x3F,
    KEY_F7 = 0x40,
    KEY_F8 = 0x41,
    KEY_F9 = 0x42,
    KEY_F10 = 0x43,
    KEY_F11 = 0x44,
    KEY_F12 = 0x45,
    
    KEY_PRINTSCREEN = 0x46,
    KEY_SCROLLLOCK  = 0x47,
    KEY_PAUSE       = 0x48,
    KEY_INSERT      = 0x49,
    KEY_HOME = 0x4A,
    KEY_PAGEUP = 0x4B,
    KEY_DELETE = 0x4C,
    KEY_END = 0x4D,
    KEY_PAGEDOWN = 0x4E,
    KEY_RIGHT = 0x4F,
    KEY_LEFT = 0x50,
    KEY_DOWN = 0x51,
    KEY_UP = 0x52,

    KEY_KP_NUMLOCKCLEAR = 0x53,
    KEY_KP_DIVIDE = 0x54,
    KEY_KP_MULTIPLY = 0x55,
    KEY_KP_MINUS = 0x56,
    KEY_KP_PLUS = 0x57,
    KEY_KP_ENTER = 0x58,
    KEY_KP_1 = 0x59,
    KEY_KP_2 = 0x5A,
    KEY_KP_3 = 0x5B,
    KEY_KP_4 = 0x5C,
    KEY_KP_5 = 0x5D,
    KEY_KP_6 = 0x5E,
    KEY_KP_7 = 0x5F,
    KEY_KP_8 = 0x60,
    KEY_KP_9 = 0x61,
    KEY_KP_0 = 0x62,
    KEY_KP_PERIOD = 0x63,
    KEY_NONUSBACKSLASH     = 0x64,
    KEY_UNUSED_APPLICATION = 0x65,
    KEY_UNUSED_POWER       = 0x66,
    KEY_KP_EQUALS = 0x67,

    KEY_F13 = 0x68,
    KEY_F14 = 0x69,
    KEY_F15 = 0x6A,
    KEY_F16 = 0x6B,
    KEY_F17 = 0x6C,
    KEY_F18 = 0x6D,
    KEY_F19 = 0x6E,
    KEY_F20 = 0x6F,
    KEY_F21 = 0x70,
    KEY_F22 = 0x71,
    KEY_F23 = 0x72,
    KEY_F24 = 0x73,
    KEY_UNUSED_EXECUTE  = 0x74,
    KEY_UNUSED_HELP     = 0x75,
    KEY_UNUSED_MENU     = 0x76,
    KEY_UNUSED_SELECT   = 0x77,
    KEY_UNUSED_STOP     = 0x78,
    KEY_UNUSED_AGAIN    = 0x79,
    KEY_UNUSED_UNDO     = 0x7A,
    KEY_UNUSED_CUT      = 0x7B,
    KEY_UNUSED_COPY     = 0x7C,
    KEY_UNUSED_PASTE    = 0x7D,
    KEY_UNUSED_FIND     = 0x7E,
    KEY_UNUSED_MUTE     = 0x7F,
    KEY_UNUSED_VOL_UP   = 0x80,
    KEY_UNUSED_VOL_DOWN = 0x81,
    KEY_UNUSED_LOCKING_CAPS_LOCK  = 0x82,
    KEY_UNUSED_LOCKING_NUM_LOCK   = 0x83,
    KEY_UNUSED_LOCKING_SCROLL_LOCK = 0x84,
    // ...to 0xE0...

    KEY_LCTRL  = 0xE0,
    KEY_LSHIFT = 0xE1,
    KEY_LALT   = 0xE2,
    KEY_LSUPER = 0xE3,  // cmd / windows-key / meta
    KEY_RCTRL  = 0xE4,
    KEY_RSHIFT = 0xE5,
    KEY_RALT   = 0xE6,
    KEY_RSUPER = 0xE7,

    // non-standard:
    KEY_CTRL  = 0xE8,
    KEY_SHIFT = 0xE9,
    KEY_ALT   = 0xEA,
    KEY_META  = 0xEB,
}

SbKey glfwKeyToHID (int key) @safe nothrow {
    import derelict.glfw3.glfw3;

    switch (key) {
        case GLFW_KEY_UNKNOWN: return SbKey.UNKNOWN;
        case GLFW_KEY_SPACE: return SbKey.KEY_SPACE;
        case GLFW_KEY_APOSTROPHE: return SbKey.KEY_APOSTROPHE;
        case GLFW_KEY_MINUS: return SbKey.KEY_MINUS;
        case GLFW_KEY_PERIOD: return SbKey.KEY_PERIOD;
        case GLFW_KEY_SLASH: return SbKey.KEY_SLASH;
        case GLFW_KEY_SEMICOLON: return SbKey.KEY_SEMICOLON;
        case GLFW_KEY_EQUAL: return SbKey.KEY_EQUALS;
        case GLFW_KEY_LEFT_BRACKET: return SbKey.KEY_LEFTBRACKET;
        case GLFW_KEY_BACKSLASH: return SbKey.KEY_BACKSLASH;
        case GLFW_KEY_RIGHT_BRACKET: return SbKey.KEY_RIGHTBRACKET;
        case GLFW_KEY_GRAVE_ACCENT:  return SbKey.KEY_GRAVE;
        case GLFW_KEY_WORLD_1: return SbKey.UNKNOWN; // FIXME?
        case GLFW_KEY_WORLD_2: return SbKey.UNKNOWN;
        case GLFW_KEY_ESCAPE: return SbKey.KEY_ESCAPE;
        case GLFW_KEY_ENTER: return SbKey.KEY_RETURN;
        case GLFW_KEY_TAB: return SbKey.KEY_TAB;
        case GLFW_KEY_BACKSPACE: return SbKey.KEY_BACKSPACE;
        case GLFW_KEY_INSERT: return SbKey.KEY_INSERT;
        case GLFW_KEY_DELETE: return SbKey.KEY_DELETE;
        case GLFW_KEY_RIGHT: return SbKey.KEY_RIGHT;
        case GLFW_KEY_LEFT: return SbKey.KEY_LEFT;
        case GLFW_KEY_DOWN: return SbKey.KEY_DOWN;
        case GLFW_KEY_UP: return SbKey.KEY_UP;
        case GLFW_KEY_PAGE_UP: return SbKey.KEY_PAGEUP;
        case GLFW_KEY_PAGE_DOWN: return SbKey.KEY_PAGEDOWN;
        case GLFW_KEY_HOME: return SbKey.KEY_HOME;
        case GLFW_KEY_END: return SbKey.KEY_END;
        case GLFW_KEY_CAPS_LOCK: return SbKey.KEY_CAPSLOCK;
        case GLFW_KEY_SCROLL_LOCK: return SbKey.KEY_SCROLLLOCK;
        case GLFW_KEY_NUM_LOCK: return SbKey.KEY_KP_NUMLOCKCLEAR;
        case GLFW_KEY_PRINT_SCREEN: return SbKey.KEY_PRINTSCREEN;
        case GLFW_KEY_PAUSE: return SbKey.KEY_PAUSE;
        case GLFW_KEY_KP_DECIMAL:  return SbKey.KEY_KP_PERIOD;
        case GLFW_KEY_KP_DIVIDE:   return SbKey.KEY_KP_DIVIDE;
        case GLFW_KEY_KP_MULTIPLY: return SbKey.KEY_KP_MULTIPLY;
        case GLFW_KEY_KP_SUBTRACT: return SbKey.KEY_KP_MINUS;
        case GLFW_KEY_KP_ADD: return SbKey.KEY_KP_PLUS;
        case GLFW_KEY_KP_ENTER: return SbKey.KEY_KP_ENTER;
        case GLFW_KEY_KP_EQUAL: return SbKey.KEY_KP_EQUALS;
        case GLFW_KEY_LEFT_SHIFT: return SbKey.KEY_LSHIFT;
        case GLFW_KEY_LEFT_CONTROL: return SbKey.KEY_LCTRL;
        case GLFW_KEY_LEFT_ALT: return SbKey.KEY_LALT;
        case GLFW_KEY_LEFT_SUPER: return SbKey.KEY_LSUPER;
        case GLFW_KEY_RIGHT_SHIFT: return SbKey.KEY_RSHIFT;
        case GLFW_KEY_RIGHT_CONTROL: return SbKey.KEY_RCTRL;
        case GLFW_KEY_RIGHT_ALT: return SbKey.KEY_RALT;
        case GLFW_KEY_RIGHT_SUPER: return SbKey.KEY_RSUPER;
        case GLFW_KEY_MENU: return SbKey.KEY_UNUSED_MENU;
        default:
    }
    if (key >= GLFW_KEY_A && key <= GLFW_KEY_Z)
        return cast(SbKey)(key - GLFW_KEY_A + SbKey.KEY_A);

    if (key >= GLFW_KEY_0 && key <= GLFW_KEY_9)
        return key == GLFW_KEY_0 ? SbKey.KEY_0 :
            cast(SbKey)(key - GLFW_KEY_1 + SbKey.KEY_1);
    if (key >= GLFW_KEY_KP_0 && key <= GLFW_KEY_KP_9)
        return key == GLFW_KEY_KP_0 ? SbKey.KEY_KP_0 :
            cast(SbKey)(key - GLFW_KEY_1 + SbKey.KEY_1);

    if (key >= GLFW_KEY_F1 && key <= GLFW_KEY_F12)
        return cast(SbKey)(key - GLFW_KEY_F1 + SbKey.KEY_F1);
    if (key >= GLFW_KEY_F13 && key <= GLFW_KEY_F25)
        return cast(SbKey)(key - GLFW_KEY_F13 + SbKey.KEY_F13);

    import std.stdio;
    import std.exception;

    assumeWontThrow(writefln("Unknown key %s (%s)", key, cast(dchar)key));
    return SbKey.UNKNOWN;
}
SbKey toKey (char chr) {
    if (chr >= 'a' && chr <= 'z')
        return cast(SbKey)(chr - 'a' + SbKey.KEY_A);
    if (chr >= 'A' && chr <= 'Z')
        return cast(SbKey)(chr - 'A' + SbKey.KEY_A);
    if (chr >= '1' && chr <= '9')
        return cast(SbKey)(chr - '1' + SbKey.KEY_1);
    if (chr == '0')
        return SbKey.KEY_0;

    return glfwKeyToHID( cast(int)chr );
}




