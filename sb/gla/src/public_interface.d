module sb.gla.public_interface;

enum GLAResourceType { None = 0, Shader, Texture2d, Vbo, Vao }
enum GLADepthTest { None = 0, Always, Less, LEqual, Greater, GEqual, Equal, NotEqual }

enum GLAShaderType { Vertex = 0, Fragment, Geometry }
enum GLAShaderStatus { NOT_COMPILED = 0, COMPILED, COMPILE_ERROR, LINK_ERROR }

alias GLAShaderErrorDelegate = void delegate(GLAResource*, GLAShaderCompilationException);
class GLAShaderCompilationException : RuntimeException {
    GLAShaderStatus status;
    this (GLAShaderStatus status, string msg, file = __FILE__, line = __LINE__) {
        this.status = status;
        super(msg, file, line);
    }
}

alias ShaderUniformValue = Algebraic!(
    uint, int, vec2i, vec3i, vec4i,
    float, vec2, vec3, vec4,
    mat3, mat4);

// Opaque GL context interface.
interface IGLAContext {
    // Threadsafe methods:
    IGLACommandBuffer createCommandBuffer (string ident = null);
    GLAResource*      createResource (GLAResourceType type, string ident = null);

    // Graphics-thread only methods:
    bool gthread_execFrameAction ();
}

// Opaque commandbuffer interface
interface IGLACommandBuffer {
    void retain  ();
    void release ();

    GLAResource* createResource (GLAResourceType type, string ident = null);
    void submitFrame ();

    // Error handling functions for this commandBuffer:
    //  – setErrorHandler: block that can handle (or rethrow) unhandled GLA runtime exceptions.
    //  – setErrorPolicy:  error policy dictates what this CB should do when
    //    recieving runtime errors. Options include continuing as normal, skipping
    //    the rest of this frame, or skipping this and all future frames until
    //    the error is reset via clearError().
    //  – currentError: get current error (None if ok)
    //  – clearError: restarts CB if was paused due to error.
    // 
    void setErrorHandler (GLAErrorDelegate onError);
    void setErrorPolicy  (GLAErrorHaltPolicy errorPolicy);    
    GLACommandErrorStatus currentError ();
    void clearError ();

    //
    // GLA methods (note that these must all be run via a command buffer).
    //
    // Since these are all async:
    // – direct opengl access (ie. from arbitrary threads) is illegal
    // – as such, calls can't tell you (via return values / exceptions) whether
    //   a call failed or not. Instead:
    // - some functions accept async error delegates that can be run on the graphics thread
    // - if that fails (and for more general cases), you can set a global error
    //   handler function for all calls made from this command buffer.
    // – function arguments _are_ checked where appropriate; invalid arguments
    //   will trigger a GLAUsageException if an invalid value was passed (eg.
    //   resource is an invalid type; we can check some of the more obvious
    //   problems on this side, before packing into the command buffer)
    //

    //
    // State functions, etc.,
    //

    // Run directly on the graphics thread; use for features that haven't yet
    // been implemented in gla, or for idk, logging messages or something.
    void runGL (void delegate(IGLADirectContext) callback);

    // glClearColor
    void clearColor (vec4 color);

    // set various gl states
    void setTransparency (bool enabled);
    void setDepthTest    (bool enabled, GLADepthTest func = GLADepthTest.Less);

    // bind shader / vao / vbo / texture / etc. type must match the resource type.
    void bind (GLAResource* resource, GLAResourceType type);

    //
    // Shader functions
    //

    // Set shader source for a shader part. Shader will be created and/or recompiled + relinked as necessary.
    // If recompilation fails for any reason, optionally calls onError() on the graphics thread.
    void setShaderSrc     (GLAResource* shader, GLAShaderType shaderType, string src,  GLAShaderErrorDelegate onError = null);

    // Sets a shader uniform.
    void setShaderUniform (GLAResource* shader, string name, ShaderUniformValue value, GLAShaderErrorDelegate onError = null);

