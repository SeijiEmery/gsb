module rev3.core.opengl;
private import rev3.core.config;
private import rev3.core.resource;

public import rev3.core.math;
public import derelict.opengl3.gl3;
public import std.format: format;
import std.exception: enforce;
import std.string: toStringz;

class GLException : Exception {
    this (string message, string file = __FILE__, ulong line = __LINE__) {
        super(message, file, line);
    }
}
class GLRuntimeException : GLException {
    this (string message, string context, string file = __FILE__, ulong line = __LINE__, string fcn = __PRETTY_FUNCTION__) {
        super(format("%s while calling %s in %s", message, context, fcn), file, line);
    }
}
class GLShaderCompilationException : GLException {
    this (string message, string file = __FILE__, ulong line = __LINE__) {
        super(message, file, line);
    }
}

public string glGetMessage (GLenum err) {
    switch (err) {
        case GL_INVALID_OPERATION:              return "GL_INVALID_OPERATION";
        case GL_INVALID_ENUM:                   return "GL_INVALID_ENUM";
        case GL_INVALID_VALUE:                  return "GL_INVALID_VALUE";
        case GL_INVALID_FRAMEBUFFER_OPERATION:  return "GL_INVALID_FRAMEBUFFER_OPERATION";
        case GL_OUT_OF_MEMORY:                  return "GL_OUT_OF_MEMORY";
        default:                                assert(0, format("Invalid GLenum error value: %d", err));
    }
}

//
// Wrapped calls (Uses D types for better introspection / debugging)
//

private uint glCreateBuffer () {
    uint buffer; glGenBuffers(1, &buffer); return buffer;
}
private uint glCreateVertexArray () {
    uint vao; glGenVertexArrays(1, &vao); return vao;
}
private uint glCreateTexture () {
    uint tex; glGenTextures(1, &tex); return tex;
}
private void glDeleteBuffer (ref uint buffer) {
    glDeleteBuffers(1, &buffer); buffer = 0;
}
private void glDeleteVertexArray (ref uint vao ) {
    glDeleteVertexArrays(1, &vao); vao = 0;
}
private void glDeleteTexture (ref uint tex) {
    glDeleteTextures(1, &tex); tex = 0;
}
private void glShaderSource (uint shader, string src) {
    const(char)* source = &src[0];
    int          length = cast(int)src.length;
    derelict.opengl3.gl3.glShaderSource(shader, 1, &source, &length);
}
private bool glCompileShader (uint shader) { 
    derelict.opengl3.gl3.glCompileShader(shader);
    int result;
    derelict.opengl3.gl3.glGetShaderiv(shader, GL_COMPILE_STATUS, &result);
    return result == GL_TRUE;
}
private bool glLinkProgram (uint program) {
    derelict.opengl3.gl3.glLinkProgram(program);
    int result;
    derelict.opengl3.gl3.glGetProgramiv(program, GL_LINK_STATUS, &result);
    return result == GL_TRUE;
}
private string glGetShaderInfoLog (uint shader) {
    int length = 0;
    derelict.opengl3.gl3.glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
    if (length == 0) return "<Empty Log?!>";

    char[] log; log.length = length;
    derelict.opengl3.gl3.glGetShaderInfoLog(shader, length, &length, &log[0]);
    return cast(string)log[0 .. length];
}
private string glGetProgramInfoLog (uint program) {
    int length = 0;
    derelict.opengl3.gl3.glGetProgramiv(program, GL_INFO_LOG_LENGTH, &length);
    if (length == 0) return "<Empty Log?!>";

    char[] log;
    log.length = length;
    derelict.opengl3.gl3.glGetProgramInfoLog(program, length, &length, &log[0]);
    return cast(string)log[0 .. length];
}

private void glSetUniform (uint l, float v) { glUniform1f(l, v); }
private void glSetUniform (uint l, vec2  v) { glUniform2fv(l, 1, v.value_ptr); }
private void glSetUniform (uint l, vec3  v) { glUniform3fv(l, 1, v.value_ptr); }
private void glSetUniform (uint l, vec4  v) { glUniform4fv(l, 1, v.value_ptr); }

private void glSetUniform (uint l, mat2  v) { glUniformMatrix2fv(l, 1, true, v.value_ptr); }
private void glSetUniform (uint l, mat3  v) { glUniformMatrix3fv(l, 1, true, v.value_ptr); }
private void glSetUniform (uint l, mat4  v) { glUniformMatrix4fv(l, 1, true, v.value_ptr); }

private void glSetUniform (uint l, int   v) { glUniform1i(l, v); }
private void glSetUniform (uint l, vec2i v) { glUniform2iv(l, 1, v.value_ptr); }
private void glSetUniform (uint l, vec3i v) { glUniform3iv(l, 1, v.value_ptr); }
private void glSetUniform (uint l, vec4i v) { glUniform4iv(l, 1, v.value_ptr); }

