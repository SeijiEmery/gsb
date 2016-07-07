module sb.gl.texture;
import gl3n.linalg;

interface ITexture {
    ITexture setFormat (TextureInternalFormat);
    ITexture fromFile  (string path);
    ITexture fromBytes (ubyte[] contents, vec2i dimensions, TextureSrcFormat format);

    // Delete texture
    void release ();
}
enum TextureInternalFormat { RED, RGB, RGBA }
enum TextureSrcFormat      { RED, RGB, RGBA }
