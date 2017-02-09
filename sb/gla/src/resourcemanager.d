module sb.gla.resourcemanager;
public import sb.gla.resource.shader;
public import sb.gla.resource.texture2d;
public import sb.gla.resource.vbo;
public import sb.gla.resource.vao;

enum GLAResourceType { None = 0, Shader, Texture2d, Buffer, VertexArray }
struct GLAResource {
    private GLAResourceType type = GLAResourceType.None;
    private uint handle = 0;
    private int  refCount = 0;
    
    private Payload data;
    private union Payload {
        GLAShader      shader;
        GLATexture2d   texture2d;
        GLABuffer      vbo;
        GLAVertexArray vao;
    }
    private void initAs (GLAResourceType rtype) {
        assert(type == GLAResourceType.None);
        type = rtype;
        handle = refCount = 0;
    }
    private void deinit () {
        switch (type) {
            case GLAResourceType.None:        return;
            case GLAResourceType.Shader:      shader.deinit(this); break;
            case GLAResourceType.Texture2d:   texture2d.deinit(this); break;
            case GLAResourceType.Buffer:      vbo.deinit(this);   break;
            case GLAResourceType.VertexArray: vao.deinit(this); break; 
        }
        type     = GLAResourceType.None;
        handle   = 0;
        refCount = 0;
    }

    void retain () { ++refCount; }
    void release () { --refCount; }
}





