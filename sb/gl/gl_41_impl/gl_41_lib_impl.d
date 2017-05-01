module sb.gl.gl_impl;
import sb.gl;

import rev3.core.opengl;
import derelict.opengl3.gl3;
import gl3n.linalg;
import std.exception: enforce;
import std.format;
import core.sync.mutex;
import std.string: toStringz;
import std.typecons;


// Create graphics lib.
// Note: this is kinda tied into the glfw3 platform impl,
// so if/when adding additional platforms this abstraction mechanism
// might need to be changed...
extern(C) IGraphicsLib sbCreateGraphicsLib (GraphicsLibVersion glVersion) {
    enforce!Exception( glVersion == GraphicsLibVersion.GL_410, 
        format("Invalid graphics lib version: %s, not GL_410",
            glVersion));

    return new GL41_GraphicsLib();
}
private class GL41_GraphicsLib : IGraphicsLib {
    GraphicsLibVersion glVersion () { 
        return GraphicsLibVersion.GL_410; 
    }
    GLVersionInfo getVersionInfo () {
        OpenglVersionInfo VERSION_INFO = {
            VERSION_MAJOR: 4, 
            VERSION_MINOR: 1,
            IS_CORE_PROFILE: true, 
            IS_FORWARD_COMPAT: true
        };
        return GLVersionInfo(VERSION_INFO);
    }
    void preInit () {
        DerelictGL3.load();
        initialized = true;
    }
    void initOnThread () {
        assert(initialized, "Did not call <gl_lib>.preInit()!");
        DerelictGL3.reload();
        glEnable(GL_DEPTH_TEST);
        //glEnable (GL_BLEND);
        //glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    void teardown () {
        if (context)
            context.teardown();
    }
    IGraphicsContext getContext () {
        enforce(initialized, "Did not initialize opengl!");
        if (!context)
            context = new GL41_GraphicsContext();
        return context;
    }
    bool initialized = false;
    GL41_GraphicsContext context = null;
}

private class GL41_GraphicsContext : IGraphicsContext {
    this () { m_mutex = new Mutex(); }

    override IBatch   createBatch   () { return getLocalBatch(); }
    override IBatch   getLocalBatch () { 
        if (!m_localBatch) {
            synchronized (m_mutex) {
                if (!m_localBatch)
                    m_localBatch = new Batch();
            }
        }
        return m_localBatch;
    }
    override GLResourcePoolRef createResourcePrefix (string name) {
        auto pool = new ResourcePool(name, this);
        synchronized (m_mutex) { m_resourcePools ~= pool; }
        return GLResourcePoolRef(pool);
    }

    override void setClearColor (vec4 color) { m_clearColor = color; }
    override void endFrame () {
        // finalize batches...?
    }
    override void beginFrame () {
        glClearColor(m_clearColor.r, m_clearColor.g, m_clearColor.b, m_clearColor.a);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    }
    void teardown () {
        synchronized (m_mutex) {
            foreach (pool; m_resourcePools)
                pool.releaseAll();
            m_resourcePools.length = 0;
        }
    }
    private void releasePool (ResourcePool pool) {
        synchronized (m_mutex) {
            foreach (i, v; m_resourcePools) {
                if (v == pool) {
                    m_resourcePools[i] = m_resourcePools[$-1];
                    m_resourcePools.length--;
                    break;
                }
            }
        }
    }
private:
    vec4 m_clearColor;
    ResourcePool[] m_resourcePools;
    Mutex m_mutex;
    Batch m_localBatch = null;
}

private class Batch : IBatch {
    override void execGL (void delegate() stuff) {
        stuff();
    }
}

private mixin template RetainRelease () {
    import core.atomic;
    import std.stdio;

    override void release () {
        auto count = atomicOp!"-="(m_rc, 1);
        //writefln("--rc: %s | %s (%s)", count, this, this.classinfo);
        if (count == 0) {
            writefln("Released: %s", this);
            this.onReleased();
        }
    }
    override void retain () {
        auto count = atomicOp!"+="(m_rc, 1);
        //writefln("++rc: %s | %s (%s)", count, this, this.classinfo);
    }
    void forceRelease () {
        uint count;
        do {
            count = m_rc;
        } while (!cas(&m_rc, count, 0));

        if (count > 0)
            this.onReleased();
    }
    private shared int m_rc = 0;
}

string getId ( ResourcePool pool ) { return pool ? pool.m_id : "null"; }

private class ResourcePool : IGraphicsResourcePool {
    string               m_id;
    GL41_GraphicsContext m_graphicsContext;
    IGraphicsResource[]  m_activeResources;
    Mutex m_mutex;

