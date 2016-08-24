module sb.gla.shader;
import sb.gla.gl41;
import gl3n.linalg;

enum ShaderType   { VERTEX = 0, FRAGMENT }
enum ShaderStatus { NOT_COMPILED = 0, COMPILED, COMPILE_ERROR, LINK_ERROR }

// Internal errors thrown on the graphics thread:
//  ShaderCompilationException => compile or link errors
//  ShaderUsageException => recoverable usage errors (eg. glUniform, etc)

class ShaderCompilationException : Exception {
    this (string errorMsg, string src) {}
    this (string errorMsg, string[] sources) {}
}
class ShaderUsageException : Exception {
    this (ShaderRef shader, string msg) {}
}

// Shader uniform value type (implemented as a variadic)
alias ShaderUniformValue = Algebraic!(
    uint, int, vec2i, vec3i, vec4i,
    float, vec2, vec3, vec4,
    mat3, mat4);

alias ShaderRef = RefCounted!GLA_Shader;

// GLA shader impl.
// Operates as an opaque wrapper around a gl41 program object.
// The main interface is _not_ object methods, but instead command
// objects (basically delegates w/ captured arguments) that can be
// inserted into a queue and executed asynchronously, hence enabling
// multithreaded opengl work to be scheduled on multiple command buffers
// simultaneously (aka poor man's vulkan / metal).
struct GLA_Shader {
public:
    ShaderStatus getStatus () { return status; }
    string       getError  () { return lastError; }
    string       getName   () { return name; }

    @disable this(this);
    ~this () { deleteShaders(); }

private:
    // Optional identifier set when the shader is compiled with sources.
    // This is just a metadata field used for debugging.
    string              name = null;

    // shared state updated atomically-ish
    shared ShaderStatus status = ShaderStatus.NOT_COMPILED;
    shared string       lastError = null;

    // gthread only
    uint program = 0;
    uint[ShaderType.max+1] shaders = 0;

    int[string] uniformLocationCache;

    //
    // Helper methods
    //

    private void deleteShaders () {
        if (program) {
            glDeleteProgram(program);
            glAssertOk(format("glDeleteProgram(%s)", program));
        }
        foreach (shader; shaders) {
            if (shader) {
                glDeleteShader(shader);
                glAssertOk(format("glDeleteShader(%s)", shader));
            }
        }
    }
    private void resetCaches () {
        foreach (k, v; uniformLocationCache)
            uniformLocationCache.remove(k);
    }

    private int getUniformLocation (string name) {
        if (name in uniformLocationCache)
            return uniformLocationCache[name];

        auto loc = glGetUniformLocation(target.program, name.toStringz);
        glAssertOk(format("glGetUniformLocation(%s, %s)", program, name));
        return target.locationCache[name] = loc;
    }

    private int getSubroutineLocation (string name) {
        return -1;
    }
}

//
// Internal GL calls -- use only from graphics thread!
//

private __gshared uint g_lastBoundProgram = 0;

// Try binding a shader using glUseProgram.
// Returns true if success (shader is bindable (compiled) and has been bound), or false otherwise.
public bool tryBind (ref ShaderRef target) {
    if (target.program != g_lastBoundProgram) {
        if (target.program && target.status == ShaderStatus.COMPILED) {
            glUseProgram(target.program);
            glAssertOk(format("glUseProgram(%s)", target.program));
            g_lastBoundProgram = target.program;
        } else {
            g_lastBoundProgram = 0;
        }
    }
    return g_lastBoundProgram != 0;
}
public void clearBoundShader () {
    g_lastBoundProgram = 0;
}

//
// Note: GLACommand(s) are only ever called on the graphics thread,
// and will be done so in sequence (so synchonization is uneccessary)
//


// Compiles or recompiles shader sources into @target.
// This also sets the shader's 'name' field (via @shaderName), which
// is an optional unique-ish identifier (eg. shader file name) to
// be used for debugging purposes.
struct GLACommand_CompileShader {
    ShaderRef                target;
    string                   shaderName = null;
    string[ShaderType.max+1] sources = null;

    auto ref setSource (ShaderType type, string src) {
        return sources[type] = src, this;
    }
    auto ref setName (string name) {
        return shaderName = name, this;
    }

