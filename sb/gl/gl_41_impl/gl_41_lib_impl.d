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

private interface IGraphicsResource {
    void forceRelease ();
}

private class Shader : IGraphicsResource, IShader {
    ResourcePool m_graphicsPool;


    this (ResourcePool pool) {
        m_graphicsPool = pool;
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