    import std.stdio;

    this (string id, typeof(m_graphicsContext) context) {
        m_id = id;
        m_graphicsContext = context;
        m_mutex = new Mutex();
    }
    override GLTextureRef createTexture () {
        auto texture = new Texture(this);
        synchronized (m_mutex) { m_activeResources ~= texture; }
        return GLTextureRef(texture);
    }
    override GLShaderRef createShader () {
        auto shader = new Shader(this);
        synchronized (m_mutex) { m_activeResources ~= shader; }
        return GLShaderRef(shader);
    }
    override GLVboRef createVBO () {
        auto vbo = new Vbo(this);
        synchronized (m_mutex) { m_activeResources ~= vbo; }
        return GLVboRef(vbo);
    }
    override GLVaoRef createVAO () {
        auto vao = new Vao(this, m_graphicsContext);
        synchronized (m_mutex) { m_activeResources ~= vao; }
        return GLVaoRef(vao);
    }
    mixin RetainRelease;
    private void onReleased () { 
        releaseAll();
        m_graphicsContext.releasePool(this); 
    }

    void releaseAll () {
        IGraphicsResource[] resources;
        //writefln("locking: releaseAll");
        synchronized (m_mutex) {
            //writefln("locked: releaseAll");
            resources = m_activeResources;
            m_activeResources.length = 0;
        }
        //writefln("unlocked: releaseAll");
        foreach (resource; resources)
            resource.forceRelease();
    }
    void releaseResource (IGraphicsResource resource) {
        //writefln("locking: releaseResource");
        synchronized (m_mutex) {
            //writefln("locked: releaseResource");
            foreach (i, v; m_activeResources) {
                if (resource == v) {
                    //writefln("swap delete: %s, %s", i, m_activeResources.length);
                    m_activeResources[i] = m_activeResources[$-1];
                    --m_activeResources.length;
                }
            }
        }
    }
    override string toString () {
        return format("ResourcePool '%s'", m_id);
    }
}

private interface IGraphicsResource {
    void forceRelease ();
}

// A bit of hackery to unwrap values from a ResourceHandle!IWhatever used by
// our lib to abstract things. Assumes, ofc, that the backing object _is_
// something that was allocated from the gl_41_lib impl...
private auto unwrap (ref GLShaderRef shader) { return cast(Shader)(shader._value); }
private auto unwrap (ref GLTextureRef texture) { return cast(Texture)(texture._value); }
private auto unwrap (ref GLVaoRef vao) { return cast(Vao)(vao._value); }
private auto unwrap (ref GLVboRef vbo) { return cast(Vbo)(vbo._value); }


private class Shader : IGraphicsResource, IShader {
    ResourcePool m_graphicsPool;

    bool                   m_hasPendingRecompile = false;
    string[GLShaderType.max] m_pendingSrc    = null;
    uint  [GLShaderType.max] m_shaderObjects = 0;
    uint                   m_programObject = 0;
    uint [string]          m_locationCache;
    Tuple!(GLShaderType,string,string,uint)[] m_subroutineCache;
    bool m_isBindable = false;

    this (ResourcePool pool) {
        m_graphicsPool = pool;
    }
    override string toString () {
        return format("Shader %s %s '%s'", m_programObject,
            m_hasPendingRecompile ? "PENDING_RECOMPILE" :
                m_isBindable ? "COMPILED" : "NOT_COMPILED",
            m_graphicsPool.getId
        );
    }

    // Call only on Graphics thread!
    private bool bindShader () {
        void maybeRecompileShaders () {
            if (!m_hasPendingRecompile)
                return;

            bool didRecompile = false;
            m_isBindable = false;

            foreach (uint i; GLShaderType.min .. GLShaderType.max) {
                if (m_pendingSrc[i]) {
                    gl.CompileAndAttachShader(m_programObject, m_shaderObjects[i], i, m_pendingSrc[i]);
                    didRecompile = true;
                    m_pendingSrc[i] = null;
                }
            }
            if (didRecompile) {
                foreach (k, v; m_locationCache)
                    m_locationCache.remove(k);

                assert(m_programObject != 0);
                gl.LinkProgram(m_programObject);
            }
            m_hasPendingRecompile = false;
            m_isBindable = true;
        }
        try {
            maybeRecompileShaders();
            if (m_isBindable) {
                gl.UseProgram( m_programObject );
                return true;
            }
        } catch (Exception e) {
            // TODO: better error reporting (signals, etc)
            import std.stdio;
            writefln("Error while recompiling shader(s):\n%s", e);
        }
        glUseProgram( 0 );
        return false;
    }

