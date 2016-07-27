module sb.gl.context;
import sb.gl.batch;
import sb.gl.texture;
import sb.gl.shader;
//import sb.platform;

enum GLVersion { GL_410 }

//IGraphicsContext sbCreateGraphicsContext (IPlatform, GLVersion);

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
    void swapFrame ();
}




