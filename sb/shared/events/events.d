module sb.events.events;
public import sb.events.window_events;
public import sb.events.input_events;
public import sb.events.internal_events;
public import std.variant: Algebraic, visit;

alias SbEvent = Algebraic!(
    SbWindowResizeEvent, SbWindowRescaleEvent, SbWindowFocusChangeEvent,
    SbWindowMouseoverEvent, SbWindowNeedsRefreshEvent,

    SbMouseMoveEvent, SbMouseButtonEvent, SbScrollInputEvent,
    SbKeyEvent, SbRawCharEvent,

    SbMousePressEvent, SbMouseDownEvent, SbMouseUpEvent,
    //SbKeyPressEvent,   SbKeyDownEvent,   SbKeyUpEvent,

    SbGamepadButtonEvent, SbGamepadAxisEvent,
    SbGamepadConnectionEvent,
 
    SbAppLoadedEvent, SbAppKilledEvent, SbNextFrameEvent,

    //SbModuleLoadingEvent, SbModuleLoadedEvent, SbModuleLoadFailedEvent,
    //SbModuleRunningEvent, SbModuleKilledEvent, SbModuleErrorEvent,
);

// List of event classifications as a bitmask
enum SbEventMask {
    FRAME_EVENTS  = 0x1,
    APP_EVENTS    = 0x2,
    MODULE_EVENTS = 0x4,
    MODULE_LOAD_EVENTS = 0x8,

    WINDOW_EVENTS = 0x10,
    INPUT_EVENTS  = 0x20,
    ALL           = 0x2f,
}

// Event producer interface; wraps an internal event list in a concurrent-ish manner.
// (note: you should not share the same IEventProducer across multiple threads, but
//  you should never have to worry about doing this, as sb will implicitely use multiple
//  instances, or use locks or whatever when/if code on multiple threads are producing
//  events concurrently).
interface IEventProducer {
    // Add event
    IEventProducer pushEvent (SbEvent);

    // Add event (convenience function: enables pushEvent(MouseEvent(...)),
    //  vs the more verbose pushEvent(SbEvent(MouseEvent(...))), as the SbEvent ctor
    //  is technically required but effectively redundant).
    IEventProducer pushEvent (Args...)(Args args) if (__traits(compiles, SbEvent(args)));
}

// Test event handler list (Cases), ensuring that it can match SbEvent.visit() / tryVisit()
private void testHandler (Cases...)() {
    SbEvent[] events;
    events[0].visit!Cases;
}

// Event consumer interface.
interface IEventList {
    // Try handling all events with types matching SbEventMask using a list of 
    // function cases @Cases; has the same semantics as std.variant: visit,
    // but with the empty case omitted.
    void handle (SbEventMask eventTypes, Cases...)() if (__traits(compiles, testHandler!Cases));

    // Same as the above, but w/out eventTypes (same as SbEventMask.ALL)
    void handle(Cases...)() if (__traits(compiles, testHandler!Cases));
}



