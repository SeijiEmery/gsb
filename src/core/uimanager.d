
module gsb.core.uimanager;
import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.window;
import gsb.core.gamepad;

import gl3n.linalg;


protected class EventContext {

}
protected interface EventCondition {
    bool passes (EventContext ctx);
}
protected interface DeviceButtonOrKey {

}
alias void delegate(UIEvent) EventCallback;

public interface UIEvents {
    void connect (DeviceButtonOrKey, EventCondition, EventCallback);
    void connect (DeviceButtonOrKey, EventCondition, EventCondition, EventCallback);
    void connect (DeviceButtonOrKey, EventCondition, EventCondition, EventCondition, EventCallback);
    void connect (DeviceButtonOrKey, EventCondition, EventCondition, EventCondition, EventCallback);
}

public struct MouseButtons {
    static DeviceButtonOrKey LEFT = new class DeviceButtonOrKey {};
    static DeviceButtonOrKey RIGHT = new class DeviceButtonOrKey {};
    static DeviceButtonOrKey MIDDLE = new class DeviceButtonOrKey {};
}
public struct Keys {
    static DeviceButtonOrKey ascii (char key) {
        return new class DeviceButtonOrKey {};
    }
}
public struct GamepadButtons {
    static DeviceButtonOrKey button (GamepadButton btn) {
        return new class DeviceButtonOrKey {};
    }
}

public struct KeyboardModifiers {
    private static class KeyboardModifer : DeviceButtonOrKey {
        final bool passes (EventContext _) { return check(); }
        abstract bool check ();

        auto opBinary (string op)(KeyboardModifer km) {
            KeyboardModifer a = this, b = km;
            static if (op == "|") return new class KeyboardModifer { bool check () { return a.check() || b.check(); }};
            else static if (op == "&") return new class KeyboardModifer { bool check () { return a.check() && b.check(); }};
            else static assert(0, "Operator "~op~" not implemented");
        }
    }
    static auto ANY = new class KeyboardModifer { bool check () { return true; } };
    static auto CTRL = new class KeyboardModifer { 
        bool check () { return g_activeKeyboardModifiers & KEYBOARD_MODIFIERS_CTRL; } 
    };
    static auto CMD  = new class KeyboardModifer {
        bool check () { return g_activeKeyboardModifiers & KEYBOARD_MODIFIERS_CMD; } };
    };
    static auto ALT  = new class KeyboardModifer {
        bool check () { return g_activeKeyboardModifiers & KEYBOARD_MODIFIERS_ALT; }
    };
    static auto SHIFT = new class KeyboardModifer {
        bool check () { return g_activeKeyboardModifiers & KEYBOARD_MODIFIERS_SHIFT; }
    };
}

public struct PressCondition {
    static auto PRESSED = new class EventCondition {
        final bool passes (EventContext ctx) {
            return ctx.flags & EVT_PRESSED;
        }
    };
    static auto RELEASED = new class EventCondition {
        final bool passes (EventContext ctx) {
            return ctx.flags & EVT_RELEASED;
        }
    };
    private static class Timer : EventCondition {
        double duration;
        double lastTime = 0.0;
        final bool passes (EventContext _) {
            if (g_currentTime >= lastTime + seconds) {
                lastTime = g_currentTime;
                return true;
            } else {
                return false;
            }
        }
    }
    static auto EVERY_SECOND (double seconds) {
        return new Timer(seconds);
    }
    static auto EVERY_MS (double ms) {
        return new Timer(ms * 1e-3);
    }
}



protected class UIEventsInstance : UIEvents {
    void connect (DeviceButtonOrKey btn, EventCondition cond, EventCallback cb) {

    }
    void connect (DeviceButtonOrKey btn, EventCondition cond1, EventCondition cond2, EventCallback cb) {
        connect(btn, merge(cond1, cond2), cb);
    }
    void connect (DeviceButtonOrKey btn, EventCondition cond1, EventCondition cond2, EventCondition cond3, EventCallback cb) {
        connect(btn, merge(cond1, merge(cond2, cond3)), cb);
    }
    void connect (DeviceButtonOrKey btn, EventCondition cond1, EventCondition cond2, EventCondition cond3, EventCondition cond4, EventCallback cb) {
        connect(btn, merge(merge(cond1, cond2), merge(cond3, cond4)), cb);
    }

    EventCondition merge (EventCondition a, EventCondition b) {
        return new class EventCondition {
            void passes (EventContext ctx) {
                return a.passes(ctx) && b.passes(ctx);
            }
        };
    }
}





/+
interface UIEvents {
    void onMouseMoved (void delegate(vec2));
    void onScroll     (void delegate(vec2));
    
    void onPressed (MouseButton, void delegate());
    void onPressed (MouseButton, PressCondition, void delegate());
    void onPressed (MouseButton, KeyboardModifiers, void delegate());
    void onPressed (MouseButton, KeyboardModifiers, PressCondition, void delegate());

    void onReleased (MouseButton, void delegate());
    void onReleased (MouseButton, KeyboardModifiers, void delegate ());

    void onPressed (KeyboardKey, void delegate());
    void onPressed (KeyboardKey, PressCondition, void delegate());
    void onPressed (KeyboardKey, KeyboardModifiers, void delegate());
    void onPressed (KeyboardKey, KeyboardModifiers, PressCondition, void delegate());

    void onReleased (KeyboardKey, void delegate(void));
    void onReleased (KeyboardKey, KeyboardModifiers, void delegate());

    void onPressed (GamepadButton, void delegate(void));
    void onPressed (GamepadButton, PressCondition, void delegate());
    void onPressed (GamepadButton, KeyboardModifiers, void delegate());
    void onPressed (GamepadButton, KeyboardModifiers, PressCondition, void delegate());
}

protected class UIEventsInstance : UIEvents {
final:
    UIManagerInstance uimanager = null;
    ISlot slots;

    this (UIManagerInstance uimanager) {
        this.uimanager = uimanager;
    }
    void onMouseMoved (void delegate(vec2) cb) {
        slots ~= g_mainWindow.onMouseMoved.connect(cb);
    }
    void onScroll (void delegate(vec2) cb) {
        slots ~= g_mainWindow.onMouseMoved.connect(cb);
    }
    void onPressed (MouseButton btn, PressCondition cond, void delegate() cb) {

    }
    void onPressed (MouseButton btn, KeyboardModifiers mods, PressCondition cond, void delegate() cb) {

    }
    void onPressed (MouseButton btn, KeyboardModifiers mods, PressCondition cond, void delegate() cb) {

    }
}+/

class UIComponent {
    protected bool hasBeenSetup = false;
    protected void delegate (UIEvents) setupFunc = null;
    protected UIEventsInstance         attachedEvents = null;
}




class UIManagerInstance {
    void setupOnce (UIComponent component, void delegate (UIEvents) doSetup) {
        if (!component.hasBeenSetup) {
            component.hasBeenSetup = true;
            component.setupFunc    = doSetup;
            component.attachedEvents = new UIEventsInstance(this);
            component.setupFunc(component.attachedEvents);
        }

    }
}









































































