module sb.model_loaders.loadobj.loadobj_impl;
import std.algorithm;
import gl3n.linalg;
import std.conv;
import std.exception: enforce;
import std.string: munch, splitLines, strip;
import std.format;

struct SbObj_TriVert {
    vec4 v;
    vec3 n;
    vec2 t;
}
struct SbObj_Triangle {
    SbObj_TriVert[3] verts;
}

void sbLoadObj ( 
    string fileContents,
    void delegate (SbObj_Triangle) onTri,
    void delegate (string mtlName, size_t triCount) onMtl,
    void delegate (string mtlLibName) onMtlLib,
    void delegate (uint lineNum, string line) onUnhandledLine,
    void delegate (string msg, uint lineNum, string line) onParseError,
) {
    vec4[] verts, gen_normals;
    vec3[] normals;
    vec2[] uvs;

    struct IntermedTriangle {
        int v0, v1, v2, hasNormals;
        int n0, n1, n2, t0, t1, t2;
    }
    IntermedTriangle[] intermedTris;
    float[] tempValues;
    string prevMtl = null;

    void emitTris () {
        if (verts.length * 3 != normals.length * 4) {
            foreach (ref n; gen_normals) {
                n.xyz /= n.w;
            }
        }
        foreach (ref tri; intermedTris) {
            //import std.stdio;
            //writefln("tri!      %s/%s/%s  %s/%s/%s  %s/%s/%s", tri.v0, tri.t0, tri.n0, tri.v1, tri.t1, tri.n1, tri.v2, tri.t2, tri.n2);
            //writefln("\tvertex: %s, %s, %s", tri.v0, tri.v1, tri.v2);
            //writefln("\tnormal: %s, %s, %s", tri.n0, tri.n1, tri.n2);
            //writefln("\tuvs:    %s, %s, %s", tri.t0, tri.t1, tri.t2);

            onTri(SbObj_Triangle([
                SbObj_TriVert( verts[tri.v0], tri.hasNormals ? normals[tri.n0] : gen_normals[tri.v0].xyz, uvs[tri.t0] ),
                SbObj_TriVert( verts[tri.v1], tri.hasNormals ? normals[tri.n1] : gen_normals[tri.v1].xyz, uvs[tri.t1] ),
                SbObj_TriVert( verts[tri.v2], tri.hasNormals ? normals[tri.n2] : gen_normals[tri.v2].xyz, uvs[tri.t2] ),
            ]));
        }
    }

    void changeMtl ( string name ) {
        if (prevMtl) {
            onMtl( prevMtl, intermedTris.count );
            emitTris();
            intermedTris.length = 0;

            //verts.length = 0;
            //gen_normals.length = 0;
            //normals.length = 0;
            //uvs.length = 0;
            //assert(tempValues.length == 0);
        }
        prevMtl = name;

    }
    bool tryParseInt (ref string s, ref int v) {
        auto sv = s.munch("-0123456789");
        if (sv.length)
            return v = sv.parse!int, true;
        return false;
    }

    void parseTri (ref string s) {
        int[4] v, n, t;
        uint i, vcount = 0, ncount = 0, tcount = 0;

        while (vcount < 4 && s.length) {
            enforce(tryParseInt(s, v[i]), format("expected index, not '%s'", s));
            ++vcount;

            if (s[0] == '/') {
                s = s[1..$];
                if (tryParseInt(s, t[i]))
                    ++tcount;

                if (s[0] == '/') {
                    s = s[1..$];
                    if (tryParseInt(s, n[i]))
                        ++ncount;
                }
            }
            ++i;
            s.munch(" \t");
        }
        enforce((tcount == 0 || tcount == vcount) && (ncount == 0 || ncount == vcount), "unbalanced indices");
        enforce(vcount == 3 || vcount == 4, format("expected face 3-4 pairs, not %d", vcount));

        //enforce(vcount == 3, "quads not supported");
        
        for (i = vcount; i --> 0; ) {
            if (v[i] < 0) 
                v[i] += verts.length;
            else
                v[i] -= 1;  // wavefront indices start at 1 for whatever reason...

            enforce(v[i] >= 0 && v[i] < verts.length,
                format("out of range: vertex %s [0, %s)", v[i], verts.length));
        }
        if (tcount) {
            for (i = tcount; i --> 0; ) {
                if (t[i] < 0) 
                    t[i] += uvs.length;
                else
                    t[i] -= 1;

                enforce(t[i] >= 0 && t[i] < uvs.length,
                    format("out of range: uv %s [0, %s)", t[i], uvs.length));
            }
        }
        if (ncount) {
            for (i = ncount; i --> 0; ) {
                if (n[i] < 0) 
                    n[i] += normals.length;
                else
                    n[i] -= 1;   

                enforce(n[i] >= 0 && n[i] < normals.length,
                    format("out of range: normal %s [0, %s)", n[i], normals.length));
            }
        }
        intermedTris ~= IntermedTriangle(
            v[0], v[1], v[2], ncount,
            n[0], n[1], n[2],
            t[0], t[1], t[2],
        );
        if (vcount == 4) {
            intermedTris ~= IntermedTriangle(
                v[0], v[2], v[3], ncount,
                n[0], n[2], n[3],
                t[0], t[2], t[3]
            );
        }
        if (ncount == 0) {
            auto fnorm = -cross(
                verts[v[0]].xyz - verts[v[1]].xyz,
                verts[v[2]].xyz - verts[v[1]].xyz);

            assert(gen_normals.length == verts.length);
            for (i = vcount; i --> 0; ) {
                gen_normals[v[i]] += vec4(fnorm, 1.0);
            }
        }
    }

    uint parseFloats (ref string s, ref float[] values, uint minCount, uint maxCount) {
        uint n = 0;
        string sv, s_start = s;
        while (s.length && ((sv = s.munch("0123456789e.-")), sv.length) ) {
            enforce(++n <= maxCount, format("too many values (expected %s): %s, '%s', '%s'",
               format(minCount == maxCount ? format("%s", minCount) : format("%s-%s", minCount, maxCount)), n, sv, s));

            values ~= sv.parse!float;
            s.munch(" \t");
        }
        enforce(n >= minCount, format("not enough values (expected %s, got %s '%s')",
            format(minCount == maxCount ? format("%s", minCount) : format("%s-%s", minCount, maxCount)), n, s_start));
        return n;
    }

    string parseLine ( uint lineNum, string line ) {
        line = line.findSplitBefore("#")[0];
        if (line.length == 0)
            return "";

        if (line.length < 6) {
            onUnhandledLine( lineNum, line );
            return "";
        }

        auto s = line;
        if (s[0..2] == "v ") {
            s.munch("v \t");
            auto n = parseFloats( s, tempValues, 3, 4 );
            verts ~= vec4( tempValues[0], tempValues[1], tempValues[2], 1.0 );
            gen_normals ~= vec4(0.0);
            tempValues.length = 0;

            //import std.stdio;
            //writefln("vertex! %s", verts[$-1]);

        } else if (s[0..3] == "vn ") {
            s.munch("vn \t");
            auto n = parseFloats( s, tempValues, 3, 3);
            normals ~= vec3( tempValues[0], tempValues[1], tempValues[2] );
            tempValues.length = 0;

            //import std.stdio;
            //writefln("normal! %s", normals[$-1]);

        } else if (s[0..3] == "vt ") {
            s.munch("vt \t");
            auto n = parseFloats( s, tempValues, 2, 3 );
            uvs ~= vec2( tempValues[0], tempValues[1] );
            tempValues.length = 0;

            //import std.stdio;
            //writefln("uv! %s", uvs[$-1]);

        } else if (s[0] == 'f') {
            s = s[1..$]; s.munch(" \t");
            parseTri(s);

        } else if (s[0..6] == "mtllib") {
            //import std.stdio;
            //writefln("mtllib! '%s'  ", s[6..$].strip);
            onMtlLib(s[6..$].strip);
    
        } else if (s[0..6] == "usemtl") {
            //import std.stdio;
            //writefln("mtl! '%s'", s[6..$].strip);
            changeMtl( s[6..$].strip );

        } else {
            onUnhandledLine( lineNum, line );
        }
        return s;
    }
    uint lineNum = 0;
    foreach (line; fileContents.splitLines) {
        try {
            parseLine(lineNum, line);
        } catch (Exception e) {
            onParseError( e.msg, lineNum, line );
        }
        ++lineNum;
    }
    changeMtl(null);
}

