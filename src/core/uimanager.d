
module gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.window;
import gsb.core.gamepad;
import gsb.core.frametime;

import gl3n.linalg;

interface UIComponent {
    void setup (UIEvents);    
}

class UIComponentManager {
    void createComponent(T)() {

    }
}

class UIEventDispatcher {
    
}




/+

protected class EventContext {

}
protected class EventCondition {
    abstract bool passes (EventContext ctx);

    auto opBinary (string op)(EventCondition cond) {
        EventCondition a = this, b = cond;
        static if (op == "|") 
            return new class EventCondition { 
                bool passes (EventContext ctx) { return a.passes(ctx) || b.passes(ctx); }
            };
        else static if (op == "&")
            return new class EventCondition {
                bool passes (EventContext ctx) { return a.passes(ctx) && b.passes(ctx); }
            };
        else static assert(0, "Operator "~op~" not implemented");
    }
}
protected interface DeviceButtonOrKey {

}
alias void delegate(UIEvent) EventCallback;

public interface UIEvents {
    void connect (DeviceButtonOrKey, EventCondition, EventCallback);
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

protected enum : ubyte {
    KEYBOARD_MODIFIERS_CTRL = 1 << 1,
    KEYBOARD_MODIFIERS_CMD  = 1 << 2,
    KEYBOARD_MODIFIERS_ALT  = 1 << 3,
    KEYBOARD_MODIFIERS_SHIFT = 1 << 4,
    KEYBOARD_MODIFIERS_META  = 1 << 5,   // replaces cmd on windows/linux, probably. Dunno if I'll implement this.
}
protected ubyte g_activeKeyboardModifiers = 0;


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
        bool check () { return g_activeKeyboardModifiers & KEYBOARD_MODIFIERS_CMD; }
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
            if (g_mainFrameTime.current >= lastTime + seconds) {
                lastTime = g_mainFrameTime.current;
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

enum : ubyte {
    SRC_EVT_NONE = 0,
    SRC_EVT_PER_FRAME,
    SRC_EVT_MOUSE_MOVED,
    SRC_EVT_SCROLL,
    SRC_EVT_MOUSE_BTN,
    SRC_EVT_KEY_BTN,
    SRC_EVT_GAMEPAD_BTN,
    SRC_EVT_GAMEPAD_AXIS,
    NUM_SRC_EVENTS
}

protected class UIEventsInstance : UIEvents {
    struct ConditionalEvent {
        DeviceButtonOrKey btn;
        EventCondition    cond;
        EventCallback     cb;
        ubyte type;
    }
    ConditionalEvent[] events;
    int[NUM_SRC_EVENTS] firstEventLookup;
    bool                eventsSorted = false;

    void connect (DeviceButtonOrKey btn, EventCondition cond, EventCallback cb) {

    }

    bool hasEvent (ubyte eventType)() if (eventType < NUM_SRC_EVENTS) {
        if (!eventsSorted) resortEvents();
        return firstEventLookup[eventType] >= 0;
    }
    void dispatchEvents (ubyte eventType)(EventContext ctx) if (eventType < NUM_SRC_EVENTS) {
        if (!eventsSorted) resortEvents();
        assert(firstEventLookup[i] >= 0);
        for (auto i = firstEventLookup[eventType]; events[i].type == eventType; ++i) {
            if (events[i].cond(ctx)) {
                cb();
            }
        }
    }
    private void resortEvents () {
        import std.algorithm.sorting: sort;
        sort!"a.type < b.type"(events);

        firstEventLookup[0..$] = -1;
        ubyte curEvt = SRC_EVT_NONE;
        foreach (i; 0..events.length) {
            if (events[i].type != curEvt) {
                firstEventLookup[curEvt = events[i].type] = i;
            }
        }
        eventsSorted = true;
    }
}

protected struct PackedEvent {
    enum: ubyte {
        EVT_MOUSE_MOVED, EVT_
    }
}



protected class UIEventDispatcher {
    UIEventsInstance[] instances;

    ISlot[] slots;
    protected void setup () {
        if (slots.length) teardown();
        slots ~= g_mainWindow.onMouseMoved.connect(onMouseMoved);
        slots ~= g_mainWindow.onScrollInput.connect(onScroll);
        slots ~= g_mainWindow.onMouseButtonPressed.connect(onMouseButton);
        slots ~= g_mainWindow.onKeyPressed.connect(onKeyPressed);
        slots ~= g_mainWindow.onGamepadButtonPressed.connect(onGamepadButtonPressed);
        slots ~= g_mainWindow.onGamepadButtonReleased.connect(onGamepadButtonReleased);
        slots ~= g_mainWindow.onGamepadAxes.connect(onGamepadAxes);
    }
    protected void teardown () {
        if (slots.length) {
            foreach (slot; slots)
                slot.disconnect();
            slots.length = 0;
        }
    }

private:
    // Internal event collection + dispatch
    PackedEvent[] pendingEvents;
    PackedEvent[] stage2Events;

    struct PackedEvent {
        union Varying {
            vec2 dirEvt;
            vec2i dimEvt;
            Window.MouseButton mbEvt;
            Window.KeyPress    kbEvt;
            GamepadBtnEvt      gbEvt;
            float[]            gamepadAxes;
        }
        Varying value;
        ubyte   type = EVT_INVALID;
    }
    struct GamepadBtnEvt  { GamepadButton btn; bool pressed; }
    enum : ubyte {
        EVT_INVALID,
        EVT_MOUSE_MOVED, EVT_MOUSE_SCROLLED, EVT_MOUSE_BUTTON, EVT_KEY_PRESSED, EVT_GAMEPAD_BUTTON,
        EVT_GAMEPAD_AXES, EVT_WINDOW_RESIZED, EVT_WINDOW_RESCALED
    }
    PackedEvent packedEvent(T)(uint type, T value) {
        return PackedEvent(PackedEvent.Varying(value), type);
    }

    enum : ubyte {
        WINDOW_RESIZE_EVT = 1 << 1,
        WINDOW_SCALE_EVT  = 1 << 2,
        WINDOW_MOVE_EVT   = 1 << 3,
        GAMEPAD_AXES_EVT  = 1 << 4,
    }

    // Noticed that we can 'cheat' quite a bit since many events will only ever occur at most
    // once per frame (window resizes, gamepad axes updates), and the amount of data we have to
    // store to reconstruct input events is quite minimal vs list of tagged unions approach
    struct EventStage {
        Window.MouseButton[] mouseBtnEvents;
        Window.KeyPress[]    keyPressEvents;
        GamepadBtnEvent[]    gamepadButtonEvents;
        float[NUM_GAMEPAD_AXES] gamepadAxes;
        vec2i windowResizeDim;
        vec2i windowScaleDim;
        vec2  mousePos;
        vec2  scrollDir;
        ubyte eventFlags = 0;

        void reset () {
            mouseBtnEvents.length = 0;
            keyPressEvents.length = 0;
            gamepadButtonEvents.length = 0;
            eventFlags = 0;
        }
    }
    EventStage nextStage, pendingStage;
    //PackedEventValue[] pendingEvents;
    //void onMouseMoved (vec2 pos) { 
    //    pendingEvents ~= packedEvent(EVT_MOUSE_MOVED, pos);
    //}
    //void onMouseScrolled (vec2 dir) {
    //    pendingEvents ~= packedEvent(EVT_MOUSE_SCROLLED, dir);
    //}
    //void onMouseButton (Window.MouseButton evt) {
    //    pendingEvents ~= packedEvent(EVT_MOUSE_BUTTON, evt);
    //}
    //void onKeyPressed  (Window.KeyPress evt) {
    //    pendingEvents ~= packedEvent(EVT_KEY_PRESSED, evt);
    //}
    //void onGamepadButtonPressed (GamepadButton btn) {
    //    pendingEvents ~= packedEvent(EVT_GAMEPAD_BUTTON, GamepadBtnEvt(btn, true));
    //}
    //void onGamepadButtonReleased (GamepadButton btn) {
    //    pendingEvents ~= packedEvent(EVT_GAMEPAD_BUTTON, GamepadBtnEvt(btn, true));
    //}
    //void onGamepadAxes (float[] axes) {
    //    pendingEvents ~= packedEvent(EVT_GAMEPAD_AXES, axes);
    //}

    void onMouseMoved (vec2 pos) {
        nextStage.eventFlags |= EVT_MOUSE_MOVED; nextStage.mousePos = pos;
    }
    void onMouseScrolled (vec2 dir) {
        nextStage.eventFlags |= EVT_MOUSE_SCROLLED; nextStage.scrollDir = dir;
    }
    void onMouseButton (Window.MouseButton evt) {
        nextStage.mouseBtnEvents ~= evt;
    }
    void onKeyPressed  (Window.KeyPress evt) {
        nextStage.keyPressEvents ~= evt;
    }
    void onGamepadButtonPressed (GamepadButton btn) {
        nextStage.gampeadButtonEvents ~= GamepadBtnEvt(btn, true);
    }
    void onGamepadButtonReleased (GamepadButton btn) {
        nextStage.gamepadButtonEvents ~= GamepadBtnEvt(btn, false);
    }
    void onGamepadAxes (float[] axes) {
        nextStage.eventFlags |= EVT_GAMEPAD_AXES;
        nextStage.gamepadAxes[0..NUM_GAMEPAD_AXES] = axes[0..NUM_GAMEPAD_AXES];
    }

public:
    void processEvents () {
        import std.algorithm.mutation: swap;

        swap(nextStage, pendingStage);
        nextStage.reset();

        // Process each event instance independently (in theory, should speed up cache performance
        // since component callbacks are grouped together)
        foreach (instance; instances) {
            if (instance.hasEvent!SRC_EVENT_WINDOW_RESIZED && pendingStage.eventFlags & EVT_WINDOW_RESIZED)
                instance.dispatchEvents!SRC_EVENT_WINDOW_RESIZED(EventContext.Empty, pendingStage.windowResizeDim);
            if (instance.hasEvent!SRC_EVENT_WINDOW_RESCALED && pendingStage.eventFlags & EVT_WINDOW_RESCALED)
                instance.dispatchEvents!SRC_EVENT_WINDOW_RESCALED(EventContext.Empty, pendingStage.windowScaleDim);

            if (instance.hasEvent!SRC_EVT_MOUSE_MOVED && pendingStage.eventFlags & EVT_MOUSE_MOVED)
                instance.dispatchEvents!SRC_EVT_MOUSE_MOVED(EventContext.Empty, pendingStage.mousePos);
            if (instance.hasEvent!SRC_EVT_SCROLL && pendingStage.eventFlags & EVT_MOUSE_SCROLLED)
                instance.dispatchEvents!SRC_EVT_SCROLL(EventContext.Empty, pendingStage.scrollDir);

            if (instance.hasEvent!SRC_EVT_MOUSE_BTN && pendingStage.mouseBtnEvents.length) {
                foreach (mouseEvt; pendingStage.mouseBtnEvents) {
                    auto ctx = EventContext(
                        fromGlfwPressState(mouseEvt.pressState),
                        fromGflwModifiers (mouseEvt.mods));
                    instance.dispatchEvents!SRC_EVT_MOUSE_BTN(ctx);
                }
            }

            if (instance.hasEvent!SRC_EVT_KEY_BTN && pendingStage.keyPressEvents.length) {
                foreach (keyEvt; pendingStage.keyPressEvents) {
                    auto ctx = EventContext(
                        fromGlfwPressState(keyEvt.pressState),
                        fromGflwModifiers(keyEvt.mods));
                    instance.dispatchEvents!SRC_EVT_KEY_BTN(ctx);
                }
            }

            if (instance.hasEvent!SRC_EVT_GAMEPAD_BTN && pendingStage.gamepadButtonEvents.length) {
                foreach (gamepadEvt; pendingStage.gamepadButtonEvents) {
                    // ...
                }
            }
            if (instance.hasEvent!SRC_EVT_GAMEPAD_AXIS && pendingStage.eventFlags & EVT_GAMEPAD_AXES) {

            }

            if (instance.hasEvent!SRC_EVENT_PER_FRAME) {
                instance.dispatchEvents!SRC_EVENT_PER_FRAME();
            }
        }
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
}+/









































































