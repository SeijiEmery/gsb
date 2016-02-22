
module gsb.core.color;

import gl3n.linalg;
import std.format;
import std.regex;
import std.conv;
import std.stdio;


private auto clamp (T) (T x, T m, T n) {
    return max(min(x, m), n);
}

struct Color {
    float r = 0, g = 0, b = 0, a = 0;

    this (float r, float g, float b, float a) {
        this.r = r; this.g = g; this.b = b; this.a = a;
    }
    this (float r, float g, float b) {
        this.r = r; this.g = g; this.b = b;
    }
    this (vec4 v) {
        this.r = v.x; this.g = v.y; this.b = v.z; this.a = v.w;
    }
    this (string colorHash) {
        static auto ctr = ctRegex!("#([0-9a-fA-F]+)");
        auto m = matchFirst(colorHash, ctr);
        if (!m.empty && m[1].length == 6 || m[1].length == 8) {
            //string s = colorHash[1..$];
            string s;
            r = cast(float)parse!int((s = colorHash[1..3], s), 16) / 255.0;
            g = cast(float)parse!int((s = colorHash[3..5], s), 16) / 255.0;
            b = cast(float)parse!int((s = colorHash[5..7], s), 16) / 255.0;
            if (colorHash.length == 9)
                a = cast(float)parse!int((s = colorHash[7..9], s), 16) / 255.0;
        } else {
            throw new Exception(format("Cannot construct Color from '%s'", colorHash));
        }
    }
    string toString () {
        return format("#%2x%2x%2x", 
            cast(int)(clamp(r, 1.0, 0.0) * 255),
            cast(int)(clamp(g, 1.0, 0.0) * 255),
            cast(int)(clamp(b, 1.0, 0.0) * 255),
            //cast(int)(clamp(a, 1.0, 0.0) * 255)
        );
    }
    //vec4  () {
    //    return vec4(r, g, b, a);
    //}
    bool opEquals (Color c) {
        return r == c.r && g == c.g && b == c.b && a == c.a;
    }

    unittest {
        assert(Color(1.0, 0.0, 1.0, 0.0) == Color(1.0, 0.0, 1.0, 0.0));
        assert(Color(1.0, 0.0, 1.0, 0.0) != Color(0.0, 1.0, 1.0, 0.0));
        writeln(Color(1.0, 1.0, 1.0, 1.0));
        writeln(Color("#ffffff"));

        assert(Color("#ffffff") == Color(1.0, 1.0, 1.0, 0.0));
        assert(Color("#000000") == Color(0.0, 0.0, 0.0, 0.0));
        assert(to!Color("#1fadff") == Color("#1fadff"));
        assert(to!string(to!Color("#1fadff")) == "#1fadff");

        //writeln(Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0));
        //writeln(to!Color(to!string(Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0))));

        assert(to!Color(to!string(Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0))) == Color(0x94 / 255.0, 0x47 / 255.0, 0xfa / 255.0));
        //assert(to!vec4(Color(0.17, 0.47, 0.94)) == vec4(0.17, 0.47, 0.94, 0.0));
        //assert(to!Color(vec4(0.17, 0.47, 0.94, 0.0)) == Color(0.17, 0.47, 0.94));
        //assert(to!vec4(to!Color(vec4(0.17, 0.47, 0.94, 0.0))) == vec4(0.17, 0.47, 0.94, 0.0));
    }
}






