private void glSetUniform (uint l, float[] v) { glUniform1fv(l, cast(int)v.length, &v[0]); }
private void glSetUniform (uint l, vec2[]  v) { glUniform2fv(l, cast(int)v.length, v[0].value_ptr); }
private void glSetUniform (uint l, vec3[]  v) { glUniform3fv(l, cast(int)v.length, v[0].value_ptr); }
private void glSetUniform (uint l, vec4[]  v) { glUniform4fv(l, cast(int)v.length, v[0].value_ptr); }

private void glSetUniform (uint l, mat2[]  v) { glUniformMatrix2fv(l, cast(int)v.length, true, v[0].value_ptr); }
private void glSetUniform (uint l, mat3[]  v) { glUniformMatrix3fv(l, cast(int)v.length, true, v[0].value_ptr); }
private void glSetUniform (uint l, mat4[]  v) { glUniformMatrix4fv(l, cast(int)v.length, true, v[0].value_ptr); }

private void glSetUniform (uint l, int[]   v) { glUniform1iv(l, cast(int)v.length, &v[0]); }
private void glSetUniform (uint l, vec2i[] v) { glUniform2iv(l, cast(int)v.length, v[0].value_ptr); }
private void glSetUniform (uint l, vec3i[] v) { glUniform3iv(l, cast(int)v.length, v[0].value_ptr); }
private void glSetUniform (uint l, vec4i[] v) { glUniform4iv(l, cast(int)v.length, v[0].value_ptr); }


enum GLTextureType : GLenum { 
    GL_TEXTURE_2D   = derelict.opengl3.gl3.GL_TEXTURE_2D 
}
enum GLBufferType : GLenum { 
    GL_ARRAY_BUFFER = derelict.opengl3.gl3.GL_ARRAY_BUFFER
}
enum GLBuffering : GLenum {
    GL_STATIC_DRAW  = derelict.opengl3.gl3.GL_STATIC_DRAW,
    GL_DYNAMIC_DRAW = derelict.opengl3.gl3.GL_DYNAMIC_DRAW,
}
enum GLNormalized : GLboolean {
    TRUE  = GL_TRUE,
    FALSE = GL_FALSE,
}
enum GLType : GLenum {
    FLOAT = derelict.opengl3.gl3.GL_FLOAT,
}
enum GLPrimitive : GLenum {
    GL_TRIANGLES = derelict.opengl3.gl3.GL_TRIANGLES,
    GL_TRIANGLE_STRIP = derelict.opengl3.gl3.GL_TRIANGLE_STRIP,
    GL_TRIANGLE_FAN = derelict.opengl3.gl3.GL_TRIANGLE_FAN,
    GL_POINTS = derelict.opengl3.gl3.GL_POINTS,
}

final class GLContext {
    struct ContextState {
        uint shader      = 0;
        uint vao         = 0;
        uint buffer      = 0;
        uint texture     = 0;
        int  textureSlot = -1;
    }
    ContextState m_state;

    private static bool doBind (T)(ref T target, const T value) {
        if (target != value) {
            target = value;
            return true;
        }
        return false;
    }

    // Nicely wraps all GL operations with error checking code, etc.
    // We can further "override" by defining functions like "bind" (called as "gl.bind(...)"), etc. 
    template opDispatch (string fcn) {
        auto opDispatch (
            string caller_file = __FILE__, 
            ulong caller_line = __LINE__, 
            string caller_fcn = __PRETTY_FUNCTION__, 
            Args...
        )(
            Args args
        ) {
            immutable bool hasReturn = !is(typeof(mixin("gl"~fcn)(args)) == void);

            static if (hasReturn)   auto result = mixin("gl"~fcn)(args);
            else                    mixin("gl"~fcn)(args);
 
            // If value in enum to track call #s, update that call value
            static if (__traits(compiles, mixin("GLTracedCalls."~fcn))) {
                mixin("callTraceCount[GLTracedCalls."~fcn~"]++");
            }

            static if (DEBUG_LOG_GL_CALLS) {
                import std.stdio;
                static if (hasReturn) writefln("gl%s(%s) => %s", fcn, joinArgs(args), result);
                else                  writefln("gl%s(%s)", fcn, joinArgs(args));
            }

            // Check for errors.
            checkError(format("gl%s(%s)", fcn, joinArgs(args)), caller_file, caller_line, caller_fcn);

            // Return result (if any).
            static if (hasReturn)    return result;
        }
    }
    private static string joinArgs (Args...)(Args args) {
        import std.conv;
        import std.array;

        string[] sargs;
        foreach (arg; args)
            sargs ~= arg.to!string();
        return sargs.join(", ");
    }

