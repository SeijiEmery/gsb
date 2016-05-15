
module gsb.glutils;

import std.stdio;
import std.format;
import std.traits;
import std.conv;
import std.array: join;

public import derelict.opengl3.gl3;
import dglsl;

class Camera {
    float viewportWidth = 800, viewportHeight = 600;
    float aspectRatio;
    float fov = 60;
    float near = 0.1, far = 1e3;

    mat4 projection;
    mat4 view;

    mat4 projectionMatrix () {
        return projection = mat4.perspective(viewportWidth, viewportHeight, fov, near, far);
    }
}


static string[GLenum] glErrors;
static this () {
    glErrors = [
                GL_INVALID_OPERATION: "INVALID OPERATION",
                GL_INVALID_ENUM: "INVALID ENUM",
                GL_INVALID_VALUE: "INVALID VALUE",
                GL_INVALID_FRAMEBUFFER_OPERATION: "INVALID FRAMEBUFFER OPERATION",
                GL_OUT_OF_MEMORY: "GL OUT OF MEMORY"
            ];
}

void CHECK_CALL (lazy void expr) {
    auto err = glGetError();
    while (err != GL_NO_ERROR) {
        throw new Exception(format("%s while calling %s", glErrors[err]));
    }
}

void CHECK_CALL (string msg) {
    auto err = glGetError();
    if (err != GL_NO_ERROR) {
        throw new Exception(format("%s (%s)", glErrors[err], msg));
    }
}

void CHECK_CALL (F,Args...) (F f, Args args) {
    if (!__ctfe) {
        f(args);
        //CHECK_CALL(f.stringof);
        CHECK_CALL(fullyQualifiedName!(f));
    }   
}

private void checkForGlErrors (string fname, Args...)(Args args) {
    auto fmtMessage (GLenum err) {
        string[] sargs;
        foreach (arg; args)
            sargs ~= to!string(arg);
        return format("%s(%s): %s", fname, sargs.join(", "), glErrors[err]);
    }
    if (!__ctfe) {
        auto err = glGetError();
        if (err != GL_NO_ERROR) {
            throw new Exception(fmtMessage(err));
        }
    }
}

//template hasGlPrefix (string fname) {
//    immutable bool hasGlPrefix = fname[0..2] == "gl";
//}



//bool isFcnWithReturnValue (string fname, Args...)(Args args) {
//    return __traits(compiles, to!bool(mixin(fname)(args)));
//}

void takesAnyArg (T)(T arg) {}

// Wraps a gl function w/ error checking code that will:
// - throw an exception w/ a useful stack trace
// - include the name of the function an its arguments
//
// Due to implementation reasons, we've implemented this as a templated
// function that takes the function _name_ as a string (at compile time),
// and a list of args (at runtime). You use it like this:
//
//   auto someValue = checked!"glSomeCall"(arg1, arg2, ...);
//
// Due to _other_ implementation reasons, we've broken up the implementation of
// this into 3 functions with compile-time guards:
//  - auto checked(...) iff f is a function, has matching arguments, and f(args) has a non-void return value
//  - void checked(...) iff f is a function, has matching arguments, and has no (void) return value
//  - fallback for if the above cases fail (f(args) will not compile).
//    In this case we call f(args) anyways to get useful error messages for why that happened:
//    - f isn't a function so calling (something)(args) doesn't make sense
//    - f(arg-types) is undefined but maybe you meant f(other-arg-types) instead
//    - etc
//    The resulting compiler errors are wierd + verbose, but they _are_ useful.
auto checked (string fname, Args...)(Args args) if (
    __traits(compiles, mixin(fname)(args)) &&
    !is(typeof(mixin(fname)(args)) == void) &&
    fname[0..2] == "gl"
) {
    auto r = mixin(fname)(args);
    checkForGlErrors!fname(args);
    return r;
}
void checked (string fname, Args...)(Args args) if (
    __traits(compiles, mixin(fname)(args)) &&
    is(typeof(mixin(fname)(args)) == void) &&
    fname[0..2] == "gl"
) {
    mixin(fname)(args);
    checkForGlErrors!fname(args);
}

// If 'fname' is not a function or cannot be compiled (wrong arguments), we'll default to this fallback
// where we'll invoke it anyways to generate a useful error message
void checked (string fname, Args...)(Args args) if (
    !__traits(compiles, mixin(fname)(args))
) {
    mixin(fname)(args);
}





//void checked (string fname, Args...)(Args args) if (__traits(compiles, mixin(fname)(args)) && !__traits(compiles, to!bool(mixin(fname)(args))) && fname[0..2] == "gl") {
//    mixin(fname)(args);
//    checkForGlErrors!fname(args);
//}






