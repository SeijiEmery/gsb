
module gsb.coregl.vao;
import gsb.coregl.sharedimpl;
import gsb.coregl.glstate;

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