    // Internal call used to check errors after making GL calls.
    public void checkError (lazy string fcn, string caller_file = __FILE__, ulong caller_line = __LINE__, string caller_fcn = __PRETTY_FUNCTION__) {
        static if (GL_RUNTIME_ERROR_CHECKING_ENABLED) {
            auto err = glGetError();
            if (err != GL_NO_ERROR) {
                throw new GLRuntimeException(glGetMessage(err), fcn, caller_file, caller_line, caller_fcn);
            }
        }
    }

    // Flushes / Ignores all errors
    public void flushErrors () {
        while (glGetError()) {}
    }

    // Records GL Call count for specified calls (defined in GLTracedCalls)
    private int[GLTracedCalls.max] callTraceCount;
    public auto ref getCallCounts () { return callTraceCount; }
    public void   resetCallCounts () { callTraceCount[0..$] = 0; }


    //
    // Resource management
    //

    mixin ResourceManager!(GLResource, GLResourceType);

    public auto create (T, Args...)(Args args) { return createResource!T(this, args); }

    //
    // GL Calls, etc...
    //

    bool BindProgram (uint program) {
        if (doBind(m_state.shader, program))
            this.UseProgram(program);
        return program != 0;
    }
    bool BindVertexArray (uint vao) {
        if (doBind(m_state.vao, vao))
            this.opDispatch!"BindVertexArray"(vao);
        return vao != 0;
    }
    bool BindBuffer (uint buffer, GLBufferType bufferType) {
        if (doBind(m_state.buffer, buffer))
            this.opDispatch!"BindBuffer"(bufferType, buffer);
        return buffer != 0;
    }
    bool BindTexture (uint texture, GLTextureType textureType, int textureSlot) {
        if (doBind(m_state.textureSlot, textureSlot))
            this.opDispatch!"ActiveTexture"(GL_TEXTURE0 + textureSlot);
        if (doBind(m_state.texture, texture))
            this.opDispatch!"BindTexture"(textureType, texture);
        return texture != 0;
    }

    void CompileAndAttachShader (ref uint program, ref uint shader, GLShaderType shaderType, string src) {
        if (!program) program = this.CreateProgram();
        if (!shader)  shader  = this.CreateShader(shaderType);

        this.ShaderSource(shader, src);
        enforce(this.CompileShader(shader),
            format("Failed to compile %s shader (%s): %s", shaderType, shader, this.GetShaderInfoLog(shader)));
        this.AttachShader(program, shader);
    }
    void LinkProgram (uint program) {
        enforce!GLException(program != 0, "Failed to link shader program: null program (no bound shaders?)");
        enforce(this.opDispatch!"LinkProgram"(program),
            format("Failed to link shader program (%s): %s", program, this.GetProgramInfoLog(program)));
    }
}

// Traced calls...
enum GLTracedCalls {
    DrawArrays,
    DrawIndexed,
};

//
// Resources...
//

// Base resource class

private class GLResource : ManagedResource {
    protected GLContext gl;
    protected this (GLContext context) { this.gl = context; assert(context !is null); }
    void resourceInit (GLContext context) { this.gl = context; assert(context !is null); }
}
enum GLResourceType {
    GLShader, GLTexture, GLVertexBuffer, GLVertexArray
}
enum GLShaderType : GLenum { 
    VERTEX   = GL_VERTEX_SHADER, 
    FRAGMENT = GL_FRAGMENT_SHADER, 
    GEOMETRY = GL_GEOMETRY_SHADER,
}
enum GLStatus { None = 0x0, Ok = 0x1, Error = 0x3 }

bool ok    (GLStatus status) { return status == GLStatus.Ok;    }
bool error (GLStatus status) { return status == GLStatus.Error; }
bool none  (GLStatus status) { return status == GLStatus.None;  }

//void setOk    (ref GLStatus status, bool ok = true)    { status |= (ok ? GLStatus.Ok : GLStatus.Error);  }
//void setError (ref GLStatus status, bool err = true)   { if (err) status |= GLStatus.Error; }
//void clear    (ref GLStatus status)                    { status = GLStatus.None;   }


public class GLShader : GLResource {
    private uint                        m_program = 0;
    private Shader[GLShaderType.max+1]  m_shaders;
    private Uniform[]                   m_uniformCache;
    private GLStatus                    m_status;
    private GLException                 m_exception = null;
    private bool                        m_dirtyShader = false;

    private struct Shader {
        uint            object = 0;
        GLStatus        status = GLStatus.None;
        string          pendingSrc = null;
    }
    private struct Uniform {
        string          name;
        uint            location = 0;
    }

