
module gsb.core.uievents;
import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.window;
import gsb.core.gamepad;
import gsb.core.frametime;
import gl3n.linalg;
import Derelict.glfw3.glfw3;

import std.variant;

// Events are ADTs (sum types). See std.variant and/or haskell.
alias UIEvent = Algebraic!(
    WindowResizeEvent, KeyboardEvent, TextEvent, MouseButtonEvent, 
    MouseMoveEvent, ScrollEvent, GamepadButtonEvent, GamepadAxisEvent
);

interface IEventCollector {
    UIEvent[] getEvents ();
}

struct WindowResizeEvent {
    vec2i newDimensions, prevDimensions;
    vec2  newScale, prevScale;    
}

struct KeyboardModifier {
    enum : ubyte {
        SHIFT = GLFW_MOD_SHIFT,
        CTRL  = GLFW_MOD_CONTROL,
        ALT   = GLFW_MOD_ALT,
        CMD   = GLFW_MOD_SUPER,
        META  = GLFW_MOD_SUPER,
    }
    static string toString (ubyte mods) {
        string[] s;
        if (mods & SHIFT) s ~= "SHIFT";
        if (mods & CTRL)  s ~= "CTRL";
        if (mods & ALT)   s ~= "ALT";
        version(OSX) { if (mods & CMD) s ~= "CMD"; }
        else         { if (mods & META) s ~= "META"; }
        return s.length ? s.join(" | ") : "NONE";
    }
}


// Wraps a glfw key event
struct KeyboardEvent {
    int              keycode = -1; // glfw key value (-1 => unknown; positive values map to ascii or special glfw values)
    KeyboardModifier mods = 0;     // bitmask of glfw modifiers
    double           keyDownTime = 0.0; // time since keydown event in seconds; set to 0.0 for keyPress events, -1.0 for keyRelease events, and something > 0.0 for keyDown eve

    @property bool keyDown () { return keyDownTime >= 0.0; }
    @property bool keyUp   () { return keyDownTime < 0.0; }
    @property bool keyPressed () { return keyDownTime == 0.0; }
    @property bool keyReleased () { return keyDownTime < 0.0; }

    @property bool shift   () { return mods & KeyboardModifier.SHIFT; }
    @property bool ctrl    () { return mods & KeyboardModifier.CTRL; }
    @property bool cmd     () { return mods & KeyboardModifier.CMD; }
    @property bool meta    () { return mods & KeyboardModifier.META; }
    @property bool alt     () { return mods & KeyboardModifier.ALT; }

    // Stringified representation of key code, including shift => alternate character codes
    @property string keystr () {
        switch (keycode) {
            case GLFW_KEY_UNKNOWN: return "UNKNOWN";
            case GLFW_KEY_SPACE:   return "SPACE";
            case GLFW_KEY_ESCAPE:  return "ESC";
            case GLFW_KEY_ENDER:   return "ENTER";
            case GLFW_KEY_DELETE:
            case GLFW_KEY_BACKSPACE: return "DELETE";
            case GLFW_KEY_INSERT:  return "INSERT";
            case GLFW_KEY_TAB:     return "TAB";
            case GLFW_KEY_LEFT:    return "LEFT";
            case GLFW_KEY_RIGHT:   return "RIGHT";
            case GLFW_KEY_UP:      return "UP";
            case GLFW_KEY_DOWN:    return "DOWN";
            case GLFW_KEY_PAGE_UP: return "PAGEUP";
            case GLFW_KEY_PAGE_DOWN: return "PAGEDOWN";
            case GLFW_KEY_HOME:    return "HOME";
            case GLFW_KEY_END:     return "END";
            case GLFW_KEY_CAPS_LOCK: return "CAPS_LOCK";
            case GLFW_KEY_SCROLL_LOCK: return "SCROLL_LOCK";
            case GLFW_KEY_NUM_LOCK:    return "NUM_LOCK";
            case GLFW_KEY_LEFT_SHIFT:   case GLFW_KEY_RIGHT_SHIFT: return "SHIFT";
            case GLFW_KEY_LEFT_CONTROL: case GLW_KEY_RIGHT_CONTROL: return "CTRL";
            case GLFW_KEY_LEFT_ALT: case GLFW_KEY_RIGHT_ALT: return "ALT";
            case GLFW_KEY_LEFT_SUPER: case GLFW_KEY_RIGHT_SUPER:
                version (OSX) { return "CMD"; } else { return "META"; }

            case '`': return shift ? "~" : "`";
            case '1': return shift ? "!" : "1";
            case '2': return shift ? "@" : "2";
            case '3': return shift ? "#" : "3";
            case '4': return shift ? "$" : "4";
            case '5': return shift ? "%" : "5";
            case '6': return shift ? "^" : "6";
            case '7': return shift ? "&" : "7";
            case '8': return shift ? "*" : "8";
            case '9': return shift ? "(" : "9";
            case '0': return shift ? ")" : "0";
            case '-': return shift ? "_" : "-";
            case '=': return shift ? "+" : "=";
            case '[': return shift ? "{" : "[";
            case ']': return shift ? "}" : "]";
            case '\\': return shift ? "|" : "\\";
            case ';': return shift ? ":" : ";";
            case '\'': return shift ? "'" : "\"";
            case ',': return shift ? "<" : ",";
            case '.': return shift ? ">" : ".";
            case '/': return shift ? "?" : "/";

            case GLFW_KEY_KP_DECIMAL: return ".";
            case GLFW_KEY_KP_DIVIDE:  return "/";
            case GLFW_KEY_KP_MULTIPLY: return "*";
            case GLFW_KEY_KP_SUBTRACT: return "-";
            case GLFW_KEY_KP_ADD:      return "+";
            case GLFW_KEY_KP_ENDER:    return "ENTER";
            case GLFW_KEY_KP_EQUAL:    return "=";
            default: {
                if (keycode >= 'a' && keycode <= 'z') {
                    return mods & KeyboardModifier.SHIFT ? keycode + 'A' - 'a' : keycode;
                }
                if (keycode >= GLFW_KEY_F1 && keycode <= GLFW_KEY_F25) {
                    return format("F%d", keycode - GLFW_KEY_F1 + 1);
                }
                if (keycode >= GLFW_KEY_KP_0 && keycode <= GLFW_KEY_KP_1) {
                    return '0' + keycode - GLFW_KEY_KP_0;
                }
            }
            return keycode > 0 ? format("%c", cast(dchar)keycode) : "";
        }
    }

