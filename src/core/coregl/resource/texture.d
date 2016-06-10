module gsb.coregl.resource.texture;
import gsb.coregl.gl;
import gsb.coregl.resource.interfaces;
import gsb.coregl.resource.vbo: VBO;
import gsb.coregl.glstate;
import gsb.engine.threads;
import gsb.engine.engineconfig;
import gsb.core.log;

import std.exception: enforce;
import std.format: format;
import core.atomic;

interface ITexture {
    ITexture pixelData (TextureDataFormat, vec2i, ubyte[]);
    ITexture pixelData (TextureDataFormat, vec2i, ubyte[] delegate());
    ITexture setFilter (GLenum minFilter, GLenum magFilter);
    ITexture release ();
}

struct TextureDataFormat {
    GLenum internal;  // internal format: base format | sized format | compressed format
    GLenum encoding;  // texture format: GL_RED | GL_RG | GL_RGB | ...
    GLenum type;

    this (GLenum internalType, GLenum encodingType, GLenum componentType) {
        enforce(internalType.isValidTextureInternalType, format("Invalid texture type: %s", internalType));
        enforce(encodingType.isValidTextureEncoding, format("Invalid texture encoding: %s", encoding));
        enforce(componentType.isValidTextureComponentType, format("Invalid texture component type: %s", type));
        
        this.internal = internalType;
        this.encoding = encodingType;
        this.type = componentType;
    }
}
bool isValidTextureEncoding (GLenum encoding) {
    switch (encoding) {
        case GL_RED: case GL_RG: case GL_RGB: case GL_BGR: case GL_RGBA:
        case GL_BGRA: case GL_RED_INTEGER: case GL_RG_INTEGER: case GL_RGB_INTEGER:
        case GL_BGR_INTEGER: case GL_RGBA_INTEGER: case GL_BGRA_INTEGER: 
        case GL_STENCIL_INDEX: case GL_DEPTH: case GL_DEPTH_STENCIL:
            return true;
        default:
            return false;
    }
}
bool isValidTextureComponentType (GLenum type) {
    switch (type) {
        case GL_UNSIGNED_BYTE: case GL_BYTE: case GL_UNSIGNED_SHORT: case GL_SHORT:
        case GL_UNSIGNED_INT: case GL_INT: case GL_FLOAT: case GL_UNSIGNED_BYTE_3_3_2:
        case GL_UNSIGNED_BYTE_2_3_3_REV: case GL_UNSIGNED_SHORT_5_6_5:
        case GL_UNSIGNED_SHORT_5_6_5_REV: case GL_UNSIGNED_SHORT_4_4_4_4:
        case GL_UNSIGNED_SHORT_4_4_4_4_REV: case GL_UNSIGNED_SHORT_5_5_5_1:
        case GL_UNSIGNED_SHORT_1_5_5_5_REV: case GL_UNSIGNED_INT_8_8_8_8:
        case GL_UNSIGNED_INT_8_8_8_8_REV: case GL_UNSIGNED_INT_10_10_10_2:
        case GL_UNSIGNED_INT_2_10_10_10_REV:
            return true;
        default:
            return false;
    }
}
bool isValidTextureInternalType (GLenum type) {
    switch (type) {
        // Base formats
        case GL_DEPTH_COMPONENT: case GL_DEPTH_STENCIL: case GL_RED: case GL_RG: case GL_RGB:
        case GL_RGBA: 

        // Sized formats
        case GL_R8: case GL_R8_SNORM: case GL_R16: case GL_R16_SNORM:
        case GL_RG8: case GL_RG8_SNORM: case GL_RG16: case GL_RG16_SNORM: case GL_R3_G3_B2:
        case GL_RGB4: case GL_RGB5: case GL_RGB8: case GL_RGB8_SNORM: case GL_RGB10:
        case GL_RGB12: case GL_RGB16_SNORM: case GL_RGBA2: case GL_RGBA4: case GL_RGB5_A1:
        case GL_RGBA8: case GL_RGBA8_SNORM: case GL_RGB10_A2: case GL_RGB10_A2UI:
        case GL_RGBA12: case GL_RGBA16: case GL_SRGB8: case GL_SRGB8_ALPHA8: 
        case GL_R16F: case GL_RG16F: case GL_RGB16F: case GL_RGBA16F: 
        case GL_R32F: case GL_RG32F: case GL_RGB32F: case GL_RGBA32F: case GL_R11F_G11F_B10F:
        case GL_RGB9_E5: case GL_R8I: case GL_R8UI: case GL_R16I: case GL_R16UI: 
        case GL_R32I: case GL_R32UI: case GL_RG8I: case GL_RG8UI: case GL_RG16I: 
        case GL_RG16UI: case GL_RG32I: case GL_RG32UI: case GL_RGB8I: case GL_RGB8UI: 
        case GL_RGB16I: case GL_RGB16UI: case GL_RGB32I: case GL_RGB32UI: case GL_RGBA8I: 
        case GL_RGBA8UI: case GL_RGBA16I: case GL_RGBA16UI: case GL_RGBA32I: case GL_RGBA32UI:

        // Compressed formats
        case GL_COMPRESSED_RED: case GL_COMPRESSED_RG: case GL_COMPRESSED_RGB: case GL_COMPRESSED_RGBA:
        case GL_COMPRESSED_SRGB:          case GL_COMPRESSED_SRGB_ALPHA: 
        case GL_COMPRESSED_RED_RGTC1:     case GL_COMPRESSED_SIGNED_RED_RGTC1: 
        case GL_COMPRESSED_RG_RGTC2:      case GL_COMPRESSED_SIGNED_RG_RGTC2:
        //case GL_COMPRESSED_RGBA_BPTC_UNORM:       case GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM: 
        //case GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT: case GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT:
            return true;
        
        default:
            return false;
    }
}