    this (GLContext context) { super(context); }
    override void resourceDtor () { clear(); }

    auto source (GLShaderType shaderType, string src) {
        m_shaders[shaderType].pendingSrc = src;
        m_shaders[shaderType].status     = GLStatus.None;
        m_dirtyShader = true;
        return this;
    }
    bool bind () {
        if (m_dirtyShader) {
            m_dirtyShader = false;
            recompileShaders();
        }
        if (m_status == GLStatus.Ok) {
            assert(m_program != 0);
            return gl.BindProgram(m_program);
        }
        return false;
    }
    private void recompileShaders () {
        try {
            bool needsRelink    = false;
            bool hasError       = false;
            foreach (shaderType; GLShaderType.min .. GLShaderType.max) {
                auto shader = &m_shaders[shaderType];
                if (shader.status == GLStatus.None && shader.pendingSrc) {
                    shader.status = GLStatus.Error;
                    gl.CompileAndAttachShader(m_program, shader.object, shaderType, shader.pendingSrc);
                    shader.status = GLStatus.Ok;
                    shader.pendingSrc = null;
                    needsRelink  = true;
                } else if (shader.status == GLStatus.Error) {
                    hasError = true;
                }
            }
            if (needsRelink) {
                gl.LinkProgram(m_program);
                m_status    = GLStatus.Ok;
                m_exception = null;
                clearUniformCache();
            } else if (hasError) {
                m_status = GLStatus.Error;
            } else {
                m_status    = GLStatus.None;
                m_exception = null;
            }
        } catch (GLException ex) {
            m_status    = GLStatus.Error;
            m_exception = ex;
            throw ex;
        }
    }
    auto clear () {
        m_status = GLStatus.None;
        if (m_program) {
            gl.DeleteProgram(m_program);
            m_program = 0;
        }
        foreach (ref shader; m_shaders) {
            if (shader.object) {
                gl.DeleteShader(shader.object);
                shader.object = 0;
                shader.status = GLStatus.None;
            }
        }
        return this;
    }
    auto setUniform (T)(string name, T value) {
        if (bind()) {
            auto loc = getUniformLocation(name);
            enforce(loc >= 0, format("No matching uniform for '%s'", name));
            gl.SetUniform(loc, value);
        }
        return this;
    }
    private uint getUniformLocation (string name) {
        foreach (ref uniform; m_uniformCache) {
            if (uniform.name == name) {
                return uniform.location;
            }
        }
        uint location = gl.GetUniformLocation(m_program, name.toStringz);
        m_uniformCache ~= Uniform(name, location);
        return location;
    }
    private void clearUniformCache () {
        m_uniformCache.length = 0;
    }
}
public class GLVertexArray : GLResource {
    uint m_object = 0;

    this (GLContext context) { super(context); }
    override void resourceDtor () { clear(); }

    uint get () {
        if (!m_object) {
            m_object = gl.CreateVertexArray();
        }
        return m_object;
    }
    bool bind () {
        return gl.BindVertexArray(get());
    }
    auto clear () {
        if (m_object) {
            gl.DeleteVertexArray(m_object);
            m_object = 0;
        }
        return this;
    }
    void bindVertexAttrib (uint index, ref Ref!GLVertexBuffer vbo, int count, GLType type,
        GLNormalized normalized, size_t stride, size_t offset
    ) {
        if (bind() && vbo.bind()) {
            gl.EnableVertexAttribArray(index);
            gl.VertexAttribPointer(index, count, type, normalized, cast(int)stride, cast(void*)offset);
            gl.BindVertexArray(0);
        }
    }
    void setVertexAttribDivisor (uint index, uint divisor) {
        if (bind()) {
            gl.VertexAttribDivisor(index, divisor);
            gl.BindVertexArray(0);
        }
    }
}
public class GLBuffer (GLBufferType BufferType) : GLResource {
    uint m_object = 0;
    this (GLContext context) { super(context); }
    override void resourceDtor () { clear(); }

    uint get () {
        if (!m_object) {
            m_object = gl.CreateBuffer();
        }
        return m_object;
    }
    bool bind () {
        return gl.BindBuffer(get(), BufferType);
    }
    auto clear () {
        if (m_object) {
            gl.DeleteBuffer(m_object);
        }
        return this;
    }
    void bufferData (T)(T[] data, GLBuffering buffering) {
        if (bind()) {
            gl.BufferData(BufferType, data.length, data.ptr, buffering);
        }
    }
}
public class GLVertexBuffer : GLBuffer!(GLBufferType.GL_ARRAY_BUFFER) {
    this (GLContext context) { super(context); }
}

public class GLTexture : GLResource {
    this (GLContext context) { super(context); }

    override void resourceDtor () {

    }
}










