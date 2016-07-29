module sb.gl.resource;
public import sb.gl.texture;
public import sb.gl.shader;

alias GLResourcePoolRef = ResourceHandle!IGraphicsResourcePool;
alias GLTextureRef      = ResourceHandle!ITexture;
alias GLShaderRef       = ResourceHandle!IShader;

interface IGraphicsResourcePool {
    GLTextureRef createTexture ();
    GLShaderRef  createShader  ();

    void release ();
    void retain();
}

private struct ResourceHandle (T) {
    T _value;
    alias _value this;

    this (T value) { _value = value; _value.retain(); }
    this (this) {
        _value.retain();
    }
    ~this () {
        _value.release();
    }
    auto ref opAssign (ref ResourceHandle!T rhs) {
        if (this._value != rhs._value) {
            this._value.release();
            rhs._value.retain();
            this._value = rhs._value;
        }
        return this;
    }
    auto ref opAssign (ResourceHandle!T rhs) {
        if (this._value != rhs._value) {
            this._value.release();
            rhs._value.retain();
            this._value = rhs._value;
        }
        return this;
    }
}
unittest {
    class Foo {
        int rc = 0;

        void retain () { ++rc; }
        void release () { --rc; }
    }
    alias FooRef = ResourceHandle!Foo;

    auto f1 = new Foo(), f2 = new Foo();

    {
        auto a = FooRef(f1);
        assert(a._value == f1);
        assert(a.rc == 1);
        {
            auto b = a;
            assert(b._value == f1);
            assert(a.rc == 2);
        }
        assert(a.rc == 1);
        {
            auto b = FooRef(f2);
            assert(b._value == f2);
            assert(b.rc == 1);

            b = a;
            assert(b._value == f1);
            assert(f2.rc == 0);
            assert(a.rc == 2);
        }
        assert(a.rc == 1);
        {
            auto b = FooRef(a);
            assert(b._value == f1);
            assert(a.rc == 2);
        }
        assert(a.rc == 1);
        a = FooRef(f2);
        assert(f1.rc == 0);
    }
    assert(f2.rc == 0);
    {
        auto a = FooRef(f1);
        assert(f1.rc == 1);
    }
    assert(f1.rc == 0);
}

