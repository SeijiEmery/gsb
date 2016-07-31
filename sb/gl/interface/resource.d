module sb.gl.resource;
public import sb.gl.texture;
public import sb.gl.shader;

alias GLResourcePoolRef = ResourceHandle!IGraphicsResourcePool;
alias GLTextureRef      = ResourceHandle!ITexture;
alias GLShaderRef       = ResourceHandle!IShader;
alias GLVboRef          = ResourceHandle!IVbo;
alias GLVaoRef          = ResourceHandle!IVao;

interface IGraphicsResourcePool {
    GLTextureRef createTexture ();
    GLShaderRef  createShader  ();
    GLVboRef     createVBO ();
    GLVaoRef     createVAO ();

    void release ();
    void retain();
}

interface IVbo {
    void bufferData (const(void)*, size_t, GLBuffering);

    void release ();
    void retain  ();
}
public void bufferData (T)(ref GLVboRef vbo, T[] data, GLBuffering bufferUsage) {
    vbo.bufferData(data.ptr, T.sizeof * data.length, bufferUsage);
}

enum GLBuffering { STATIC_DRAW, DYNAMIC_DRAW };

interface IVao {
    void bindVertexAttrib (uint index, GLVboRef vbo, uint count, GLType dataType,
        GLNormalized normalized, size_t stride = 0, size_t offset = 0);
    void setVertexAttribDivisor(uint index, uint divisor);

    // hacky... but whatever. 
    // We'll write some abstraction over VAOs later.
    void bindShader ( GLShaderRef shader );
    void drawArrays ( GLPrimitive, uint start, uint count );
    void drawArraysInstanced ( GLPrimitive, uint start, uint count, uint instanceCount );

    void release ();
    void retain ();
}

// maps to GLenum values; we need some abstraction for this since
// we are NOT importing actual opengl symbols (ie. import derelict.gl3)
// into our library interface
enum GLType { 
    BYTE, UNSIGNED_BYTE, 
    SHORT, UNSIGNED_SHORT, 
    INT, UNSIGNED_INT,
    FIXED,
    HALF_FLOAT, FLOAT, DOUBLE
}
enum GLNormalized : bool { FALSE = false, TRUE = true }

// And ditto for opengl primitives.
// Higher level API TBD!
enum GLPrimitive {
    POINTS,
    LINES, LINE_STRIP, LINE_LOOP,
    TRIANGLES, TRIANGLE_STRIP, TRIANGLE_FAN
}

private struct ResourceHandle (T) if (is(T == class) || is(T == interface)) {
    T _value = null;
    alias _value this;

    this (T value) { 
        _value = value; 
        if (_value)
            _value.retain(); 
    }
    this (this) {
        if (_value)
            _value.retain();
    }
    ~this () {
        if (_value)
            _value.release();
    }
    auto ref opAssign (ref ResourceHandle!T rhs) {
        if (this._value != rhs._value) {
            if (this._value)
                this._value.release();
            if (rhs._value)
                rhs._value.retain();
            this._value = rhs._value;
        }
        return this;
    }
    auto ref opAssign (ResourceHandle!T rhs) {
        if (this._value != rhs._value) {
            if (this._value)
                this._value.release();
            if (rhs._value)
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

