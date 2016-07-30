module sb.gl.batch;
import sb.gl.context;
import sb.gl.texture;
import sb.gl.shader;

interface IBatch {
    //void bind (IShader);
    //void bind (ITexture, uint slot = 0);

    // Run raw gl in proper sequence (for bindings that haven't been written yet, etc)
    // Note: any data passed around must remain valid for 1-2 frames (no implicit temporaries!).
    // To facilitate this, see tempData().
    void execGL (void delegate());
    //void execGL (void function(void*), void*);

    // Make + return a copy of data (any arbitrary memory) using an internal per-frame, per-batch allocator.
    // This is mandatory if you're using local / mutable data in execGL (which is called _asynchronously_,
    // and possibly on another thread)
    //void* tempData (void* data, size_t size);

    // Save / reset state (bindings, etc)
    //void pushState (bool resetState = false);
    //void popState  ();

    // Release the batch (don't call this until you're done with the batch!)
    //void release ();
}

