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

private void glShaderSource (uint shader, string src) { 
    const(char)* source = &src[0];
    int          length = cast(int)src.length;
    derelict.opengl3.gl3.glShaderSource(shader, 1, &source, &length);
}
private bool glGetShaderCompileStatus (uint shader) {
    int result;
    derelict.opengl3.gl3.glGetShaderiv(shader, GL_COMPILE_STATUS, &result);
    return result == GL_TRUE;
}
private int glGetShaderInfoLogLength (uint shader) {
    int result;
    derelict.opengl3.gl3.glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &result);
    return result;
}
private bool glGetProgramLinkStatus (uint program) {
    int result;
    derelict.opengl3.gl3.glGetShaderiv(program, GL_LINK_STATUS, &result);
    return result == GL_TRUE;
}
private int glGetProgramInfoLogLength (uint program) {
    int result;
    derelict.opengl3.gl3.glGetProgramiv(program, GL_INFO_LOG_LENGTH, &result);
    return result;
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





final class GLContext {
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
                static if (hasReturn) writefln("gl%s(%s) = %s", fcn, joinArgs(args), result);
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


    //private ResourceManager!(GLResource, GLResourceType) resourceManager;
    //public auto create (T, Args...)(Args args) {
    //    return resourceManager.create!T(this, args);
    //}
    //public void gcResources () {
    //    resourceManager.gcResources();
    //}
    //public auto ref getActiveResources () {
    //    return resourceManager.getActive();
    //}



    //
    // GL Calls, etc...
    //

    uint m_program = 0;
    bool BindProgram (uint program) {
        if (program != m_program) {
            this.UseProgram(m_program = program);
        }
        return program != 0;
    }

    string GetShaderInfoLog (uint shader) {
        int length = this.GetShaderInfoLogLength(shader);
        if (length == 0) return "<Empty Log?!>";

        char[] log;
        log.length = length;

        this.opDispatch!"GetShaderInfoLog"( shader, length, &length, &log[0] );
        return cast(string)log[ 0 .. length ];
    }
    void CheckCompileStatus (uint shader, GLShaderType shaderType) {
        enforce!GLShaderCompilationException(
            this.GetShaderCompileStatus(shader),
            format("Failed to compile %s shader (%s): %s", shaderType, shader, this.GetShaderInfoLog(shader)));
    }

    string GetProgramInfoLog (uint program) {
        int length = this.GetProgramInfoLogLength(program);
        if (length == 0) return "<Empty Log?!>";

        char[] log;
        log.length = length;

        this.opDispatch!"GetProgramInfoLog"( program, length, &length, &log[0] );
        return cast(string)log[0 .. length];
    }
    void CheckLinkStatus (uint program) {
        enforce!GLShaderCompilationException(
            this.GetProgramLinkStatus(program),
            format("Failed to link shader program (%s): %s", program, this.GetProgramInfoLog(program)));
    }

    void CompileAndAttachShader (ref uint program, ref uint shader, GLShaderType shaderType, string src) {
        if (!program) program = this.CreateProgram();
        if (!shader)  shader  = this.CreateShader(shaderType);

        this.ShaderSource(shader, src);
        this.CheckCompileStatus(shader, shaderType);
        this.AttachShader(program, shader);
    }
    void LinkProgram (uint program) {
        enforce!GLException(program != 0, "Failed to link shader program: null program (no bound shaders?)");
        this.opDispatch!"LinkProgram"(program);
        this.CheckLinkStatus(program);
    }
}

// Traced calls...
enum GLTracedCalls {
    DrawArrays,
    DrawIndexed,
};

//public auto GLCall (alias F, string file = __FILE__, ulong line = __LINE__, string externalFunc = __PRETTY_FUNCTION__, Args...)(Args args)
//    if (__traits__(compiles, F(args)))
//{
//    static if (!is(typeof(F(args)) == void))    auto result = F(args);
//    else                                        F(args);

//    static if (GL_RUNTIME_ERROR_CHECKING_ENABLED) {
//        auto err = glGetError();
//        if (err != GL_NO_ERROR) {
//            throw new GLRuntimeException(glGetMessage(err), F.stringof, args.joinArgs(), externalFunc, file, line);
//        }
//    }
//    static if (!is(typeof(F(args)) == void))    return result;
//}

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
    GLShader, GLTexture, GLBuffer, GLVertexArray
}
enum GLShaderType : GLenum { 
    FRAGMENT = GL_FRAGMENT_SHADER, 
    VERTEX   = GL_VERTEX_SHADER, 
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
            enforce(loc > 0, format("No matching uniform for '%s'", name));
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
    //private void setUniform (uint l, float v) { gl.Uniform1f(l, v); }
    //private void setUniform (uint l, vec2  v) { gl.Uniform2fv(l, 1, v.value_ptr); }
    //private void setUniform (uint l, vec3  v) { gl.Uniform3fv(l, 1, v.value_ptr); }
    //private void setUniform (uint l, vec4  v) { gl.Uniform4fv(l, 1, v.value_ptr); }
    
