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
    size_t  width, height, size, componentDepth;
    ubyte[] data;
    
    this (string filename, ubyte[] data, int w, int h, int d) {
        this.filename = filename;
        this.data = data;
        this.width = cast(typeof(width))w;
        this.height = cast(typeof(height))h;
        this.size = width * height;
        this.componentDepth = cast(typeof(componentDepth))d;
    }
}

public STB_Texture stb_loadImage (string filename, ubyte[] data, uint componentDepth = 0) {
    int w, h, d;
    auto ptr = stbi_load_from_memory(data.ptr, cast(int)data.length, &w, &h, &d, cast(int)componentDepth);
    enforce(ptr && w * h != 0, format("Could not load '%s': %s", filename, stbi_failure_reason().fromStringz));

    auto texData = ptr[0 .. w * h];
    stbi_image_free(ptr);

    return STB_Texture(filename, texData, w, h, d);
}
