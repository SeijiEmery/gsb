module sb.gl.gl_impl;
import sb.gl;

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

    // Internal state bindings
    bool bindVao ( Vao vao, uint handle ) {
        if (vao != m_lastBoundVao || handle != m_lastBoundVaoHandle) {
            glBindVertexArray( handle );
            m_lastBoundVao = vao;
            m_lastBoundVaoHandle = handle;
        }
        return handle != 0;
    }
    void unbindVao () {
        if (m_lastBoundVao) {
            glBindVertexArray( 0 );
            m_lastBoundVao = null;
        }
    }

    bool bindShader ( Shader shader ) {
        if (shader != m_lastBoundShader) {
            m_lastBoundShader = shader;
            return m_shaderOk = shader.bindShader();
        }
        return m_shaderOk;
    }

private:
    vec4 m_clearColor;
    ResourcePool[] m_resourcePools;
    Mutex m_mutex;
    Batch m_localBatch = null;

    // Internal state bindings
    Vao  m_lastBoundVao = null;
    uint m_lastBoundVaoHandle;

    Shader m_lastBoundShader = null;
    bool   m_shaderOk = false;
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

// GL utilities

private auto toGLEnum (ShaderType type) {
    final switch (type) {
        case ShaderType.VERTEX:  return GL_VERTEX_SHADER;
        case ShaderType.FRAGMENT: return GL_FRAGMENT_SHADER;
        case ShaderType.GEOMETRY: return GL_GEOMETRY_SHADER;
    }
}
private auto glGetCompileStatus ( uint shader ) {
    int result;
    glGetShaderiv( shader, GL_COMPILE_STATUS, &result );
    return result;
}
private auto getShaderInfoLog ( uint shader ) {
    int length = 0;
    glGetShaderiv( shader, GL_INFO_LOG_LENGTH, &length );

    char[] log;
    log.length = length;
    glGetShaderInfoLog( shader, length, &length, &log[0] );
    return log[ 0 .. length ];
}
private auto glGetLinkStatus ( uint program ) {
    int result;
    glGetProgramiv( program, GL_LINK_STATUS, &result );
    return result;
}
private auto getProgramInfoLog ( uint program ) {
    int length = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &length);

    char[] log;
    log.length = length;
    glGetProgramInfoLog( program, length, &length, &log[0] );
    return log [ 0 .. length ];
}

// GL error checking

