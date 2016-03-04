
module gsb.core.singleton;
import gsb.core.log;
import std.traits;


// http://wiki.dlang.org/Low-Lock_Singleton_Pattern
mixin template LowLockSingleton () {
    private this () { log.write("Creating %s instance", fullyQualifiedName!(typeof(this))); }
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