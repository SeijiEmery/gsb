
module gsb.gl.state;

import gsb.core.log;

import gsb.glutils;
import derelict.opengl3.gl3;
import gl3n.linalg;

public __gshared GLState glState;
struct GLState {
    private bool depthTestEnabled = false;
    private GLenum depthTestFunc  = GL_LESS;
    private bool transparencyEnabled = false;
    private GLuint lastBoundBuffer = 0;
    private GLuint lastBoundShader = 0;
    private GLuint lastBoundVao = 0;
    private GLuint lastBoundTexture = 0;
    private uint lastActiveTexture = 0;

    void enableDepthTest (bool enabled, GLenum depthTest = GL_LESS) {
        if (depthTestEnabled != enabled || depthTestFunc != depthTest) {
            if ((depthTestEnabled = enabled) == true) {
                depthTestFunc = depthTest;
                //log.write("Enabling glDepthTest (GL_LESS)");
                glEnable(GL_DEPTH_TEST);
                glDepthFunc(depthTest);
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

        //log.write("glState: binding shader %s", shader);

        //if (shader != lastBoundShader) {
            checked_glUseProgram(shader);
            lastBoundShader = shader;
        //}
    }
    void bindVao (GLuint vao) {

        //log.write("glState: binding vao %s", vao);
        //if (vao != lastBoundVao) {
            checked_glBindVertexArray(vao);
            lastBoundVao = vao;
        //}
    }
    void bindBuffer (GLenum type, GLuint vbo) {

        //log.write("glState: binding vbo %s", vbo);
        //if (vbo != lastBoundBuffer) {
            checked_glBindBuffer(type, vbo);
            lastBoundBuffer = vbo;
        //}
    }
    void bindTexture (GLenum type, GLuint texture) {

        //log.write("glState: binding texture %s", texture);

        //if (texture != lastBoundTexture) {
            checked_glBindTexture(type, texture);
            lastBoundTexture = texture;
        //}
    }
    void activeTexture (uint textureUnit) {

        //log.write("glState: activating texture %d", textureUnit - GL_TEXTURE0);

        if (textureUnit != lastActiveTexture)
            checked_glActiveTexture(lastActiveTexture = textureUnit);
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

            log.write("creating buffer %s", handle);
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
        glState.bindBuffer(type, get()); bindingType = type;
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

enum TextureFormat : GLuint {
    INVALID,
    //GL_RED = GL_RED,
    //GL_RG  = GL_RG,
    //GL_RGB = GL_RGB,
    //GL_BGR = GL_BGR,
    //GL_RGBA = GL_RGBA,
    //GL_BGRA = GL_BGRA,
    //GL_DEPTH_COMPONENT = GL_DEPTH_COMPONENT,
    //GL_STENCIL_INDEX = GL_STENCIL_INDEX
}
enum TextureComponentType : GLuint {
    INVALID,
    //GL_UNSIGNED_BYTE = GL_UNSIGNED_BYTE,
    //GL_BYTE = GL_BYTE, 
    //GL_UNSIGNED_SHORT = GL_UNSIGNED_SHORT, 
    //GL_SHORT = GL_SHORT, 
    //GL_UNSIGNED_INT = GL_UNSIGNED_INT, 
    //GL_INT = GL_INT, 
    //GL_FLOAT = GL_FLOAT, 
    //GL_UNSIGNED_BYTE_3_3_2 = GL_UNSIGNED_BYTE_3_3_2, 
    //GL_UNSIGNED_BYTE_2_3_3_REV = GL_UNSIGNED_BYTE_2_3_3_REV, 
    //GL_UNSIGNED_SHORT_5_6_5 = GL_UNSIGNED_SHORT_5_6_5, 
    //GL_UNSIGNED_SHORT_5_6_5_REV = GL_UNSIGNED_SHORT_5_6_5_REV, 
    //GL_UNSIGNED_SHORT_4_4_4_4 = GL_UNSIGNED_SHORT_4_4_4_4, 
    //GL_UNSIGNED_SHORT_4_4_4_4_REV = GL_UNSIGNED_SHORT_4_4_4_4_REV, 
    //GL_UNSIGNED_SHORT_5_5_5_1 = GL_UNSIGNED_SHORT_5_5_5_1, 
    //GL_UNSIGNED_SHORT_1_5_5_5_REV = GL_UNSIGNED_SHORT_1_5_5_5_REV, 
    //GL_UNSIGNED_INT_8_8_8_8 = GL_UNSIGNED_INT_8_8_8_8, 
    //GL_UNSIGNED_INT_8_8_8_8_REV = GL_UNSIGNED_INT_8_8_8_8_REV, 
    //GL_UNSIGNED_INT_10_10_10_2 = GL_UNSIGNED_INT_10_10_10_2
}
enum TextureType {
    INVALID = 0,
    GL_TEXTURE_2D,
    //GL_TEXTURE_2D = GL_TEXTURE_2D,
}


class BufferTexture : GLResource {
    private GLuint handle = 0;
    private VBO    buffer = null;
    private uint   rangeSize = 0, rangeOffset = 0;

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

    void bind (uint textureUnit) {
        glState.activeTexture(textureUnit);
        glState.bindTexture(GL_TEXTURE_BUFFER, get());

        if (!buffer)
            buffer = new VBO();
        buffer.bind(GL_TEXTURE_BUFFER);
    }

    void setData (GLuint textureUnit, GLenum imageFormat, void* data, size_t size) {

        bind(textureUnit);
        log.write("writing to buffer texture");
        if (!buffer || rangeSize != size || rangeOffset != 0) {
            log.write("binding vbo to texture unit");
            bind(textureUnit);
            glTexBuffer(GL_TEXTURE_BUFFER, imageFormat, buffer.get());
            rangeSize = cast(uint)size, rangeOffset = 0;
        }
        log.write("buffering data");
        buffer.bufferData!(GL_TEXTURE_BUFFER, GL_DYNAMIC_DRAW)(size, data);
    }
    void setData (T)(GLuint textureUnit, GLenum imageFormat, T[] data) {
        setData(textureUnit, imageFormat, data.ptr, data.length);
    }

    void setDataRange (GLuint textureUnit, GLenum imageFormat, void* data, size_t size, size_t offset) {

        bind(textureUnit);
        if (rangeSize != size || rangeOffset != offset) {
            glTexBufferRange(GL_TEXTURE_BUFFER, imageFormat, buffer.get(), offset, size);
            rangeSize = cast(uint)size; rangeOffset = cast(uint)offset;
        }
        buffer.bufferData!(GL_TEXTURE_BUFFER, GL_DYNAMIC_DRAW)(size, data);
    }
    void setDataRange (T)(GLuint textureUnit, GLenum imageFormat, T[] data, size_t offset) {
        setDataRange(textureUnit, imageFormat, data.ptr, data.length, offset);
    }
}



class GLTexture : GLResource {
    private GLuint handle = 0;
    private GLenum filtering;  // GL_NEAREST / GL_LINEAR / etc
    private GLenum sampling;   
    private TextureType imagetype;  // GL_TEXTURE_2D, etc

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
    void bind (TextureType type, uint texunit) {
        glState.activeTexture(texunit);
        glState.bindTexture(imagetype = type, get());
    }
    void setFiltering (GLenum target) {
        if (filtering != target) {
            glTexParameteri(imagetype, GL_TEXTURE_MAG_FILTER, filtering = target);
            glTexParameteri(imagetype, GL_TEXTURE_MIN_FILTER, filtering);
        }
    }
    void setSampling (GLenum target) {
        if (sampling != target) {

        }
    }
    void setData (T)(uint s0, uint t0, uint width, uint height, TextureFormat format, TextureComponentType type, T[] data) {
        assert(data.length >= width * height);
        setData(s0, t0, width, height, data.ptr);
    }
    //void setData (uint s0, uint t0, uint width, uint height, TextureFormat format, TextureComponentType type, void* data) {
    //    if (dimensions.x == width && dimensions.y >= height) {
    //        switch (imagetype) {
    //            case GL_TEXTURE_2D: glTexSubImage2D(imagetype, get(), 0, s0, t0, width, height, format, type, data); break;
    //            default: throw new Exception("Unsupported texture format: %s", imagetype);
    //        }
    //    } else {
    //        switch (imagetype) {
    //            case GL_TEXTURE_2D: glTexSubImage2D(imagetype, get(), 0, s0, t0, width, height, format, type, data); break;
    //            default: throw new Exception("Unsupported texture format: %s", imagetype);
    //        }
    //    }
    //}
}












