module sb.gl.texture;
import gl3n.linalg;

interface ITexture {
    ITexture setFormat (TextureInternalFormat);
    ITexture fromFile  (string path);
    ITexture fromBytes (ubyte[] contents, vec2i dimensions, TextureSrcFormat format);

    // Attempt to bind texture to slot. Returns false if texture is not bindable 
    // (did not buffer data, etc).
    bool bindTo    (uint slot);

    // Release / retain
    void release ();
    void retain  ();
}
enum TextureInternalFormat { RED, RGB, RGBA }
enum TextureSrcFormat      { RED, RGB, RGBA }
