module rev3.renderer3d.renderer3d_opengl41;
public  import rev3.core.math;
private import rev3.core.opengl;


final class Renderer3d {
    private GLContext       gl;
    private Drawcall[][2]   pendingDrawcalls;
    private int             nextPass;

    this (GLContext context = null) {
        gl = context || new GLContext();
    }

    //
    // Available Drawcalls
    //

    struct RenderPass {
        Renderer3d renderer;
        Drawcall[] drawcalls;
        int        index;

        this (Renderer3d renderer, int index) { 
            this.renderer = renderer; 
            this.index = index; 
        }
        ~this () {
            if (drawcalls.length) {
                submit();
            }
        }

        void draw (ref Ref!Mesh mesh, ref Ref!Material material) {
            assert(mesh && material);
            drawcalls ~= DrawMesh3d(mesh.get, material.get);
        }
        void submit () {
            renderer.submit(drawcalls, index);
            drawcalls = [];
        }
    }
    alias Drawcall = Algebraic!(DrawMesh3d);
    struct DrawMesh3d { Mesh mesh; Material material; }


    RenderPass begin  () { return RenderPass(this, nextPass); }
    void       submit (ref RenderPass pass) {
        if (pass.index % 2 == nextPass % 2) {
            pendingDrawcalls[nextPass] ~= pass.drawcalls;
        }
    }

    //
    // Rendering impl...
    //

    void renderFrame () {
        auto drawcalls = pendingDrawcalls[nextPass++];
        // ...
    }

    //
    // Asset management
    //

    private import rev3.core.resource;
    private ResourceManager!(R3dResource, R3dResourceType) resourceManager;

    public auto create (T, Args...)(Args args) {
        return resourceManager.create!T(this, args);
    }
    public void gcResources () {
        resourceManager.gcResources();
    }
    public auto ref getActiveResources () {
        return resourceManager.getActive();
    }
}
class R3dResource : ManagedResource {
    protected Renderer3d renderer;
    protected this (Renderer3d renderer) { this.renderer = renderer; assert(renderer != null); }
}
enum  R3dResourceType {
    Shader, Material, Mesh, Texture
}
class Shader : R3dResource {
    this (Renderer3d renderer) { super(renderer); }
    void resourceDtor () {}
}
class Material : R3dResource {
    this (Renderer3d renderer) { super(renderer); }
    void resourceDtor () {}

    public Ref!Shader           shader;
    public Ref!Texture[string]  textures;
}
class Mesh : R3dResource {
    this (Renderer3d renderer) { super(renderer); }
    void resourceDtor () {}
}
class Texture : R3dResource {
    this (Renderer3d renderer) { super(renderer); }
    void resourceDtor () {}
}
