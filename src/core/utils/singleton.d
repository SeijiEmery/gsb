
module gsb.core.singleton;

// http://wiki.dlang.org/Low-Lock_Singleton_Pattern
mixin template LowLockSingleton () {
    private this () { 
        import std.traits;
        import gsb.core.log;
        
        log.write("Creating %s instance", fullyQualifiedName!(typeof(this))); 
    }
    private static bool instantiated_ = false;
    private static __gshared typeof(this) instance_ = null;

    static final auto @property instance () {
        if (!instantiated_) {
            synchronized (typeof(this).classinfo) {
                if (!instance_)
                    instance_ = new typeof(this)();
                instantiated_ = true;
            }
        }
        return instance_;
    }
}