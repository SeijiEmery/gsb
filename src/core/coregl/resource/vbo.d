module gsb.coregl.resource.vbo;
import gsb.coregl.resource.interfaces;
import gsb.coregl.glstate;
import gsb.coregl.gl;

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


class VBO : GLResource {
    private GLuint handle = 0;
    private GLenum bindingType = 0;
    private GLenum usageType   = 0;
    private size_t reservedSize = 0;
    private bool   hasUsedData = false;

    auto get () {
        if (!handle) {
            glchecked!glGenBuffers(1, &handle);
            bindingType = usageType = 0;
            reservedSize = 0;
            hasUsedData = false;
        }
        return handle;
    }
    final void release () {
        if (handle) {
            glchecked!glDeleteBuffers(1, &handle);
            handle = 0;
        }
    }
    void bind (GLenum type) {
        glState.bindBuffer(type, get()); bindingType = type;
    }
    void bufferData (GLenum type, GLenum usage)(size_t size, void* data) if (isValidGlTarget(type)) {
        bind(type);
        glchecked!glBufferData(type, size, data, usage);
    }
    void bufferData (GLenum type, GLenum usage, T)(T[] data) if (isValidGlTarget(type)) {
        bind(type);
        glchecked!glBufferData(type, data.length, data.ptr, usage);
    }

    void* mapRange (GLenum type)(size_t offset, size_t size, GLbitfield access) if (isValidGlTarget(type)) {
        bind(type);
        return glchecked!glMapBufferRange(type, offset, size, access);
    }
    void unmap (GLenum type)() if (isValidGlTarget(type)) {
        glState.bindBuffer(type, handle);
        glchecked!glUnmapBuffer(type);
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

