class GlTexture : ITexture {
    GLuint m_handle = 0;
    ulong m_dataLen = 0;

    import gsb.utils.checksum;
    GL_TEXTURE_DATA_CHECKSUM.HashType m_dataHash;

    GLint  m_internalFormat = GL_RGBA;
    GLenum m_magFilter = GL_LINEAR;
    GLenum m_minFilter = GL_LINEAR;
    vec2i  m_size;

    // Dirty flags
    shared uint m_dirtyAttribs = 0; // guarded by atomic operations (see setDirty())
    private enum : uint {
        TEX_ATTRIB_MIN_FILTER = 1, TEX_ATTRIB_MAG_FILTER = 2,
    }

    //
    // Fontend user interface (from non-gl threads)
    //
    ~this () {
        if (gsb_isGraphicsThread)
            doRelease();
        else 
            // Not sure how well this will work, but w/e...
            gsb_graphicsThread.send(&doRelease);
    }

    ITexture pixelData (TextureDataFormat fmt, vec2i size, ubyte[] data) {

        if (hashDiff!GL_TEXTURE_DATA_CHECKSUM(m_dataHash, data) || size != m_size) {
            m_size = size;

            gsb_graphicsThread.send({
                if (!m_handle) createTexture();
                setData(fmt, size, data);
            });
        } else {
            static if (SHOW_GL_TEXTURE_SKIPPED_OPERATIONS)
                log.write("Skipped update (hash %s)", hash);
        }
        return this;
    }
    ITexture pixelData (TextureDataFormat fmt, vec2i size, ubyte[] delegate() get) {
        gsb_graphicsThread.send({
            auto data = get();

            if (hashDiff!GL_TEXTURE_DATA_CHECKSUM(m_dataHash, data) || size != m_size) {
                m_size = size;

                if (!m_handle) createTexture();
                setData(fmt, size, data);
            } else {
                static if (SHOW_GL_TEXTURE_SKIPPED_OPERATIONS)
                    log.write("Skipped update (hash %s)", hash);
            }
        });
        return this;
    }
    ITexture setFilter (GLenum minFilter, GLenum magFilter) {
        if (m_minFilter != minFilter || m_magFilter != magFilter) {
            m_minFilter = minFilter;
            m_magFilter = magFilter;

            setDirty( TEX_ATTRIB_MIN_FILTER | TEX_ATTRIB_MAG_FILTER );
            gsb_graphicsThread.send(&updateAttribs);
        }
        return this;
    }
    ITexture release () {
        if (m_handle) gsb_graphicsThread.send(&doRelease);
        return this;
    }

