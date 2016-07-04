module gsb.utils.attrib;

enum AttribType { READ_ONLY, READ_WRITE };

struct Attrib (T, AttribType type = AttribType.READ_ONLY) {
private:
    union {
        T delegate() getValue;
        T value;
    }
    static if (type != AttribType.READ_ONLY) {
        void delegate(T) setValue;
    }
    bool isConst = true;
public:
    this (Args...)(Args args) if (__traits(compiles, opAssign(args))) {
        this.opAssign(args);
    }
    auto ref opAssign (typeof(value) value) {
        this.value = value;
        this.isConst = true;
        return this;
    }
    static if (type == AttribType.READ_ONLY) {
        auto ref opAssign (typeof(getValue) getValue) {
            this.getValue = getValue;
            this.isConst = false;
            return this;
        }
    } else {
        auto ref opAssign (typeof(getValue) getValue, typeof(setValue) setValue) {
            this.getValue = getValue;
            this.setValue = setValue;
            this.isConst  = false;
            return this;
        }
    }
    auto get () {
        return isConst ? value : getValue();
    }
    auto set (T v) {
        return isConst ?
            value = v :
            (setValue(v), v);
    }
}
