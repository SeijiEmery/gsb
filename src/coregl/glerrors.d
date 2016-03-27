
module gsb.coregl.glerrors;
import gsb.core.log;
import std.format;
import std.conv;

public import derelict.opengl3.gl3;

public immutable bool GL_RUNTIME_ERROR_CHECKING_ENABLED = true;

class GLException : Exception {
    this (string msg, string file = __FILE__, ulong line = __LINE__, string fcn = __PRETTY_FUNCTION__) {
        super(msg, file, line);
    }
}

private string glGetMessage (GLenum err) {
    final switch (err) {
        case GL_NO_ERROR: return "GL_NO_ERROR";
        case GL_INVALID_OPERATION: return "GL_INVALID_OPERATION";
        case GL_INVALID_ENUM:      return "GL_INVALID_ENUM";
        case GL_INVALID_VALUE:     return "GL_INVALID_VALUE";
        case GL_INVALID_FRAMEBUFFER_OPERATION: return "GL_INVALID_FRAMEBUFFER_OPERATION";
        case GL_OUT_OF_MEMORY: return "GL_OUT_OF_MEMORY";
    }
    assert(0, format("Invalid error: %d", err));
}

// GL error-checking call wrapper #1 (note: gives shitty error messages, but can work with any call / calls)
// 
// usage:  glchecked({ glDrawArrays(GL_TRIANGLES, 0, 100); }); 
//
public auto glchecked (T, string file = __FILE__, ulong line = __LINE__, string externalFunc = __PRETTY_FUNCTION__)
    (T function() expr) 
{
    static if (!is(T == void)) auto result = expr();
    else                expr();

    static if (GL_RUNTIME_ERROR_CHECKING_ENABLED) {
        auto err = glGetError();
        if (err != GL_NO_ERROR) {
            string msg = glGetMessage(err); log.write(msg);
            while ( (err = glGetError()) != GL_NO_ERROR) {
                msg ~= ", ";
                msg ~= glGetMessage(err);
            }
            throw new GLException(
                format("%s in %s", msg, externalFunc),
                file, line);
        }
    }
    static if (!is(T == void)) return result;
}

private string joinArgs (Args...)(Args args) {
    import std.conv;
    import std.array;

    string[] sargs;
    foreach (arg; args)
        sargs ~= arg.to!string();
    return sargs.join(", ");
}

// GL error-checking call wrapper #2 (gives much nicer error messages, but probably involves much more compile-time overhead since the template is much more complex)
//
// usage:  glchecked!glDrawArrays( GL_TRIANGLES, 0, 100 );
//
public auto glchecked (alias F, string file = __FILE__, ulong line = __LINE__, string externalFunc = __PRETTY_FUNCTION__, Args...)(Args args) {
    static if (!is(typeof(F(args)) == void)) auto result = F(args);
    else                            F(args);

    static if (GL_RUNTIME_ERROR_CHECKING_ENABLED) {
        auto err = glGetError();
        if (err != GL_NO_ERROR) {
            throw new GLException(
                format("%s while calling %s(%s) in %s", glGetMessage(err), F.stringof, args.joinArgs(), externalFunc),
                file, line);
        }
    }
    static if (!is(typeof(F(args)) == void)) return result;
}