    auto toString () {
        if (mods)
            return format("[KB Event %d(%s) %s]", keycode, keystr, KeyboardModifier.toString(mods));
        return format("KBEvent %d(%s)]", keycode, keystr);
    }
}

struct TextEvent {
    string text;
}

enum MouseButton {
    LMB = GLFW_MOUSE_BUTTON_LEFT,
    RMB = GLFW_MOUSE_BUTTON_RIGHT,
    MMB = GLFW_MOUSE_BUTTON_MIDDLE,
    BUTTON_4 = GLFW_MOUSE_BUTTON_4,
    BUTTON_5 = GLFW_MOUSE_BUTTON_5,
    BUTTON_6 = GLFW_MOUSE_BUTTON_6,
    BUTTON_7 = GLFW_MOUSE_BUTTON_7,
    BUTTON_8 = GLFW_MOUSE_BUTTON_8,
}

struct MouseButtonEvent {
    MouseButton button;
    KeyboardModifier modifiers;
    double      pressTime = 0.0;

    @property bool down    () { return pressTime >= 0.0; }
    @property bool pressed () { return pressTime == 0.0; }
    @property bool released () { return pressTime < 0.0; }

    @property bool isLMB () { return button == MouseButton.LMB; }
    @property bool isRMB () { return button == MouseButton.RMB; }
    @property bool isMMB () { return button == MouseButton.MMB; }

    @property bool shift () { return modifiers & KeyboardModifier.SHIFT; }
    @property bool cmd   () { return modifiers & KeyboardModifier.CMD; }
    @property bool meta  () { return modifiers & KeyboardModifier.META; }
    @property bool ctrl  () { return modifiers & KeyboardModifier.CTRL; }
    @property bool alt   () { return modifiers & KeyboardModifier.ALT; }
}

struct MouseMoveEvent {
    vec2 position;
    vec2 prevPosition;
}

struct ScrollEvent {
    vec2 dir;
}

struct GamepadButtonEvent {
    GamepadButton button;
    bool          pressed = true;
    @property bool released () { return !pressed; }
}

struct GamepadAxisEvent {
    float[NUM_GAMEPAD_AXES] axes;

    @property auto AXIS_LX () { return axes[GamepadAxis.AXIS_LX]; }
    @property auto AXIS_LY () { return axes[GamepadAxis.AXIS_LY]; }
    @property auto AXIS_RX () { return axes[GamepadAxis.AXIS_RX]; }
    @property auto AXIS_RY () { return axes[GamepadAxis.AXIS_RY]; }
    @property auto AXIS_LT () { return axes[GamepadAxis.AXIS_LTRIGGER]; }
    @property auto AXIS_RT () { return axes[GamepadAxis.AXIS_RTRIGGER]; }
    @property auto DPAD_X () { return axes[GamepadAxis.AXIS_DPAD_X]; }
    @property auto DPAD_Y () { return axes[GamepadAxis.AXIS_DPAD_Y]; }
}









































