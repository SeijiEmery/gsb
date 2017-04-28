module rev3.core.resource;
import std.typecons: Proxy;
import std.algorithm: swap;

public class ManagedResource {
    void resourceDtor () {}

    private int _rc = 0;
    public final int rc () { return _rc; }
    public final void retain  () { ++_rc; }
    public final void release () { --_rc; }
    public final bool alive () { return _rc > 0; }

    //unitttest {
    //    // TBD...
    //}
}

mixin template ResourceManager (BaseType, TypeEnum) 
    //if (__traits(compiles, (new BaseType()).rc() >= 0))
{
    private BaseType[][TypeEnum.max+1] deadObjects;
    private BaseType[][TypeEnum.max+1] aliveObjects;

    private static auto getEnum (T)() { return mixin(TypeEnum.stringof~"."~T.stringof); }

    private auto createResource (T, Args...)(Args args) {
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
        aliveObjects[getEnum!T] ~= cast(BaseType)(resource);

        // Return object wrapped in Ref wrapper
        return Ref!T(resource);
    }
    public void gcResources () {
        foreach (resourceType; TypeEnum.min .. TypeEnum.max) {
            for (size_t i = aliveObjects[resourceType].length; i --> 0; ) {
                if (!aliveObjects[resourceType][i].alive) {
                    // Call resource dtor
                    aliveObjects[resourceType][i].resourceDtor();

                    // Add to dead list
                    deadObjects[resourceType] ~= aliveObjects[resourceType][i];

                    // Remove from alive list
                    aliveObjects[resourceType][i] = aliveObjects[resourceType][$-1];
                    --aliveObjects[resourceType].length;
                }
            }
        }
    }
    public auto ref getActiveResources () { return aliveObjects; }

    //unittest {
    //    // TBD...
    //}
}

// Non-owning reference struct used to implement RAII for objects with an intrusive external refcount.
// Requires that objects have 2 methods: retain() (addref) and release(decref).
// Object lifetime is managed externally via a ResourceManager or somesuch.
// Object is expected to be derived from ManagedResource.
public struct Ref (T) if (is(T == class)) {
    private T _value;
    mixin Proxy!_value;

    this (T v)  { _value = v; assert(v !is null); }
    this (this) { if (_value) _value.retain(); }
    ~this ()    { if (_value) _value.release(); }

    auto ref opAssign (typeof(this) other) {
        swap(_value, other._value);
        return this;
    }
    auto ref opAssign (T value) {
        if (_value) _value.release();
        if (value)  value.retain();
        value = _value;
    }

    auto get () { return _value; }
    //auto ref opDispatch (string member)()
    //    if (__traits__(compiles, mixin("get()."member))) 
    //{ 
    //    return mixin("get()."~member); 
    //}
    //auto opCall (Args...)(Args args) if (__traits__(compiles, get()(args))) {
    //    static if (!is(typeof(F(args)) == void))    return get()(args);
    //    else                                        get()(args);
    //}
    //unittest {
    //    // TBD...
    //}
}