    override IShader source (GLShaderType type, string path) {
        assert(0, "Unimplemented! set shader source from path");
    }
    override IShader rawSource (GLShaderType type, string contents) {
        m_hasPendingRecompile = true;
        m_pendingSrc[type] = contents;
        return this;
    }
    override IShader useSubroutine (GLShaderType type, string name, string value) {
        uint fetchSubroutineUniform () {
            if (name !in m_locationCache) {
                int location = gl.GetSubroutineUniformLocation(m_programObject, type, name.toStringz);
                enforce(location != -1, format("Could not get subroutine uniform '%s'", name));
                return m_locationCache[name] = location;
            }
            return m_locationCache[name];
        }
        uint fetchSubroutineValue () {
            foreach (ref entry; m_subroutineCache) {
                if (entry[0] == type && entry[1] == name && entry[2] == value)
                    return entry[3];
            }
            auto subroutine = gl.GetSubroutineIndex(m_programObject, type, value.toStringz);
            enforce(subroutine != -1, format("Could not get subroutine value '%s': '%s'", name, value));
            m_subroutineCache ~= tuple(type, name, value, subroutine);
            return subroutine;
        }
        if (gl.BindProgram(getProgram)) {
            //uint[2] kv = [ fetchSubroutineUniform(), fetchSubroutineValue() ];
            uint index = fetchSubroutineUniform();
            uint v     = fetchSubroutineValue();
            enforce( index == 0, format("Index != 0: %s", index));

            gl.UniformSubroutinesuiv(type, 1, &v );
        }
        return this;
    }
    uint getLocation (string name) {
        if (name !in m_locationCache) {
            int location = gl.GetUniformLocation(m_programObject, name.toStringz);
            enforce(location != -1, format("Could not get uniform '%s'", name));
            return m_locationCache[name] = cast(uint)location;
        }
        return m_locationCache[name];
    }
    override IShader setv (string name, float v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    override IShader setv (string name, int v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    override IShader setv (string name, uint v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    override IShader setv (string name, vec2 v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    override IShader setv (string name, vec3 v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    override IShader setv (string name, vec4 v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    override IShader setv (string name, mat3 v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    override IShader setv (string name, mat4 v) {
        if (gl.BindProgram(getProgram)) {
            gl.SetUniform(getLocation(name), v);
        }
        return this;
    }
    mixin RetainRelease;
    private void onReleased () {
        if (m_programObject) {
            gl.DeleteProgram(m_programObject);
            m_programObject = 0;
        }
        foreach (ref uint shader; m_shaderObjects) {
            if (shader) {
                gl.DeleteShader(shader);
                shader = 0;
            }
        }
        import std.stdio;
        writefln("releaseResource()");
        m_graphicsPool.releaseResource(this); 
    }
    auto getProgram () { return m_programObject; }
}
private class Texture : IGraphicsResource, ITexture {
    ResourcePool m_graphicsPool;
    uint         m_handle = 0;
    TextureSrcFormat m_currentFormat;
    auto             m_size = vec2i(0, 0);


    this (ResourcePool pool) {
        m_graphicsPool = pool;
    }
    override string toString () {
        return format("Texture %s (%s %s x %s) '%s'", 
            m_handle, m_currentFormat, m_size.x, m_size.y, m_graphicsPool.m_id);
    }
    override ITexture setFormat (TextureInternalFormat textureFormat) {
        assert(0, "Unimplemented!");
    }
    override ITexture fromFile (string path) {
        assert(0, "Unimplemented!");
    }

    override ITexture fromBytes (ubyte[] contents, vec2i dimensions, TextureSrcFormat srcFormat) {
        if (!m_handle) {
            gl.GenTextures(1, &m_handle);
            gl.opDispatch!"BindTexture"(GL_TEXTURE_2D, m_handle); 
        } else {
            gl.opDispatch!"BindTexture"(GL_TEXTURE_2D, m_handle);
        }
        GLenum internalFmt, baseFmt;
        final switch (srcFormat) {
            case TextureSrcFormat.RED: internalFmt = GL_R8; baseFmt = GL_RED; break;
            case TextureSrcFormat.RGB: internalFmt = GL_RGB8; baseFmt = GL_RGB; break;
            case TextureSrcFormat.RGBA: internalFmt = GL_RGBA8; baseFmt = GL_RGBA; break;
        }
        gl.TexStorage2D(GL_TEXTURE_2D, 1, internalFmt, dimensions.x, dimensions.y);
        gl.TexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, dimensions.x, dimensions.y, baseFmt,
            GL_UNSIGNED_BYTE, contents.ptr);
        gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

        m_currentFormat = srcFormat;
        m_size = dimensions;

        import std.stdio;
        writefln("buffered data: %s", this);

        return this;
    }
    override bool bindTo (uint textureSlot) {
        if (m_handle) {
            gl.ActiveTexture(GL_TEXTURE0 + textureSlot);
            gl.opDispatch!"BindTexture"(GL_TEXTURE_2D, m_handle);
            return true;
        }
        return false;
    }
    mixin RetainRelease;
    private void onReleased () {
        if (m_handle) {
            gl.DeleteTextures(1, &m_handle);
            m_handle = 0;
        }
        m_graphicsPool.releaseResource(this);
    }
}

private class Vao : IGraphicsResource, IVao {
    GL41_GraphicsContext m_graphicsContext;
    ResourcePool m_graphicsPool;
    uint        m_handle = 0;
    GLShaderRef m_boundShader;

    this (ResourcePool pool, GL41_GraphicsContext context) {
        m_graphicsPool = pool;
        m_graphicsContext = context;
    }
    override string toString () {
        return format("VAO %s '%s' | bound shader: %s", m_handle, m_graphicsPool.getId,
            m_boundShader.unwrap);
    }
    uint getHandle () {
        if (!m_handle) {
            m_handle = gl.CreateVertexArray();
        }
        return m_handle;
    }

    override void bindVertexAttrib ( uint index, GLVboRef vbo, uint count, GLType dataType,
        GLNormalized normalized, size_t stride, size_t offset)
    {
        assert( count >= 1 && count <= 4, format("Invalid count passed to bindVertexAttrib: %s!", count));

        gl.BindVertexArray(getHandle);
        gl.EnableVertexAttribArray( index ); 

        gl.opDispatch!"BindBuffer"(GL_ARRAY_BUFFER, vbo.unwrap.getHandle);
        gl.VertexAttribPointer( index, count, dataType, 
            cast(GLboolean)normalized, cast(int)stride, cast(void*)offset );

        gl.BindVertexArray(0);
    }
    override void setVertexAttribDivisor (uint index, uint divisor) {
        gl.BindVertexArray(getHandle);
        gl.VertexAttribDivisor( index, divisor );
    }
    override void bindShader ( GLShaderRef shader ) { 
        m_boundShader = shader;
        shader.unwrap.bindShader();
     }

    override void drawArrays ( GLPrimitive primitive, uint start, uint count ) {
                    import std.stdio;

        if (gl.BindProgram(m_boundShader.unwrap.getProgram) &&
            gl.BindVertexArray(getHandle)
        ) {
            gl.DrawArrays( primitive, start, count );
        } else {
            writefln("not drawing arrays!");
        }
    }
    override void drawArraysInstanced ( GLPrimitive primitive, uint start, uint count, uint instances ) {
        if (gl.BindProgram(m_boundShader.unwrap.getProgram) &&
            gl.BindVertexArray(getHandle)
        ) {
            gl.DrawArraysInstanced( primitive, start, count, instances );
        }
    }

    mixin RetainRelease;
    private void onReleased () { 
        if (m_handle) {
            gl.DeleteVertexArray(m_handle);
        }
        m_graphicsPool.releaseResource(this); 
    }
}

private class Vbo : IGraphicsResource, IVbo {
    ResourcePool m_graphicsPool;
    uint         m_handle = 0;

    this (typeof(m_graphicsPool) pool) { m_graphicsPool = pool; }

    override string toString () {
        return format("VBO %s '%s'", m_handle, m_graphicsPool.getId);
    }

    uint getHandle () {
        if (!m_handle) {
            m_handle = gl.CreateBuffer();
        }
        return m_handle;
    }
    override void bufferData (const(void)* data, size_t length, GLBufferUsage buffer_usage) {
        // TODO: Add a cpu-side data buffer + command buffer so this can be safely called
        // on threads other than the graphics thread!
        gl.opDispatch!"BindBuffer"(GL_ARRAY_BUFFER, getHandle());
        gl.opDispatch!"BufferData"(GL_ARRAY_BUFFER, length, data, buffer_usage);
    }

    mixin RetainRelease;
    private void onReleased () {
        if (m_handle) {
            gl.DeleteBuffer(m_handle);
        }
        m_graphicsPool.releaseResource(this);
    }
}
