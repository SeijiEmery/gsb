module sb.gl.context;
import sb.gl.batch;
import sb.gl.texture;
import sb.gl.shader;
import std.variant: Algebraic;

//
// Graphics lib abstraction layer:
//   GLVersion: unique version id (includes opengl + possibly others like directx, etc)
//      could include: GL_410, GL_450, GL_320, VULKAN_WHATEVER, METAL, DX_12, etc
//      (but for the near future we're only interested in supporting GL_410)
//
//   GLVersionInfo: variant that includes per-graphics-lib info.
//      if other graphics backends are added, non-opengl ones would get their own
//      struct (eg. MetalVersionInfo, VulkanVersionInfo).
//
//   IGraphicsLib: opaque interface that handles graphics lib creation + shutdown;
//      is kinda-sorta tied to the platform backend (glfw), but the goal is to make
//      the graphics + platform backends separate + orthogonal.
//      
//   IGraphicsContext: graphics interface abstraction layer.
//      May / will be extended to support multiple backends in the future (if we can
//      abstract multiple graphics libs to the same interface?), but in the meantime
//      this is just a high-level wrapper around GL_410.
//

enum GraphicsLibVersion { GL_410 }

struct OpenglVersionInfo {
    int  VERSION_MAJOR;
    int  VERSION_MINOR;    
    bool IS_CORE_PROFILE;
    bool IS_FORWARD_COMPAT;
}
alias GLVersionInfo = Algebraic!(OpenglVersionInfo);

// Try creating a graphics lib instance.
// We may try to support dynamic switching at _some point_ in the far, far future,
// but in the meantime the graphics lib impl is effectively hardcoded in the lib impl 
// you choose (eg. gl/gl_41_impl), and the version is checked by an enforce guard
// (passing anything other than GL_410 while linking to the GL_41 lib will throw an Exception)
//
// MOVED TO gl_impl.di
//
//IGraphicsLib sbCreateGraphicsLib (GraphicsLibVersion);

// Graphics lib handle. 
// Methods are NOT threadsafe + require external guards and/or sane calling order.
interface IGraphicsLib {
    GraphicsLibVersion glVersion ();
    GLVersionInfo getVersionInfo ();

    void preInit      ();
    void initOnThread ();
    void teardown     ();

    IGraphicsContext getContext ();
}

// Thread-safe OpenGL handle / abstraction used to create GL resources, etc.,
interface IGraphicsContext {
    
    // Batch creation: create a new batch with createBatch, or get a new / existing
    // batch instance for this thread
    IBatch createBatch ();     // NOT thread safe; create a new one for each thread
    IBatch getLocalBatch ();   // or just use this (thread-local batch)

    // Create GL resources: textures + shaders, etc
    ITexture createTexture ();
    IShader  createShader ();

    // Swap current frame + draw (and reset) all active batches
    void endFrame ();
}




