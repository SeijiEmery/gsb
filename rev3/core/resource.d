module rev3.core.resource;

class ManagedResource {
    abstract void resourceDtor ();

    private int _rc = 0;
    public final int rc () { return _rc; }
    public final void retain  () { ++_rc; }
    public final void release () { --_rc; }
    public final bool alive () { return _rc > 0; }

    unitttest {
        // TBD...
    }
}

struct ResourceManager (BaseType, TypeEnum) if (__traits(compiles, new T().rc() > 0)) {
    private BaseType[TypeEnum][] pool;             // Owning pool of unused objects, sorted by resource type
    private BaseType[]           active;           // Owning list of all active objects
    private BaseType[TypeEnum][] sorted;           // Non-owning cached list of active objects, sorted by resource type

    private static auto getEnum (T)() { return mixin(TypeEnum.stringof~"."~T.stringof); }

    public auto create (T, Args...)(Args args) {
        T resource = null;
        if (pool[getEnum!T].length) {
            resource = cast(T)(pool[getEnum!T][$-1]);
            resource.resourceInit(args);
            --pool[getEnum!T].length;
        } else {
            resource = new T(args);
        }
        dirtyResourceList = true;
        active ~= resource;
        return Ref!T(resource);
    }
    public void gcResources () {
        for (size_t i = active.length; i --> 0; ) {
            if (!active[i].alive) {
                active[i].resourceDtor();



                active[i] = active[$-1];
                --active.length;
                dirtyResourceList = true;
            }
        }
    }
    public auto ref getActive () {
        if (dirtyResourceList) {
        }
    }
}

struct ResourceManager (BaseType, TypeEnum) if (__traits(compiles, new T().rc() > 0)) {
    private BaseType[TypeEnum][] deadObjects;
    private BaseType[TypeEnum][] aliveObjects;

    private static auto getEnum (T)() { return mixin(TypeEnum.stringof~"."~T.stringof); }

    public auto create (T, Args...)(Args args) {
        T resource = null;
        if (deadObjects[getEnum!T].length) {
            // If dead object, reuse from that, and call resourceInit(args)
            resource = cast(T)(deadObjects[getEnum!T][$-1]);
            --deadObjects[getEnum!T].length;
            resource.resourceInit(args);
        } else {
            // Otherwise, create new object
            resource = new T(args);
        }
        // Add to alive list
        aliveObjects ~= resource;

        // Return object wrapped in Ref wrapper
        return Ref!T(resource);
    }
    public void gcResources () {
        foreach (resourceType; __traits__(allMembers, TypeEnum)) {
            for (size_t i = aliveObjects[resourceType].length; i --> 0; ) {
                if (!aliveObjects[resourceType][i].alive) {
                    // Call resource dtor
                    active[i].resourceDtor();

                    // Add to dead list
                    deadObjects[resourceType] ~= active[i];

                    // Remove from alive list
                    aliveObjects[resourceType][i] = aliveObjects[resourceType][$-1];
                    --aliveObjects[resourceType].length;
                }
            }
        }
    }
    public auto ref getActive () { return aliveObjects; }

    unittest {
        // TBD...
    }
}

// Non-owning reference struct used to implement RAII for objects with an intrusive external refcount.
// Requires that objects have 2 methods: retain() (addref) and release(decref).
// Object lifetime is managed externally via a ResourceManager or somesuch.
// Object is expected to be derived from ManagedResource.
struct Ref (T) if (is(T == class) && ) {
    private T _value;

    this (T v)  { _value = v; assert(v != null); }
    this (this) { _value.retain(); }
    ~this ()    { _value.release(); }

    T get () { return _value; }
    int opCmp (ref Ref!T other) { return cmp(get(), other.get()); }
    auto ref opDispatch (string member) if (__traits__(compiles, mixin("get()."member))) { return mixin("get()."~member); }
    auto opCall (Args...)(Args args) if (__traits__(compiles, get()(args))) {
        static if (!is(typeof(F(args)) == void))    return get()(args);
        else                                        get()(args);
    }
    unittest {
        // TBD...
    }
}



