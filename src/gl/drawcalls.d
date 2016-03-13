
module gsb.gl.drawcalls;

import gsb.glutils;
import derelict.opengl3.gl3;
import gl3n.linalg;

struct VertexAttrib {
    GLuint index;
    GLuint count;
    GLenum type;
    GLboolean normalized = GL_FALSE;
    GLsizei   stride = 0;
    const GLvoid* pointerOffset = null;
}

struct VertexData {
    void* data; size_t length;
    VertexAttrib[] attribs;
}

struct ElementData {
    void* data; size_t length;
    GLenum type = GL_UNSIGNED_SHORT;
    void*  pointerOffset = null;
}

struct VADrawCall {
    GLuint vao;
    GLenum type;
    GLsizei offset, count;
    VertexData[] components;
}







































