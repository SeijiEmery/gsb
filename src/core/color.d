
module gsb.core.color;

import gl3n.linalg;
import gl3n.ext.hsv;

import std.format;
import std.regex;
import std.conv;
import std.stdio;

private auto clamp (T) (T x, T m, T n) {
    return max(min(x, m), n);
}

struct Color {
    vec4 components;
    alias components this;

    static Color fromRGBA (vec4 rgba) { return Color(rgba); }
    static Color fromRGBA (float r, float g, float b, float a) {
        return Color(r, g, b, a);
    }
    static Color fromHSVA (vec4 hsva) {
        return Color(hsv2rgb(hsva));
    }
    static Color fromHSVA (float h, float s, float v, float a) {
        return Color(hsv2rgb(vec4(h, s, v, a)));
    }
    static vec4  toHSVA (Color color_rgba) {
        return rgb2hsv(color_rgba.components);
    }
    static vec4  toHSVA (vec4 color_rgba) {
        return rgb2hsv(color_rgba);
    }

    this (vec4 rgba) { 
        this.components = rgba; 
    }
    this (float r, float g, float b, float a) {
        this.components = vec4(r, g, b, a);
    }
    this (vec3 rgb) {
        this.components = vec4(rgb, 1.0);
    }
    this (float r, float g, float b) {
        this.components = vec4(r, g, b, 1.0);
    }
    this (Color color) {
        this.components = color.components;
    }
    this (uint hexv) {
        import std.bitmanip;
        ubyte[4] values = nativeToLittleEndian(hexv);
        this.components = values[3] ?
            vec4(
                (cast(float)values[3]) * (1f / 255f),
                (cast(float)values[2]) * (1f / 255f),
                (cast(float)values[1]) * (1f / 255f),
                (cast(float)values[0]) * (1f / 255f)) :

            vec4( 
                (cast(float)values[2]) * (1f / 255f),
                (cast(float)values[1]) * (1f / 255f),
                (cast(float)values[0]) * (1f / 255f),
                1.0 );
    }
    this (string colorHash) {
        static auto ctr = ctRegex!("#([0-9a-fA-F]+)");
        auto m = matchFirst(colorHash, ctr);
        if (!m.empty && m[1].length == 6 || m[1].length == 8) {
            //string s = colorHash[1..$];
            string s;
            this.components = vec4(
                cast(float)parse!int((s = colorHash[1..3], s), 16) * (1 / 255.0),
                cast(float)parse!int((s = colorHash[3..5], s), 16) * (1 / 255.0),
                cast(float)parse!int((s = colorHash[5..7], s), 16) * (1 / 255.0),
                colorHash.length == 9 ?
                    cast(float)parse!int((s = colorHash[7..9], s), 16) * (1 / 255.0) :
                    1.0);
        } else {
            throw new Exception(format("Cannot construct Color from '%s'", colorHash));
        }
    }

    bool opEquals (Color other) {
        return r == other.r && g == other.g && b == other.b && a == other.a;
        //return components == other.components;
    }

    // from http://aras-p.info/blog/2009/07/30/encoding-floats-to-rgba-the-final/
    float toPackedFloat () {
        return components.dot(vec4(1.0, 1/255.0, 1/65025.0, 1/160581375.0));
    }

    // Add this to shaders to unpack packed color values
    mixin template unpackRGBA () {
        vec4 unpackRGBA (float packed) {
            vec4 enc = vec4(1.0, 255.0, 65025.0, 160581375.0) * packed;
            enc = fract(enc);
            vec4 foo = enc.yzww * vec4(1.0/255.0, 1.0/255.0, 1.0/255.0, 0.0);
            enc -= foo;
            //enc -= enc.yzww * vec4(1.0/255.0, 1.0/255.0, 1.0/255.0, 0.0);
            return enc;
        }
    }
    static Color unpack (float v) {
        mixin fract;
        mixin unpackRGBA;
        return Color(unpackRGBA(v));
    }

    // And here's a basic fract implementation so we can get the above to compile in D
    // (do NOT mixin this into the actual shader; the function should just be in scope outside,
    //  and we should hopefully never need to actually _use_ this (since it's defined in glsl))
    mixin template fract () {
        vec4 fract (vec4 v) {
            import std.math: floor;
            return vec4(
                v.x - floor(v.x),
                v.y - floor(v.y),
                v.z - floor(v.z),
                v.w - floor(v.w),
            );
        }
    }

    string toString () {
        return a != 1f ?
            format("#%2x%2x%2x%2x", 
                cast(int)(clamp(r, 1.0, 0.0) * 255),
                cast(int)(clamp(g, 1.0, 0.0) * 255),
                cast(int)(clamp(b, 1.0, 0.0) * 255),
                cast(int)(clamp(a, 1.0, 0.0) * 255)) :
            format("#%2x%2x%2x",
                cast(int)(clamp(r, 1.0, 0.0) * 255),
                cast(int)(clamp(g, 1.0, 0.0) * 255),
                cast(int)(clamp(b, 1.0, 0.0) * 255));
    }

    unittest {
        writefln("%x, %s", 0x1256afce, Color(0x1256afce));
        writefln("%x, %s", 0x1256af, Color(0x1256af));
        writefln("%s, %s, equal: %s", to!Color("#1fadff"), Color(0x1fadff), Color("#1fadff") == Color(0x1fadff));
        writefln("%s, %s, equal: %s", to!Color("#1fadff").components, Color(0x1fadff).components,
            Color("#1fadff").components == Color(0x1fadff).components);

        assert(Color(1.0, 0.0, 1.0, 0.0) == Color(1.0, 0.0, 1.0, 0.0));
        assert(Color(1.0, 0.0, 1.0, 0.0) != Color(0.0, 1.0, 1.0, 0.0));
        writeln(Color(1.0, 1.0, 1.0, 1.0));
        writeln(Color("#ffffff"));

        assert(Color("#ffffff") == Color(1.0, 1.0, 1.0, 1.0));
        assert(Color("#000000") == Color(0.0, 0.0, 0.0, 1.0));
        assert(to!Color("#1fadff") == Color("#1fadff"));
        //assert(to!Color("#1fadff") == Color(0x1fadff));
        //assert(to!Color("#1fadff2e") == Color(0x1fadff2e));
        writeln(to!string(to!Color("#1fadff")));

        //assert(to!string(to!Color("#1fadff")) == "#1fadffff");

        //writeln(Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0));
        //writeln(to!Color(to!string(Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0))));

        assert(to!Color(to!string(Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0))) == Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0));
        //assert(to!vec4(Color(0.17, 0.47, 0.94)) == vec4(0.17, 0.47, 0.94, 0.0));
        //assert(to!Color(vec4(0.17, 0.47, 0.94, 0.0)) == Color(0.17, 0.47, 0.94));
        //assert(to!vec4(to!Color(vec4(0.17, 0.47, 0.94, 0.0))) == vec4(0.17, 0.47, 0.94, 0.0));
    }
}






