    // Set an onLink function to get run on the graphics thread each time the
    // shader is recompiled successfully (or the optional error delegate if 
    // compilation failed).
    //
    // This has direct access to all shader values, and can do stuff like iterate
    // over shader uniforms + subroutines, etc, and is basically intended to setup
    // shader values after (re)-complation.
    //
    // Presently this is the _only_ way to get the indices needed to use shader
    // subroutines and other advanced features (well, you could use runOnShader,
    // but this gets run automatically and only needs to be set once).
    //
    void onShaderLink (GLAResource* shader, void delegate(IGLADirectShader) onLink, GLAShaderErrorDelegate onError = null);

    // Run some arbitrary code on the graphics thread. Needed to get direct 
    // access to shader values (as opposed to setting things asynchronously).
    // Same semantics as onShaderLink; onError gets called if the shader is in
    // in invalid state, or callback terminated with an unhandled error.
    void runOnShader (GLAResource* shader, void delegate(IGLADirectShader) callback, GLAShaderErrorDelegate onError = null);

    // Vbo functions
}

// Encapsulates direct access to an opengl shader.
// Can only be accessed via graphics thread, so access must be wrapped in an async 
// callback run on a command buffer (see setShaderOnLink / runOnShader).
//
// The following methods will be run directly and can thus access runtime shader
// values (ie. iterate over uniforms, subroutines + bind points, etc), and will
// throw GLA runtime exceptions on invalid arguments / etc.
//
interface IGLADirectShader {
    GLAResource* resource ();
    uint         handle   ();
    GLAShaderStatus status ();

    Tuple!(string, uint, GLAShaderUniformType)[] enumerateUniforms ();
    Tuple!(string, uint)[]                       enumerateSubroutines ();
    Tuple!(string, uint)[]                       enumerateSubroutineValues (uint subroutine);

    uint getUniform (string name, GLAShaderUniformType type);
    uint getSubroutineValue (string fcn, string value);

    void setUniform    (uint uniform, ShaderUniformValue value);
    void setSubroutine (uint subroutine, uint value);
}

// Ditto for the entire context / state functions + resources.
// Basically mirrored functionality that runs directly on the graphics thread.
//
// Do NOT call save + call into this from any other thread.
// Methods will return GLA runtime exceptions on invalid arguments / GL state,
// so make sure you have try / catch blocks.
//
interface IGLADirectContext {
    // Get global context / current command buffer to create resources, etc.
    // _can_ issue regular commands via the command buffer (which is technically
    // a separate graphics-thread-only object just aliased to the command buffer
    // your callback was run from), but call order is pretty much undefined (ie.
    // if you're writing to it from another thread), and commands will not be
    // run until the next frame.
    IGLAContext       globalContext ();
    IGLACommandBuffer commandBuffer ();

    // Immediate mode API (same API, but will throw GLA runtime exceptions if
    // arguments _or_ GL state is invalid)

    void clearColor (vec4 color);
    void setTransparency (bool enabled);
    void setDepthTest    (bool enabled, GLADepthTest func = GLADepthTest.Less);
    void bind (GLAResource* resource, GLAResourceType type);
}



// Opaque resource handle (wraps shaders, buffers, textures, etc)
// Memory is managed internally in a packed, recycled variant array.
// We're using variants / structs and raw pointers instead of classes for 
// our resource (and command buffer) impl b/c we want deterministic destruction
// (can finely control this w/ structs + manually managed memory), and we _don't_
// want to use GC memory for small, (potentially) frequently allocated objects.
// 
// Our event system + command buffers are implemented using variant structs for
// exactly that reason (hundreds / thousands of GC allocations per frame would
// be horrible), and it makes sense that we might as well use the same system
// for resources.
//
// Ofc, infrequently allocated objects (eg. UI) make perfect sense to use gc-ed
// classes for, so the rest of our API uses interfaces for persistent-ish objects.
//
struct GLAResource {
    private GLAResourceType m_type = GLAResourceType.None;
    private int             m_refCount = 0;

    auto type () { return m_type; }
    auto rc   () { return m_refCount; }

    void retain () { ++m_refCount; }
    void release () { --m_refCount; }

    void setType (GLAResourceType type) {
        assert(m_type == GLAResourceType.None, format(
            "Invalid: GLAResource attempting to overwrite type %s with %s",
            m_type, type));
        m_type = type;
        m_refCount = 0;
    }
}



