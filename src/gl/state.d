
module gsb.gl.state;

import gsb.core.log;

import gsb.glutils;
import derelict.opengl3.gl3;
import gl3n.linalg;

public __gshared GLState glState;
struct GLState {
    private bool depthTestEnabled = false;
    private bool transparencyEnabled = false;
    private GLuint lastBoundBuffer = 0;
    private GLuint lastBoundShader = 0;
    private GLuint lastBoundVao = 0;
    private GLuint lastBoundTexture = 0;

    void enableDepthTest (bool enabled) {
        if (depthTestEnabled != enabled) {
            if ((depthTestEnabled = enabled) == true) {
                //log.write("Enabling glDepthTest (GL_LESS)");
                glEnable(GL_DEPTH_TEST);
                glDepthFunc(GL_LESS);
            } else {
                //log.write("Disabling glDepthTest");
                glDisable(GL_DEPTH_TEST);
            }
        }
    }
    void enableTransparency (bool enabled) {
        if (transparencyEnabled != enabled) {
            if ((transparencyEnabled = enabled) == true) {
                //log.write("Enabling alpha transparency blending");
                glEnable(GL_BLEND);
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            } else {
                //log.write("Disabling alpha transparency");
                glDisable(GL_BLEND);
            }
        }
    }

    void bindShader (GLuint shader) {
        if (shader != lastBoundShader) {
            checked_glUseProgram(shader);
            lastBoundShader = shader;
        }
    }
    void bindVao (GLuint vao) {
        if (vao != lastBoundVao) {
            checked_glBindVertexArray(vao);
            lastBoundVao = vao;
        }
    }
    void bindBuffer (GLenum type, GLuint vbo) {
        if (vbo != lastBoundBuffer) {
            checked_glBindBuffer(type, vbo);
            lastBoundBuffer = vbo;
        }
    }
    void bindTexture (GLenum type, GLuint texture) {
        if (texture != lastBoundTexture) {
            checked_glBindTexture(type, texture);
            lastBoundTexture = texture;
        }
    }
}

private bool isValidGlTarget (GLenum target) {
    return target == GL_ARRAY_BUFFER ||
        target == GL_ELEMENT_ARRAY_BUFFER ||
        target == GL_COPY_READ_BUFFER ||
        target == GL_COPY_WRITE_BUFFER ||
        target == GL_PIXEL_UNPACK_BUFFER ||
        target == GL_PIXEL_PACK_BUFFER ||
        target == GL_QUERY_BUFFER ||
        target == GL_TEXTURE_BUFFER ||
        target == GL_TRANSFORM_FEEDBACK_BUFFER ||
        target == GL_UNIFORM_BUFFER ||
        target == GL_DRAW_INDIRECT_BUFFER;
}


interface GLResource {
    void release ();
}

class VAO : GLResource {
    private GLuint handle = 0;
    auto get () {
        if (!handle)
            checked_glGenVertexArrays(1, &handle);
        return handle;
    }
    final void release () {
        if (handle) {
            checked_glDeleteVertexArrays(1, &handle);
            handle = 0;
        }
    }
    void bind () {
        glState.bindVao(get());
    }
}

class VBO : GLResource {
    private GLuint handle = 0;
    private GLenum bindingType = 0;
    private GLenum usageType   = 0;
    private size_t reservedSize = 0;
    private bool   hasUsedData = false;

    auto get () {
        if (!handle) {
            checked_glGenBuffers(1, &handle);
            bindingType = usageType = 0;
            reservedSize = 0;
            hasUsedData = false;
        }
        return handle;
    }
    final void release () {
        if (handle) {
            checked_glDeleteBuffers(1, &handle);
            handle = 0;
        }
    }
    void bind (GLenum type) {
        glState.bindBuffer(bindingType = type, get());
    }
    void bufferData (GLenum type, GLenum usage)(size_t size, void* data) if (isValidGlTarget(type)) {
        bind(type);
        checked_glBufferData(type, size, data, usage);
    }
    void bufferData (GLenum type, GLenum usage, T)(T[] data) if (isValidGlTarget(type)) {
        bind(type);
        checked_glBufferData(type, data.length, data.ptr, usage);
    }

    void* mapRange (GLenum type)(size_t offset, size_t size, GLbitfield access) if (isValidGlTarget(type)) {
        bind(type);
        return checked_glMapBufferRange(type, offset, size, access);
    }
    void unmap (GLenum type)() if (isValidGlTarget(type)) {
        glState.bindBuffer(type, handle);
        checked_glUnmapBuffer(type);
    }
    void writeMappedRange (GLenum type, T)(size_t offset, T[] data, GLbitfield access) if (isValidGlTarget(type)) {
        writeMappedRange(offset, data.length, data.ptr, access);
    }
    void writeMappedRange (GLenum type)(size_t offset, size_t size, void* data, GLbitfield access) if (isValidGlTarget(type)) {
        import core.stdc.string: memcpy;
        auto ptr = mapRange!type(offset, size, access);
        memcpy(ptr, data, size);
        unmap!type();
    }
}

class GLTexture : GLResource {
    private GLuint handle = 0;
    auto get () {
        if (!handle)
            checked_glGenTextures(1, &handle);
        return handle;
    }
    final void release () {
        if (handle) {
            checked_glDeleteTextures(1, &handle);
            handle = 0;
        }
    }
    void bind (GLenum type) {
        glState.bindTexture(type, get());
    }
}












