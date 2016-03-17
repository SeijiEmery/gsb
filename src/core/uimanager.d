
module gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.window;
import gsb.core.gamepad;
import gsb.core.frametime;
import gsb.core.singleton;

import std.traits;
import gl3n.linalg;

// UIComponent base class. Note: components should use onInit() / onShutdown() as its 
// ctor / dtor, respectively, NOT this() / ~this().
class UIComponent {
    // Called when component is activated / 'created'
    abstract void onComponentInit ();

    // Called when component is deactivated / 'destroyed'
    abstract void onComponentShutdown();

    // Event handler. Doesn't support event eating / forwarding (yet); currently all components recieve the same events.
    abstract void handleEvent (UIEvent);
    
    // Public properties: registered name, unique instance id, and active / inactive state.
    @property auto name ()   { return _name; }
    @property auto id ()     { return _id; }
    @property auto active () { return _active; }

    private string _name;
    private ulong  _id = 0;
    private bool   _active = false;
}

public @property auto UIComponentManager () {
    return UIComponentManagerInstance.instance;
}

private class UIComponentManagerInstance {
    mixin LowLockSingleton;

    private UIEventDispatcher dispatcher;

    private UIComponent[string] registeredComponents;
    private UIComponent[]       activeComponents;
    private ulong nextComponentId = 1;

    // workaround for module constructors (useless unless they can run code _after_
    // app init). No better place to put it atm, so it goes here
    private void delegate()[] deferredInitCode;

    public Signal!(UIComponent) onComponentActivated;
    public Signal!(UIComponent) onComponentDeactivated;
    public Signal!(UIComponent, string) onComponentRegistered;

    public Signal!(IEventCollector) onEventSourceRegistered;
    public Signal!(IEventCollector) onEventSourceUnregistered;

    // Dispatch events on components
    void updateFromMainThread () {
        if (activeComponents.length) {
            dispatcher.dispatchEvents(activeComponents);
        } else {
            dispatcher.dispatchEvents([]);
        }
    }

    void shutdown () {
        foreach (component; activeComponents) {
            component.onComponentShutdown();
            onComponentDeactivated.emit(component);
        }
        activeComponents.length = 0;
    }

    void init () {
        foreach (cb; deferredInitCode)
            cb();
        deferredInitCode.length = 0;
    }

    void runAtInit (void delegate() deferredCallback) {
        deferredInitCode ~= deferredCallback;
    }

    // use for introspection, etc; used by module_manager.d
    auto getComponentList () {
        return registeredComponents;
    }

    // Register component instance. Components are created once
    void registerComponent (UIComponent component, string name, bool active = true) {
        if (name in registeredComponents)
            throw new Exception("Already registered component '%s'", name);

        component._id = nextComponentId++;
        component._name = name;
        component._active = active;

        registeredComponents[name] = component;
        onComponentRegistered.emit(component, name);

        if (component._active) {
            component._active = false;
            activateComponent(component);
        }
    }

    void registerEventSource (IEventCollector source) {
        onEventSourceUnregistered.emit(source);
        dispatcher.registerEventSource(source);
    }
    void unregisterEventSource (IEventCollector source) {
        onEventSourceUnregistered.emit(source);
        dispatcher.unregisterEventSource(source);
    }

    void createComponent (string name) {
        if (name !in registeredComponents)
            throw new Exception("No registered component '%s'", name);

        activateComponent(registeredComponents[name]);
    }
    void deleteComponent (string name) {
        if (name !in registeredComponents)
            throw new Exception("No registered component '%s'", name);

        deactivateComponent(registeredComponents[name]);
    }

    private void activateComponent (UIComponent component) {
        if (!component.active) {
            component._active = true;
            activeComponents ~= component;
            component.onComponentInit();
            onComponentActivated.emit(component);
        }
    }
    private void deactivateComponent (UIComponent component) {
        if (component.active) {
            component._active = false;
            component.onComponentShutdown();
            onComponentDeactivated.emit(component);

            // swap-delete (or could std.algorithm remove, but w/e; this is faster)
            for (auto i = activeComponents.length; i --> 0; ) {
                if (activeComponents[i] == component) {
                    if (i != activeComponents.length - 1)
                        activeComponents[$-1] = activeComponents[i];
                    activeComponents.length -= 1;
                    return;
                }
            }
            //assert(0);
        }
    }
}

private struct UIEventDispatcher {
    private IEventCollector[] eventSources;
    private UIEvent[] eventList;

    void registerEventSource (IEventCollector source) {
        // assert unique
        foreach (ev; eventSources)
            assert(ev != source);
        eventSources ~= source;
    }
    void unregisterEventSource (IEventCollector source) {
        for (auto i = eventSources.length; i --> 0; ) {
            if (eventSources[i] == source) {
                if (i != eventSources.length - 1)
                    eventSources[i] = eventSources[$-1];
                eventSources.length -= 1;
                return;
            }
        }
        throw new Exception("Event source was not registered");
    }

    void dispatchEvents (UIComponent[] components) {
        eventList.length = 0;
        foreach (ev; eventSources)
            eventList ~= ev.getEvents();
        
        eventList ~= FrameUpdateEvent.create(
            g_eventFrameTime.current,
            g_eventFrameTime.dt,
            g_eventFrameTime.frameCount
        );

        //log.write("Dispatching %d events to %d components",
        //    eventList.length, components.length);

        foreach (event; eventList) {
            foreach (component; components) {
                component.handleEvent(event);
            }
        }
    }
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









































































