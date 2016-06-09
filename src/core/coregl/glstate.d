module gsb.coregl.glstate;
import gsb.coregl.resource;
import gsb.coregl.gl;
import gsb.core.log;

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
                glchecked!glEnable(GL_DEPTH_TEST);
                glchecked!glDepthFunc(depthTest);
            } else {
                //log.write("Disabling glDepthTest");
                glchecked!glDisable(GL_DEPTH_TEST);
            }
        }
    }
    void enableTransparency (bool enabled) {
        if (transparencyEnabled != enabled) {
            if ((transparencyEnabled = enabled) == true) {
                //log.write("Enabling alpha transparency blending");
                glchecked!glEnable(GL_BLEND);
                glchecked!glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            } else {
                //log.write("Disabling alpha transparency");
                glchecked!glDisable(GL_BLEND);
            }
        }
    }

    void bindShader (GLuint shader) {
        //log.write("glState: binding shader %s", shader);
        if (shader != lastBoundShader) {
            glchecked!glUseProgram(shader);
            lastBoundShader = shader;
        }
    }
    void bindVao (GLuint vao) {
        //log.write("glState: binding vao %s", vao);
        if (vao != lastBoundVao) {
            glchecked!glBindVertexArray(vao);
            lastBoundVao = vao;
        }
    }
    void bindBuffer (GLenum type, GLuint vbo) {

        //log.write("glState: binding vbo %s", vbo);
        if (vbo != lastBoundBuffer) {
            glchecked!glBindBuffer(type, vbo);
            lastBoundBuffer = vbo;
        }
    }
    void bindTexture (GLenum type, GLuint texture) {
        //log.write("glState: binding texture %s", texture);
        if (texture != lastBoundTexture) {
            glchecked!glBindTexture(type, texture);
            lastBoundTexture = texture;
        }
    }
    void activeTexture (uint textureUnit) {
        //log.write("glState: activating texture %d", textureUnit - GL_TEXTURE0);
        if (textureUnit != lastActiveTexture)
            glchecked!glActiveTexture(lastActiveTexture = textureUnit);
    }
}

// gl.state

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


