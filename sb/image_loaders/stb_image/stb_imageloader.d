module sb.image_loaders.stb_imageloader;
import std.string: fromStringz;
import std.exception: enforce;
import std.format: format;
import std.typecons: RefCounted;

private extern(C) ubyte* stbi_load_from_memory (const(ubyte*), int, int*, int*, int*, int);
private extern(C) const(char)* stbi_failure_reason ();
private extern(C) void stbi_image_free (void*);

struct STB_Texture {
    string filename;   // metadata
    const size_t  width, height, size, componentDepth;
    const(ubyte*) data;
    
    this (string filename, ubyte* data, int w, int h, int d) {
        this.filename = filename;
        this.data = data;
        this.width  = cast(typeof(width))w;
        this.height = cast(typeof(height))h;
        this.size   = this.width * this.height;
        this.componentDepth = cast(typeof(componentDepth))d;

        import std.stdio;
        writefln("Loaded image data for '%s'", filename);
    }
    @disable this(this);

    ~this () {
        import std.stdio;
        writefln("Freeing image data for '%s'", filename);
        stbi_image_free(cast(void*)data);
    }
}
alias STB_TextureRef = RefCounted!STB_Texture;

public STB_TextureRef stb_loadImage (string filename, ubyte[] data, uint componentDepth = 0) {
    int w, h, d;
    auto ptr = stbi_load_from_memory(data.ptr, cast(int)data.length, &w, &h, &d, cast(int)componentDepth);
    enforce(ptr, format("Could not load '%s': %s", filename, stbi_failure_reason().fromStringz));
    return STB_TextureRef(filename, ptr, w, h, d);
}