    bool canExec () { return true; }
    void exec () {
        assert(target, "Null shader reference!");

        // Set target name (this is just an identifier used for debugging)
        target.name = shaderName;

        // Create program object if it doesn't exist
        if (!target.program) {
            target.program = glCreateProgram();
            glAssertOk("Could not create program object?");
            assert(target.program, "Did not create program object!");
        }

        // Iterate over non-null shader sources
        bool hasSubShaders = false;
        foreach (st; ShaderType.min .. ShaderType.max) {
            if (sources[st]) hasSubShaders = true;
            else continue;

            // Create shader if it doesn't exist
            if (!target.shaders[st]) {
                target.shaders[st] = glCreateShader( st.toGLEnum );
                glAssertOk(format("Error creating shader? (%s)", st));
            }
            assert(target.shaders[st], format("Could not create shader! (%s)", st));

            const(char)* source = &src[0];
            int    length = cast(int)src.length;

            // Compile shader
            glShaderSource( target.shaders[st], 1, &source, &length );
            glCompileShader( target.shaders[st] );

            // Check for compile errors -- if there is one, set target status + last error message and bail
            if (glGetCompileStatus(target.shaders[st]) != GL_TRUE) {
                target.lastError = format("Failed to compile %s shader: %s", type, getShaderInfoLog(target.shaders[st]));
                target.status = ShaderStatus.COMPILE_ERROR;
                throw new ShaderCompilationException(target.lastError, sources[st]);
            }
            // double check that there's no internal errors before proceeding
            glEnforceOk(format("glShaderSource / glCompileShader (%s, %s)", type, target.shaders[st]));

            // Attach shader to program object
            glAttachShader(m_programObject, target.shaders[st]);
            glEnforceOk(format("Failed to attach shader? (%s, %s)", type, getShaderInfoLog(target.shaders[st])));
        }

        // If our request didn't contain any shader sources we'll assume that we wanted to kill the shader (reset)
        if (!hasSubShaders) {
            // Signal new status
            target.lastError = null;
            target.status = ShaderStatus.NOT_COMPILED;

            // Delete program + shaders if they exist
            target.deleteShaders();

        } else {
            // Reset cached uniform locations, etc
            target.resetCaches();

            // Link shader program and check for errors
            glLinkProgram(target.program);
            if (glGetLinkStatus(target.program) != GL_TRUE) {
                target.lastError = format("Failed to link shader program: %s", getProgramInfoLog(target.program)));
                target.status = ShaderStatus.LINK_ERROR;
                throw new ShaderCompilationException(target.lastError, sources[0..$]);
            }

            // check gl errors before proceeding
            glEnforceOk(format("glLinkProgram(%s)", target.program));
        }
    }
}

struct GLACommand_ShaderUseSubroutine {
    ShaderRef target;
    string name, value;

    bool canExec () { return target.program && tryBind(target); }
    void exec () {
        assert(target.program != 0 && g_lastBoundProgram == target.program,
            format("%s, %s", target.program, g_lastBoundProgram));

        throw new ShaderUsageException(target, "Unimplemented!");
    }
}
struct GLACommand_ShaderSetUniform {
    ShaderRef target;
    string name;
    ShaderUniformValue value;

    bool canExec () { return target.program && tryBind(target); }
    void exec () {
        assert(target.program != 0 && g_lastBoundProgram == target.program,
            format("%s, %s", target.program, g_lastBoundProgram));

        // Try getting the uniform location (will be -1 if not found)
        int location = target.getUniformLocation(name);
        enforce!ShaderUsageException(location != -1,
            target, format("Could not get uniform location '%s'", name));

        auto loc = cast(uint)location;

        // Set value using glUniform
        value.visit!(
            (uint v) => glUniform1ui(loc, v),
            (int  v) => glUniform1i (loc, v),
            (vec2i v) => glUniform2iv(loc, v.value_ptr),
            (vec3i v) => glUniform3iv(loc, v.value_ptr),
            (vec4i v) => glUniform4iv(loc, v.value_ptr),
            (float v) => glUniform1f(loc, v),
            (vec2 v) => glUniform2fv(loc, v.value_ptr),
            (vec3 v) => glUniform3fv(loc, v.value_ptr),
            (vec4 v) => glUniform4fv(loc, v.value_ptr),
            (mat3 v) => glUniformMatrix3fv(loc, v.value_ptr),
            (mat4 v) => glUniformMatrix4fv(loc, v.value_ptr),
        )();
        glAssertOk(format("glUniform<...>(%s (%s), %s)", name, location, value));
    }
}