private void glAssertOk (lazy string msg, string file = __FILE__, size_t line = __LINE__) {
    auto err = glGetError();
    assert( err == GL_NO_ERROR, format("GL ERROR: %s | %s, %s: %s", 
        err.glErrorToString, file, line, msg ));
}
private void glEnforceOk (lazy string msg, string file = __FILE__, size_t line = __LINE__) {
    auto err = glGetError();
    enforce( err == GL_NO_ERROR, format("GL ERROR: %s | %s, %s: %s",
        err.glErrorToString, file, line, msg ));
}
private void glFlushErrors (string file = __FILE__, size_t line = __LINE__) {
    GLenum err;
    import std.stdio;
    while ((err = glGetError()) != GL_NO_ERROR)
        writefln("Uncaught error: %s (%s, %s)", err.glErrorToString, file, line);
}
private auto glErrorToString ( GLenum error ) {
    switch (error) {
        case GL_NO_ERROR: return "GL_NO_ERROR";
        case GL_INVALID_ENUM: return "GL_INVALID_ENUM";
        case GL_INVALID_VALUE: return "GL_INVALID_VALUE";
        case GL_INVALID_OPERATION: return "GL_INVALID_OPERATION";
        case GL_INVALID_FRAMEBUFFER_OPERATION: return "GL_INVALID_FRAMEBUFFER_OPERATION";
        case GL_OUT_OF_MEMORY: return "GL_OUT_OF_MEMORY";
        //case GL_STACK_UNDERFLOW: return "GL_STACK_UNDERFLOW";
        //case GL_STACK_OVERFLOW:  return "GL_STACK_OVERFLOW";
        default: return format("Unknown error %s", error);
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
    string[ShaderType.max] m_pendingSrc    = null;
    uint  [ShaderType.max] m_shaderObjects = 0;
    uint                   m_programObject = 0;
    uint [string]          m_locationCache;
    Tuple!(ShaderType,string,string,uint)[] m_subroutineCache;
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
        void recompileShader ( ref uint shader, ShaderType type, string src ) {
            // Create shader if it doesn't already exist
            if (!shader) {
                shader = glCreateShader( type.toGLEnum );
                glAssertOk( format("Error creating shader? (%s)", type) );
            }

            assert( shader, format("Could not create shader! (%s)", type ));

            const(char)* source = &src[0];
            int    length = cast(int)src.length;

            // Compile shader
            glShaderSource( shader, 1, &source, &length );
            glCompileShader( shader );

            enforce( glGetCompileStatus(shader) == GL_TRUE,
                format("Failed to compile %s shader: %s", type, getShaderInfoLog(shader)));
            glEnforceOk(format("glShaderSource / glCompileShader (%s, %s)", type, shader));

            // Attach to program object
            glAttachShader( m_programObject, shader );
            glEnforceOk(format("Failed to attach shader? (%s, %s)", type, getShaderInfoLog(shader)));
        }
        void maybeRecompileShaders () {
            if (!m_hasPendingRecompile)
                return;

            m_isBindable = false;
            glFlushErrors();

            if (!m_programObject) {
                m_programObject = glCreateProgram();
                glAssertOk("Could not create program object?");
                assert( m_programObject, "did not create program object!" );
            }
            bool didRecompile = false;
            foreach (uint i; 0 .. ShaderType.max) {
                if (m_pendingSrc[i]) {
                    auto src = m_pendingSrc[i]; m_pendingSrc[i] = null;
                    recompileShader( m_shaderObjects[i], cast(ShaderType)i, src );
                    didRecompile = true;
                }
            }
            if (didRecompile) {
                foreach (k, v; m_locationCache)
                    m_locationCache.remove(k);

                glLinkProgram( m_programObject );
                enforce( glGetLinkStatus(m_programObject) == GL_TRUE,
                    format("Failed to link shader program: %s", getProgramInfoLog(m_programObject)));
                glEnforceOk("glLinkProgram");
            }
            m_hasPendingRecompile = false;
            m_isBindable = true;
        }
        try {
            maybeRecompileShaders();
            if (m_isBindable) {
                glUseProgram( m_programObject );
                glEnforceOk(format("glUseProgram: %s", m_programObject));
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

    override IShader source (ShaderType type, string path) {
        assert(0, "Unimplemented! set shader source from path");
    }
    override IShader rawSource (ShaderType type, string contents) {
        m_hasPendingRecompile = true;
        m_pendingSrc[type] = contents;

        // Temp hack to test shader compilation (it works!)
        if (m_pendingSrc[ShaderType.FRAGMENT] && m_pendingSrc[ShaderType.VERTEX]) {
            import std.stdio;
            writefln("Recompiling shader");
            if (bindShader())
                writefln("Shader compiled successfully + program %s bound!", m_programObject);
        }
        return this;
    }
    override IShader useSubroutine (ShaderType type, string name, string value) {
        uint shaderType = type.toGLEnum;
        uint fetchSubroutineUniform () {
            if (name !in m_locationCache) {
                int location = glGetSubroutineUniformLocation(m_programObject, shaderType, name.toStringz);
                enforce(location != -1, format("Could not get subroutine uniform '%s'", name));
                glAssertOk(format("glGetSubroutineUniformLocation(%s, %s, %s)", m_programObject, type, name));
                return m_locationCache[name] = location;
            }
            return m_locationCache[name];
        }
        uint fetchSubroutineValue () {
            foreach (ref entry; m_subroutineCache) {
                if (entry[0] == type && entry[1] == name && entry[2] == value)
                    return entry[3];
            }
            auto subroutine = glGetSubroutineIndex(m_programObject, shaderType, value.toStringz);
            enforce(subroutine != -1, format("Could not get subroutine value '%s': '%s'", name, value));
            glAssertOk(format("glGetSubroutineIndex(%s, %s, %s)", m_programObject, type, value));
            m_subroutineCache ~= tuple(type, name, value, subroutine);
            return subroutine;
        }
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glFlushErrors();
            //uint[2] kv = [ fetchSubroutineUniform(), fetchSubroutineValue() ];
            uint index = fetchSubroutineUniform();
            uint v     = fetchSubroutineValue();
            enforce( index == 0, format("Index != 0: %s", index));

            glUniformSubroutinesuiv( shaderType, 1, &v );
            glAssertOk(format("glUniformSubroutinesuiv(%s, 1, %s)", type, v));
        }
        return this;
    }
    uint getLocation (string name) {
        if (name !in m_locationCache) {
            glFlushErrors();
            int location = glGetUniformLocation(m_programObject, name.toStringz);
            enforce(location != -1, format("Could not get uniform '%s'", name));
            glAssertOk(format("glGetUniformLocation(%s, %s)", m_programObject, name));
            return m_locationCache[name] = cast(uint)location;
        }
        return m_locationCache[name];
    }
    override IShader setv (string name, float v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniform1f( getLocation(name), v );
            glAssertOk(format("glUniform(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    override IShader setv (string name, int v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniform1i( getLocation(name), v );
            glAssertOk(format("glUniform(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    override IShader setv (string name, uint v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniform1ui( getLocation(name), v );
            glAssertOk(format("glUniform(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    override IShader setv (string name, vec2 v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniform2fv( getLocation(name), 1, v.value_ptr );
            glAssertOk(format("glUniform(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    override IShader setv (string name, vec3 v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniform3fv( getLocation(name), 1, v.value_ptr );
            glAssertOk(format("glUniform(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    override IShader setv (string name, vec4 v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniform4fv( getLocation(name), 1, v.value_ptr );
            glAssertOk(format("glUniform(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    override IShader setv (string name, mat3 v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniformMatrix3fv( getLocation(name), 1, true, v.value_ptr );
            glAssertOk(format("glUniformMatrix(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    override IShader setv (string name, mat4 v) {
        if (m_graphicsPool.m_graphicsContext.bindShader(this)) {
            glUniformMatrix4fv( getLocation(name), 1, true, v.value_ptr );
            glAssertOk(format("glUniformMatrix(%s (%s), %s)", name, getLocation(name), v));
        }
        return this;
    }
    mixin RetainRelease;
    private void onReleased () {
        if (m_programObject) {
            glDeleteProgram(m_programObject);
            m_programObject = 0;
        }
        foreach (ref uint shader; m_shaderObjects) {
            if (shader) {
                glDeleteShader(shader);
                shader = 0;
            }
        }
        import std.stdio;
        writefln("releaseResource()");
        m_graphicsPool.releaseResource(this); 
    }
}
private class Texture : IGraphicsResource, ITexture {
    ResourcePool m_graphicsPool;

    this (ResourcePool pool) {
        m_graphicsPool = pool;
    }
    override ITexture setFormat (TextureInternalFormat textureFormat) {
        assert(0, "Unimplemented!");
    }
    override ITexture fromFile (string path) {
        assert(0, "Unimplemented!");
    }
    override ITexture fromBytes (ubyte[] contents, vec2i dimensions, TextureSrcFormat srcFormat) {
        assert(0, "Unimplemented!");
    }
    mixin RetainRelease;
    private void onReleased () { 
        m_graphicsPool.releaseResource(this);
    }
}

private auto toGLEnum ( GLType type ) {
    final switch (type) {
        case GLType.BYTE: return GL_BYTE;
        case GLType.UNSIGNED_BYTE: return GL_UNSIGNED_BYTE;
        case GLType.SHORT: return GL_SHORT;
        case GLType.UNSIGNED_SHORT: return GL_UNSIGNED_SHORT;
        case GLType.INT: return GL_INT;
        case GLType.UNSIGNED_INT: return GL_UNSIGNED_INT;
        case GLType.FIXED: return GL_FIXED;
        case GLType.HALF_FLOAT: return GL_HALF_FLOAT;
        case GLType.FLOAT: return GL_FLOAT;
        case GLType.DOUBLE: return GL_DOUBLE;
    }
}
private auto toGLEnum ( GLPrimitive primitive ) {
    final switch (primitive) {
        case GLPrimitive.POINTS: return GL_POINTS;
        case GLPrimitive.LINES:  return GL_LINES;
        case GLPrimitive.LINE_STRIP: return GL_LINE_STRIP;
        case GLPrimitive.LINE_LOOP: return GL_LINE_LOOP;
        case GLPrimitive.TRIANGLES: return GL_TRIANGLES;
        case GLPrimitive.TRIANGLE_STRIP: return GL_TRIANGLE_STRIP;
        case GLPrimitive.TRIANGLE_FAN: return GL_TRIANGLE_FAN;
    }
}

private class Vao : IGraphicsResource, IVao {
    ResourcePool         m_graphicsPool;
    GL41_GraphicsContext m_graphicsContext;
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
            glGenVertexArrays(1, &m_handle);
            glAssertOk("glGenVertexArrays");
            assert( m_handle, "glGenVertexArrays returned null!");
        }
        return m_handle;
    }

    override void bindVertexAttrib ( uint index, GLVboRef vbo, uint count, GLType dataType,
        GLNormalized normalized, size_t stride, size_t offset)
    {
        assert( count >= 1 && count <= 4, format("Invalid count passed to bindVertexAttrib: %s!", count));

        glFlushErrors();
        m_graphicsContext.bindVao( this, getHandle() );
        //glBindVertexArray( getHandle() ); glAssertOk("glBindVertexArray");

        glEnableVertexAttribArray( index ); 
        glAssertOk(format("glEnableVertexAttribArray(%s)", index));

        glBindBuffer( GL_ARRAY_BUFFER, vbo.unwrap.getHandle );
        glAssertOk(format("glBindBuffer(GL_ARRAY_BUFFER, %s)", vbo.unwrap.getHandle));

        glVertexAttribPointer( index, count, dataType.toGLEnum, 
            cast(GLboolean)normalized, cast(int)stride, cast(void*)offset );
        glAssertOk(format("glVertexAttribPointer(%s, %s, %s, %s, %s, %s)",
            index, count, dataType, normalized, stride, offset));

        m_graphicsContext.unbindVao();
    }
    override void setVertexAttribDivisor (uint index, uint divisor) {
        glFlushErrors();
        m_graphicsContext.bindVao( this, getHandle() );
        glVertexAttribDivisor( index, divisor );
        glAssertOk(format("glVertexAttribDivisor(%s, %s)", index, divisor));
    }
    override void bindShader ( GLShaderRef shader ) { 
        m_boundShader = shader;
        shader.unwrap.bindShader();
     }

    override void drawArrays ( GLPrimitive primitive, uint start, uint count ) {
                    import std.stdio;

        if (m_graphicsContext.bindShader(m_boundShader.unwrap),
            m_graphicsContext.bindVao( this, getHandle())
        ) {
            glDrawArrays( primitive.toGLEnum, start, count );
            glAssertOk(format("glDrawArrays(%s, %s, %s)", primitive, start, count));
        } else {
            writefln("not drawing arrays!");
        }
    }
    override void drawArraysInstanced ( GLPrimitive primitive, uint start, uint count, uint instances ) {
        if (m_graphicsContext.bindShader(m_boundShader.unwrap),
            m_graphicsContext.bindVao( this, getHandle())
        ) {
            glDrawArraysInstanced( primitive.toGLEnum, start, count, instances );
            glAssertOk(format("glDrawArrays(%s, %s, %s)", primitive, start, count));
        }
    }

    mixin RetainRelease;
    private void onReleased () { 
        if (m_handle) {
            glDeleteVertexArrays(1, &m_handle);
            m_handle = 0;
        }
        m_graphicsPool.releaseResource(this); 
    }
}

private auto toGLEnum ( GLBuffering buffering ) {
    final switch (buffering) {
        case GLBuffering.STATIC_DRAW:  return GL_STATIC_DRAW;
        case GLBuffering.DYNAMIC_DRAW: return GL_DYNAMIC_DRAW;
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
            glGenBuffers(1, &m_handle);
            glAssertOk("glGenBuffers");
            assert( m_handle, "glGenBuffers returned null!" );
        }
        return m_handle;
    }
    override void bufferData (const(void)* data, size_t length, GLBuffering buffer_usage) {
        // TODO: Add a cpu-side data buffer + command buffer so this can be safely called
        // on threads other than the graphics thread!

        glFlushErrors();
        glBindBuffer( GL_ARRAY_BUFFER, getHandle() );
        glBufferData( GL_ARRAY_BUFFER, length, data, buffer_usage.toGLEnum );
        glAssertOk(format("glBufferData( %s, %s, %s, %s)", getHandle, length, data, buffer_usage));
    }

    mixin RetainRelease;
    private void onReleased () {
        if (m_handle) {
            glDeleteBuffers(1, &m_handle);
            m_handle = 0;
        }
        m_graphicsPool.releaseResource(this);
    }
}
