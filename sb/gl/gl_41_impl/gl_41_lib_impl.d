module sb.gl.gl_impl;
import sb.gl;

import derelict.opengl3.gl3;
import gl3n.linalg;
import std.exception: enforce;
import std.format;
import core.sync.mutex;


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


    override IBatch   createBatch   () { return null; }
    override IBatch   getLocalBatch () { return null; }
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
}

private mixin template RetainRelease () {
    import core.atomic;

    override void release () {
        auto count = atomicOp!"-="(m_rc, 1);
        if (count == 0)
            this.onReleased();
    }
    override void retain () {
        atomicOp!"+="(m_rc, 1);
    }
    void forceRelease () {
        uint count;
        do {
            count = m_rc;
        } while (!cas(&m_rc, count, 0));

        if (count > 0)
            this.onReleased();
    }
    private shared int m_rc = 1;
}

private class ResourcePool : IGraphicsResourcePool {
    string               m_id;
    GL41_GraphicsContext m_graphicsContext;
    IGraphicsResource[]  m_activeResources;
    Mutex m_mutex;

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
    mixin RetainRelease;
    private void onReleased () { m_graphicsContext.releasePool(this); }

    void releaseAll () {
        synchronized (m_mutex) {
            foreach (resource; m_activeResources)
                resource.forceRelease();
            m_activeResources.length = 0;
        }
    }
    void releaseResource (IGraphicsResource resource) {
        synchronized (m_mutex) {
            foreach (i, v; m_activeResources) {
                if (resource == v) {
                    m_activeResources[i] = m_activeResources[$-1];
                    --m_activeResources.length;
                }
            }
        }
    }
}

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
private auto getProgramInfoLog ( uint program ) {
    int length = 0;
    glGetProgramIv(program, GL_LINK_STATUS, &length);
}

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
        case GL_STACK_UNDERFLOW: return "GL_STACK_UNDERFLOW";
        case GL_STACK_OVERFLOW:  return "GL_STACK_OVERFLOW";
        default: return format("Unknown error %s", err);
    }
}


private interface IGraphicsResource {
    void forceRelease ();
}

private class Shader : IGraphicsResource, IShader {
    ResourcePool m_graphicsPool;

    bool                   m_hasPendingRecompile = false;
    string[ShaderType.max] m_pendingSrc    = null;
    uint  [ShaderType.max] m_shaderObjects = 0;
    uint                   m_programObject = 0;
    bool m_isBindable = false;

    this (ResourcePool pool) {
        m_graphicsPool = pool;
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
            size_t       length = src.length;

            // Compile shader
            glShaderSource( shader, 1, &source, &length );
            glCompileShader( shader );

            enforce( glGetCompileStatus(shader) == GL_TRUE,
                format("Failed to compile %s shader: %s", type, getInfoLog(shader)));
            glEnforceOk("glShaderSource / glCompileShader (%s, %s)", type, shader);

            // Attach to program object
            glAttachShader( m_programObject, shader );
            glEnforceOk("Failed to attach shader? (%s, %s)", type, getInfoLog(shader));
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
            foreach (i; 0 .. ShaderType.max) {
                if (m_pendingSrc[i]) {
                    recompileShader( m_shaderObjects[i], cast(ShaderType)i, m_pendingSrc[i] );
                    didRecompile = true;
                }
            }
            if (didRecompile) {
                glLinkProgram( m_programObject );
                enforce( glGetLinkStatus(m_programObject) == GL_TRUE,
                    format("Failed to link shader program: %s", getProgramInfoLog(m_programObject)));
                glEnforceOk("glLinkProgram");
            }
            m_isBindable = true;
        }
        try {
            maybeRecompileShaders();
            if (m_isBindable) {
                glUseProgram( m_programObject );
                glEnforceOk("glUseProgram: %s", m_programObject);
                return true;
            }
            return false;
        } catch (Exception e) {
            writefln("Error while recompiling shader(s):\n%s", e);
            return false;
        }
    }

    override IShader source (ShaderType type, string path) {
        assert(0, "Unimplemented! set shader source from path");
    }
    override IShader rawSource (ShaderType type, string contents) {

        return this;
    }
    override IShader setv (string name, float value) {
        return this;
    }
    override IShader setv (string name, int value) {
        return this;
    }
    override IShader setv (string name, uint value) {
        return this;
    }
    override IShader setv (string name, vec2 value) {
        return this;
    }
    override IShader setv (string name, vec3 value) {
        return this;
    }
    override IShader setv (string name, vec4 value) {
        return this;
    }
    override IShader setv (string name, mat3 value) {
        return this;
    }
    override IShader setv (string name, mat4 value) {
        return this;
    }
    mixin RetainRelease;
    private void onReleased () { m_graphicsPool.releaseResource(this); }
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
    private void onReleased () { m_graphicsPool.releaseResource(this); }
}





