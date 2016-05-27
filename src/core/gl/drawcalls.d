
module gsb.gl.drawcalls;

import gsb.glutils;
import derelict.opengl3.gl3;
import gl3n.linalg;
import std.format;

struct VertexAttrib {
    GLuint index;
    GLuint count;
    GLenum type;
    GLboolean normalized = GL_FALSE;
    GLsizei   stride = 0;
    const GLvoid* pointerOffset = null;

    string toString () {
        return format("\n\t\t[ VertexAttrib index=%d, count=%d, type=%d, normalized=%s, stride=%d, offset=%d",
            index, count, type, normalized, stride, cast(size_t)pointerOffset);
    }
}

struct VertexData {
    void* data; size_t length;
    VertexAttrib[] attribs;

    string toString () {
        return format("\n\t[ VertexData data=%x, length=%d, attribs: %s ]",
            data, length, attribs);
    }
}

struct ElementData {
    void* data; size_t length;
    GLenum type = GL_UNSIGNED_SHORT;
    void*  pointerOffset = null;

    string toString () {
        return format("[ ElementData data=%x, length = %d, type = %d, offset = %d ]",
            data, length, type, cast(size_t)pointerOffset);
    }
}

struct VADrawCall {
    GLuint vao;
    GLenum type;
    GLsizei offset, count;
    VertexData[] components;

    string toString () {
        return format("[ DrawCall vao=%d, type=%d, offset=%d, count=%d, data:%s ]",
            vao, type, offset, count, components);
    }
}







































