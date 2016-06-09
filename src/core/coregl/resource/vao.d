module gsb.coregl.resource.vao;
import gsb.coregl.resource.interfaces;
import gsb.coregl.glstate;
import gsb.coregl.gl;

class VAO : GLResource {
    private GLuint handle = 0;
    auto get () {
        if (!handle)
            glchecked!glGenVertexArrays(1, &handle);
        return handle;
    }
    final void release () {
        if (handle) {
            glchecked!glDeleteVertexArrays(1, &handle);
            handle = 0;
        }
    }
    void bind () {
        glState.bindVao(get());
    }
}