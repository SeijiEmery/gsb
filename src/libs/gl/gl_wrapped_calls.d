module gl.wrapped_calls;
import derelict.opengl3.gl3;
import gl3n.linalg;
import std.exception: enforce;
import std.format;
import std.string: toStringz;

//
// Error handling
//

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
    import std.stdio;
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
        //case GL_STACK_UNDERFLOW: return "GL_STACK_UNDERFLOW";
        //case GL_STACK_OVERFLOW:  return "GL_STACK_OVERFLOW";
        default: return format("Unknown error %s", error);
    }
}

//
// Helper functions
//

private auto toGLEnum (ShaderType type) {
    final switch (type) {
        case ShaderType.VERTEX:   return GL_VERTEX_SHADER;
        case ShaderType.FRAGMENT: return GL_FRAGMENT_SHADER;
        case ShaderType.GEOMETRY: return GL_GEOMETRY_SHADER;
    }
}
private auto getCompileStatus ( uint shader ) {
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
private auto getLinkStatus ( uint program ) {
    int result;
    glGetProgramiv( program, GL_LINK_STATUS, &result );
    return result;
}
private auto getProgramInfoLog ( uint program ) {
    int length = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &length);

    char[] log;
    log.length = length;
    glGetProgramInfoLog( program, length, &length, &log[0] );
    return log [ 0 .. length ];
}

//
// High-level resource context...
//

// Enumerates the types of opengl resources, plus our internal types
// (ie. Context, ErrorListener). Used to identify resource types.
// May be used as a bitmask; values are orthogonal.
enum GLResource {
    None          = 0, 
    Context       = 1 << 0,         // Custom data structure
    ErrorListener = 1 << 1,         // Custom data structure
    Shader        = 1 << 2,         // Shader program
    Texture2d     = 1 << 3,         // 2d Texture
    Vbo           = 1 << 4,      // VBO abstraction
    Vao           = 1 << 5,      // VAO abstraction
}

// Note: does not match GL values (probably).
// This is just a sensible-ish enumeration based on bitmasks +
// combinations of possible values.
enum GLDepthTest {
    None          = 0,
    Eq            = 0x1,
    Lesser        = 0x2,
    Leq           = 0x3,
    Greater       = 0x4,
    Geq           = 0x5,
    Neq           = 0x6,
    Always        = 0x7,
}
enum GLShader {
    None        = 0, 
    Vertex      = 1 << 0, 
    Fragment    = 1 << 1, 
    Geometry    = 1 << 2,
}

// Enumerates the status of an individual resource.
// Initially None; after an operation will either be Ok or Error.
// Note: an Error value is persistant and will block most operations.
enum GLStatus { 
    None = 0x0, Ok = 0x1, Error = 0x2, Dead = 0x3, 
}

enum GLErrorLevel {
    Warning, Error, Critical
}

//enum GLType {
//    Unknown = 0,
//    Int, Vec2i, Vec3i, Vec4i,
//    Float, Vec2, Vec3, Vec4,
//    Mat2, Mat3, Mat4,
//}

alias GLShaderValue = Algebraic!(
    int, vec2i, vec3i, vec4i,
    float, vec2, vec3, vec4,
    mat3, mat4,

    int[], vec2i[], vec3i[], vec4i[],
    float[], vec2[], vec3[], vec4[],
    mat3[], mat4[],
    
    GLShaderUniformBlock,
);

struct GLShaderUniformBlock {
    struct Element {
        string              name;
        ShaderUniformValue  value;
        size_t              offset;
    }
    Element[] descriptor;
    void*     data = null;
}

struct GLErrorInfo {
    int             resource;
    GLResource      type;
    GLError         error;
    string          message;
    GLErrorLevel    severity;
    string          file;
    uint            line;
}
alias GLErrorCallback = void delegate (GLErrorInfo);



interface IGLContext {
    int create  (GLResource type);
    int release (int resource);
    int retain  (int resource);
    
    int        getRefcount (int resource);
    GLResource getType     (int resource);
    GLStatus   getStatus   (int resource);

    bool isContext (int resource);
    bool isErrorListener (int resource);
    bool isShader  (int resource);
    bool isTexture (int resource);
    bool isVbo     (int resource);
    bool isVao     (int resource);

    // Get backreference to self
    int  thisResource ();

    //
    // Context calls
    //

    void   setContextName (int context, string name);
    IGLContext getContext (int context);
    void setContextErrorSeverity (int context, GLError errorType, GLErrorLevel severity);

    //
    // Error listener calls
    //

    void addErrorListenerCallback (int listener, GLErrorCallback callback);

    //
    // Shader calls
    //

    void clearShaders (int shader);
    void shaderSource (int shader, GLShader type, string src);

    Tuple!(string, GLShaderValue)[] listShaderUniforms      (int shader);
    Tuple!(string, string[])[]      listShaderSubroutines   (int shader);

    void setShaderUniform    (int shader, string name, GLShaderValue value);
    void setShaderSubroutine (int shader, string name, string value);

    //
    // Texture calls
    //

    void setTextureSlot (int texture, uint slot);
    void bufferTexture  (int texture, ubyte[] data, vec2i dimensions, GLTextureFormat format);

    //
    // VBO / VAO calls
    //

    void setDrawType          (GLPrimitive primitive, GLDrawType type);
    void bindVertexAttrib     (int vao, int vbo, uint index, GLType dataType, GLNormalized normalized, size_t stride, size_t offset);
    void bindIndexAttrib      (int vao, int vbo, GLType dataType, size_t stride, size_t offset);
    void bindInstancingAttrib (int vao, int vbo, size_t stride, size_t offset);
    void setInstanceCount     (int vao, size_t count);
    void setVertexDivisor     (int vao, uint divisor);

    void bufferData           (int vbo, ubyte[] data);

    void bindShader           (int vao, int shader);
    void bindTexture          (int vao, int texture, int slot);
    void draw                 (int vao);

    // Inherit properties...
    int createChildVao        (int vao);
}