    //private void setUniform (uint l, mat2  v) { gl.UniformMatrix2fv(l, 1, true, v.value_ptr); }
    //private void setUniform (uint l, mat3  v) { gl.UniformMatrix3fv(l, 1, true, v.value_ptr); }
    //private void setUniform (uint l, mat4  v) { gl.UniformMatrix4fv(l, 1, true, v.value_ptr); }

    //private void setUniform (uint l, int   v) { gl.Uniform1i(l, v); }
    //private void setUniform (uint l, vec2i v) { gl.Uniform2iv(l, 1, v.value_ptr); }
    //private void setUniform (uint l, vec3i v) { gl.Uniform3iv(l, 1, v.value_ptr); }
    //private void setUniform (uint l, vec4i v) { gl.Uniform4iv(l, 1, v.value_ptr); }

    //private void setUniform (uint l, float[] v) { gl.Uniform1fv(l, cast(int)v.length, &v[0]); }
    //private void setUniform (uint l, vec2[]  v) { gl.Uniform2fv(l, cast(int)v.length, v[0].value_ptr); }
    //private void setUniform (uint l, vec3[]  v) { gl.Uniform3fv(l, cast(int)v.length, v[0].value_ptr); }
    //private void setUniform (uint l, vec4[]  v) { gl.Uniform4fv(l, cast(int)v.length, v[0].value_ptr); }
    
    //private void setUniform (uint l, mat2[]  v) { gl.UniformMatrix2fv(l, cast(int)v.length, true, v[0].value_ptr); }
    //private void setUniform (uint l, mat3[]  v) { gl.UniformMatrix3fv(l, cast(int)v.length, true, v[0].value_ptr); }
    //private void setUniform (uint l, mat4[]  v) { gl.UniformMatrix4fv(l, cast(int)v.length, true, v[0].value_ptr); }

    //private void setUniform (uint l, int[]   v) { gl.Uniform1iv(l, cast(int)v.length, &v[0]); }
    //private void setUniform (uint l, vec2i[] v) { gl.Uniform2iv(l, cast(int)v.length, v[0].value_ptr); }
    //private void setUniform (uint l, vec3i[] v) { gl.Uniform3iv(l, cast(int)v.length, v[0].value_ptr); }
    //private void setUniform (uint l, vec4i[] v) { gl.Uniform4iv(l, cast(int)v.length, v[0].value_ptr); }
}
public class GLTexture : GLResource {
    this (GLContext context) { super(context); }

    override void resourceDtor () {

    }
}
public class GLBuffer : GLResource {
    this (GLContext context) { super(context); }

    override void resourceDtor () {

    }
}
public class GLVertexArray : GLResource {
    this (GLContext context) { super(context); }

    override void resourceDtor () {

    }
}











