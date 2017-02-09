// sb/gla/src/gla41.d
//
// This module is a collection of opengl ulilities and base classes used by the
// rest of the gla library.
//
// In theory, this could also abstract the opengl 4.1 implementation of gla,
// but at present we'll remain tightly bound to glfw / gl 4.1.
//
module sb.gla.gl41;
public import sb.gla.public_interface;
public import derelict.opengl3.gl3;
public import gl3n.linalg;
public import std.exception: enforce;
public import std.format;
import std.string: toStringz;
import std.typecons;

//
// Internal types, etc.
//

auto toGLEnum (ShaderType type) {
    final switch (type) {
        case GLAShaderType.VERTEX:   return GL_VERTEX_SHADER;
        case GLAShaderType.FRAGMENT: return GL_FRAGMENT_SHADER;
        case GLAShaderType.GEOMETRY: return GL_GEOMETRY_SHADER;
    }
}
auto toGLEnum (GLADepthTest depthTest) {
    final switch (depthTest) {
        case GLADepthTest.None: return GL_NONE;
        case GLADepthTest.All:  return GL_ALL;
        case GLADepthTest.Less: return GL_LESS;
        case GLADepthTest.LEqual: return GL_LEQUAL;
        case GLADepthTest.Greater: return GL_GREATER;
        case GLADepthTest.GEqual:  return GL_GEQUAL;
        case GLADepthTest.Equal:   return GL_EQUAL;
    }
}



//
// GL context
//

struct GLContext {
    uint boundProgram = 0;
    // ...
}




//
// GL error checking
//

void glAssertOk (lazy string msg, string file = __FILE__, size_t line = __LINE__) {
    auto err = glGetError();
    assert( err == GL_NO_ERROR, format("GL ERROR: %s | %s, %s: %s", 
        err.glErrorToString, file, line, msg ));
}
void glEnforceOk (lazy string msg, string file = __FILE__, size_t line = __LINE__) {
    auto err = glGetError();
    enforce( err == GL_NO_ERROR, format("GL ERROR: %s | %s, %s: %s",
        err.glErrorToString, file, line, msg ));
}
void glFlushErrors (string file = __FILE__, size_t line = __LINE__) {
    GLenum err;
    import std.stdio;
    while ((err = glGetError()) != GL_NO_ERROR)
        writefln("Uncaught error: %s (%s, %s)", err.glErrorToString, file, line);
}
auto glErrorToString ( GLenum error ) {
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

//
// Shader utils
//

auto glGetCompileStatus ( uint shader ) {
    int result;
    glGetShaderiv( shader, GL_COMPILE_STATUS, &result );
    return result;
}
auto getShaderInfoLog ( uint shader ) {
    int length = 0;
    glGetShaderiv( shader, GL_INFO_LOG_LENGTH, &length );

    char[] log;
    log.length = length;
    glGetShaderInfoLog( shader, length, &length, &log[0] );
    return log[ 0 .. length ];
}
auto glGetLinkStatus ( uint program ) {
    int result;
    glGetProgramiv( program, GL_LINK_STATUS, &result );
    return result;
}
auto getProgramInfoLog ( uint program ) {
    int length = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &length);

    char[] log;
    log.length = length;
    glGetProgramInfoLog( program, length, &length, &log[0] );
    return log [ 0 .. length ];
}