    //
    // Internal interface (from gl thread)
    //

    // Bind texture to a texture slot (GL_TEXTURE0 + slot).
    // Binds texture + returns true iff texture exists (handle != 0), or false otherwise.
    // If this fails, client code should bind the default / "null" texture instead.
    bool bind (uint slot) {
        if (m_handle) {
            static if (SHOW_GL_TEXTURE_BINDING)
                log.write("Binding texture %s", m_handle);
            checked_glActiveTexture(GL_TEXTURE0 + slot);
            checked_glBindTexture(GL_TEXTURE_2D, m_handle);
            return true;
        } else {
            static if (SHOW_GL_TEXTURE_BINDING)
                log.write("Null texture!");
        }
        return false;
    }

    //
    // Impl details (should/will always be executed on the graphics thread, and will be implicitely locked)
    //
    private void createTexture () {
        if (!m_handle) {
            checked_glGenTextures(1, &m_handle);

            static if (SHOW_GL_TEXTURE_OPERATIONS)
                log.write("Generated texture %s", m_handle);

            //atomicStore(m_dirtyAttribs, 0xff);
            m_dirtyAttribs = 0xff;  // should be fine, since we're writing all flags
            updateAttribs();
        }
    }

    // Set dirty attrib flags (probably called from non-gl thread).
    // Note: since m_dirtyAttribs guards important state that _may_ cause subtle bugs if subjected
    // to race conditions (ie. mark one texture attrib on one thread while we're running update() on
    // another), it's important that this remain synchronized; since this is the one part of GlTexture
    // that is _not_ guarded by gsb message semantics, we'll use atomic operations to set + get flags.
    private void setDirty (uint flags) {
        while (!cas(&m_dirtyAttribs, m_dirtyAttribs, m_dirtyAttribs | flags)) {}
    }
    private void updateAttribs () {
        if (m_handle && m_dirtyAttribs) {
            static if (SHOW_GL_TEXTURE_OPERATIONS)
                log.write("Setting attribs: %s (minfilter = %s, magfilter = %s)", m_handle, 
                    m_minFilter, m_magFilter);

            checked_glBindTexture(GL_TEXTURE_2D, m_handle);

            auto dirty = atomicLoad(m_dirtyAttribs);
            if (dirty & TEX_ATTRIB_MIN_FILTER) 
                checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, m_minFilter);
            if (dirty & TEX_ATTRIB_MAG_FILTER)
                checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, m_magFilter);
            atomicStore(m_dirtyAttribs, 0);
        }
    }
    private void setData (TextureDataFormat dataFmt, vec2i size, ubyte[] data) {

        static if (SHOW_GL_TEXTURE_OPERATIONS)
            log.write("Setting data: %s (size %s, %s bytes, hash %s, format %s)", m_handle,
                size, data.length, m_dataHash, dataFmt);

        checked_glBindTexture(GL_TEXTURE_2D, m_handle);
        checked_glTexImage2D (GL_TEXTURE_2D, 0, m_internalFormat = dataFmt.internal, 
            size.x, size.y, 0, dataFmt.encoding, dataFmt.type, data.ptr);
    }
    private void doRelease () {
        if (m_handle) {
            static if (SHOW_GL_TEXTURE_RELEASE)
                log.write("Releasing texture %s", m_handle);
            checked_glDeleteTextures(1, &m_handle);
            m_handle = 0;
        }
    }
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