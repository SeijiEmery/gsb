module sb.gl.impl.gl_41_lib_impl;
import sb.gl;

import derelict.opengl3.gl3;
import gl3n.linalg;
import std.exception: enforce;
import std.format;


// Create graphics lib.
// Note: this is kinda tied into the glfw3 platform impl,
// so if/when adding additional platforms this abstraction mechanism
// might need to be changed...
IGraphicsLib sbCreateGraphicsLib (GraphicsLibVersion glVersion) {
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
    IBatch   createBatch   () { return null; }
    IBatch   getLocalBatch () { return null; }
    ITexture createTexture () { return null; }
    IShader  createShader  () { return null; }
    void endFrame () {}
    void teardown () {}
}