//auto checked (string fname, Args...)(Args args) if (isGLFunction(fname) && 



//auto checked (string fname, Args...)(Args args) if (fname[0..2] == "gl" && __traits(compiles, mixin) )





//auto checked (string fname, Args...)(Args args) if (fname[0..2] == "gl" && __traits(compiles, mixin(fname)(args)))
//body {
//    auto f = mixin(fname);
//    static if (!is(ReturnType!f == void))
//        auto r = f(args);
//    else
//        f(args);

//    checkForGlErrors();
    
//    static if (!is(ReturnType!f == void))
//        return r;
//}

// find: \n(gl\w+)\s*([^\n]*)
// repl: \nalias checked_$1 = checked!("$1", $2);


// From opengl 4.1 function listings

alias checked_glGenVertexArrays = checked!("glGenVertexArrays", GLsizei, GLuint*);
alias checked_glBindVertexArray = checked!("glBindVertexArray", GLuint);
alias checked_glDeleteVertexArrays = checked!("glDeleteVertexArrays", GLsizei, GLuint*);

alias checked_glVertexAttribPointer = checked!("glVertexAttribPointer", GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
alias checked_glEnableVertexAttribArray = checked!("glEnableVertexAttribArray", GLuint);
alias checked_glDisableVertexAttribArray = checked!("glDisableVertexAttribArray", GLuint);
alias checked_glVertexAttribDivisor = checked!("glVertexAttribDivisor", GLuint, GLuint);

alias checked_glGenBuffers = checked!("glGenBuffers", GLsizei, GLuint*);
alias checked_glDeleteBuffers = checked!("glDeleteBuffers", GLsizei, const(GLuint)*);
alias checked_glBindBuffer = checked!("glBindBuffer", GLenum, GLuint);
alias checked_glBindBufferRange = checked!("glBindBufferRange", GLenum, GLuint, GLuint, GLintptr, GLsizeiptr);
alias checked_glBindBufferBase  = checked!("glBindBufferBase", GLenum, GLuint, GLuint);
alias checked_glBufferData = checked!("glBufferData", GLenum, GLsizeiptr, const(void)*, GLenum);
alias checked_glBufferSubData = checked!("glBufferSubData", GLenum, GLintptr, GLsizeiptr, const(void)*);
alias checked_glMapBufferRange = checked!("glMapBufferRange", GLenum, GLintptr, GLsizeiptr, GLbitfield);
alias checked_glUnmapBuffer    = checked!("glUnmapBuffer", GLenum);


alias checked_glDrawArrays = checked!("glDrawArrays", GLenum, GLint, GLint);
alias checked_glDrawElements = checked!("glDrawElements", GLenum, GLsizei, GLenum, const(GLvoid)*);


alias checked_glActiveTexture = checked!("glActiveTexture", GLenum);
alias checked_glBindTexture   = checked!("glBindTexture", GLenum, GLuint);
alias checked_glDeleteTextures = checked!("glDeleteTextures", GLsizei, const(GLuint)*);
alias checked_glGenTextures = checked!("glGenTextures", GLsizei, GLuint*);
alias checked_glTexImage2D  = checked!("glTexImage2D", GLuint, GLint, GLint, GLint, GLint, GLint, GLuint, GLuint, const(void)*);
alias checked_glTexParameteri = checked!("glTexParameteri", GLuint, GLuint, GLint);


alias checked_glGenSamplers = checked!("glGenSamplers", GLsizei, GLuint*);
alias checked_glBindSampler = checked!("glBindSampler", GLuint, GLuint);
alias checked_glSamplerParameteriv = checked!("glSamplerParameteriv", GLuint, GLenum, const(GLint)*);
alias checked_glSamplerParameterfv = checked!("glSamplerParameterfv", GLuint, GLenum, const(GLfloat)*);
alias checked_glSamplerParameterIiv = checked!("glSamplerParameterIiv", GLuint, GLenum, const(GLint)*);
alias checked_glSamplerParameterIuiv = checked!("glSamplerParameterIuiv", GLuint, GLenum, const(GLuint)*);






alias checked_glCreateShader = checked!("glCreateShader", GLenum);
alias checked_glShaderSource = checked!("glShaderSource", GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
alias checked_glReleaseShaderCompiler = checked!("glReleaseShaderCompiler");
alias checked_glDeleteShader = checked!("glDeleteShader", GLuint);
alias checked_glShaderBinary = checked!("glShaderBinary", GLsizei, const GLuint *, GLenum, const GLvoid*, GLsizei);
alias checked_glCreateProgram = checked!("glCreateProgram");
alias checked_glAttatchShader = checked!("glAttachShader", GLuint, GLuint);
alias checked_glDetatchShader = checked!("glDetachShader", GLuint, GLuint);
alias checked_glLinkProgram = checked!("glLinkProgram", GLuint);
alias checked_glUseProgram = checked!("glUseProgram", GLuint);

alias checked_glCreateShaderProgramv = checked!("glCreateShaderProgramv", GLenum, GLsizei, const(GLchar*)*);
alias checked_glProgramParameteri = checked!("glProgramParameteri", GLuint, GLenum, GLint);
alias checked_glDeleteProgram = checked!("glDeleteProgram", GLuint);

alias checked_glGenProgramPipelines = checked!("glGenProgramPipelines", GLsizei, GLuint*);
alias checked_glDeleteProgramPipelines = checked!("glDeleteProgramPipelines", GLsizei, const(GLuint)*);
alias checked_glBindProgramPipeline = checked!("glBindProgramPipeline", GLuint);
alias checked_glUseProgramStages = checked!("glUseProgramStages", GLuint, GLbitfield, GLuint);
alias checked_glActiveShaderProgram = checked!("glActiveShaderProgram", GLuint, GLuint);

alias checked_glGetProgramBinary = checked!("glGetProgramBinary", GLuint, GLsizei, GLsizei*, GLenum*, void*);
alias checked_glProgramBinary = checked!("glProgramBinary", GLuint, GLenum, const(void)*, GLsizei);

alias checked_glGetActiveAttrib = checked!("glGetActiveAttrib", GLuint, GLuint, GLsizei, GLsizei*, GLint*, GLenum*, GLchar*);
alias checked_glGetAttribLocation = checked!("glGetAttribLocation", GLuint, const(GLchar)*);

alias checked_glGetUniformLocation = checked!("glGetUniformLocation", GLuint, const(GLchar)*);
alias checked_glGetUniforBlockIndex = checked!("glGetUniformBlockIndex", GLuint, const(GLchar)*);
alias checked_glGetActiveUniformBlockName = checked!("glGetActiveUniformBlockName", GLuint, GLuint, GLsizei, GLsizei*, GLchar*);
alias checked_glGetUniformIndices = checked!("glGetUniformIndices", GLuint, GLsizei, const(GLchar*)*, GLuint*);
alias checked_glGetActiveUniformName = checked!("glGetActiveUniformName", GLuint, GLuint, GLsizei, GLsizei*, GLchar*);
alias checked_glGetActiveUniform = checked!("glGetActiveUniform", GLuint, GLuint, GLsizei, GLsizei*, GLint*, GLenum*, GLchar*);
alias checked_glGetActiveUniformsiv = checked!("glGetActiveUniformsiv", GLuint, GLsizei, GLuint*, GLenum, GLint*);

alias checked_glUniform1i = checked!("glUniform1i", GLint, GLint);
alias checked_glUniform2i = checked!("glUniform2i", GLint, GLint, GLint);
alias checked_glUniform3i = checked!("glUniform3i", GLint, GLint, GLint, GLint);
alias checked_glUniform4i = checked!("glUniform4i", GLint, GLint, GLint, GLint, GLint);

alias checked_glUniform1f = checked!("glUniform1f", GLint, GLfloat);
alias checked_glUniform2f = checked!("glUniform2f", GLint, GLfloat, GLfloat);
alias checked_glUniform3f = checked!("glUniform3f", GLint, GLfloat, GLfloat, GLfloat);
alias checked_glUniform4f = checked!("glUniform4f", GLint, GLfloat, GLfloat, GLfloat, GLfloat);








//auto checked_glUseProgram = checked!"glUseProgram";

//alias checked_glUseProgram = checked!"glUseProgram";




//auto makeChecked (string fname) {
//    auto f = mixin(fname);
//    void impl (Args...)(Args args) {
//        if (!__ctfe) {
//             f(args);
//            CHECK_CALL(fname);
//        }
//    }
//    return impl;
//}

//auto checked_glUseProgram = makeChecked!("glUseProgram");





//void CHECK_CALL(F)(F fcn) {
//    auto err = glGetError();
//    while (err != GL_NO_ERROR) {
//        writefln("%s while calling %s", glErrors[err], F.stringof);
//        err = glGetError();
//    }
//}
//void CHECK_CALL(string context) {
//    auto err = glGetError();
//    while (err != GL_NO_ERROR) {
//        writefln("%s while calling %s", glErrors[err], context);
//        err = glGetError();
//    }
//}

