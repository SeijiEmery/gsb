//
// Polymorphic Object-based Event System.
// Much less efficient than a variant-based solution (all those allocations! agh!),
// but is much more flexible, extensible, and less of a PITA.
//
// With this system, any class instance can be an event -- which is quite powerful.
// Since we're essentially using htis as a generalized command system, this is quite nice.
//

//
// TBD: WeakRef / StrongRef.
// Need a RAII ref-counted memory management system w/ object persistence beyond
// initial rc == 0, and controlled gc invocation (ie. release all resources from
// target thread). Need this for opengl, and many other things.
//


alias Event = Object;

class EventNode {
    WeakRef!Any parent;
    int priority;
public:
    this (typeof(parent) parent, typeof(priority) priority) { 
        this.parent = parent; 
        this.priority = priority;
    }
    abstract bool handle (Event event);
    final    bool removed () { return parent.removed(); }
}

class EventNodeListener (T) : public EventNode {
    void delegate (T) callback;
public:
    this (WeakRef!Any parent, int priority, typeof(callback) callback) {
        super(parent, priority);
        this.callback = callback;
    }
    bool handle (Event event) override {
        if (typeid(event) == typeid(T)) {
            callback(cast(T)(event));
            return true;
        }
        return false;
    }
    unittest {
        // TBD...
    }
}

public enum EventDispatch { First, All, None };

class EventNodeBranch : public EventNode {
    EventNode[] children;
    EventDispatch dispatch;
    bool dirty = false;
public:
    this (WeakRef!Any parent, EventDispatch dispatch, int priority) {
        super(parent, priority);
    }
    bool handle (Event event) override {
        if (children.length) {
            for (auto i = children.length; i --> 0; ) {
                if (children[i].removed()) {
                    children[i] = children[$-1];
                    --children.length;
                    dirty = true;
                }
            }
            if (dirty && dispatch == EventDispatch.First) {
                children.sort!"a.priority";
            }
            dirty = false;

            switch (dispatch) {
                case EventDispatch.All: {
                    for (auto child : children) {
                        child.handle(event);
                    }
                    return children.length != 0;
                } break;
                case EventDispatch.First: {
                    for (auto child : children) {
                        if (child.handle(event)) {
                            return true;
                        }
                    }
                } break;
            }
        }
        return false;
    }
    void setDispatch (EventDispatch dispatch) {
        this.dispatch = dispatch;
        dirty = true;
    }
    void append (EventNode child) {
        children ~= child;
        dirty     = true;
    }
    void clear () {
        children.length = 0;
    }
    unittest {
        // TBD...
    }
}

class EventNodeBuffer : public EventNode {
    EventNode node;
    Event[] events;
    Event[] backEvents;
    Mutex   mutex;
public:
    this (WeakRef!Any parent, EventNode next, int priority = 0,) {
        super(parent, priority);
        this.node = next;
        this.mutex = new Mutex();
    }
    bool handle (Event event) {
        events ~= event;
        return true;
    }
    void dispatchAll () {
        synchronized (mutex) {
            swap(events, backEvents);
            for (auto event : backEvents) {
                node.handle(event);
            }
            backEvents.clear();
        }
    }
}




struct EventDispatcher {
    EventNode node;
public:
    this (EventNode root) {
        this.root = root;
    }
    bool opCall (T)(T event) {
        return root.handle(cast(Event)event);
    }
    unittest {
        // TBD...
    }
}

struct EventListener {
    EventNodeBranch branch;
    WeakRef!Any     selfref;
public:
    this (EventDispatch dispatch = Dispatch.First, int priority = 0) {
        branch = new EventNodeBranch(selfref, dispatch, priority);
    }
    void setDispatch (EventDispatch dispatch) {
        branch.setDispatch(dispatch);
    }
    void on (T)(void delegate (T) callback) {
        branch.append(new EventNodeListener(selfref, callback, branch.priority));
    }
    void on (T)(void delegate (T) callback, int priority) {
        branch.append(new EventNodeListener(selfref, callback, branch.priority));
    }
    void clear () { 
        branch.clear();
    }
    unittest {
        // TBD...
    }
}















