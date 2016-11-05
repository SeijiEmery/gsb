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

public interface ObjLoaderDelegate {
    void onTriangle (SbObj_Triangle);
    void onMtl      (string name, size_t triCount);
    void onMtlLib   (string libName);
    void onGroup    (string group);
    void onObject   (string object);
    void onUnhandledLine (uint lineNum, string line);
    void onParseError    (string msg, uint lineNum, string line);
}

// Helper method: try parsing a signed integer, advancing s and returning true iff parsed; false otherwise.
private bool tryParseInt (ref string s, ref int v) {
    auto sv = s.munch("-0123456789");
    if (sv.length)
        return v = sv.parse!int, true;
    return false;
}

// Helper method: parse a whitespace-delimited sequence of floats into values, advancing s.
// Throws an exception if the number of parsed values is not within [minCount, maxCount];
// otherwise, returns the number of values parsed.
private uint parseFloats (ref string s, ref float[] values, uint minCount, uint maxCount) {
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


void sbLoadObj ( 
    string fileContents,
    ObjLoaderDelegate dg,
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
    string prevMtl = "<none>";

    void emitTris () {
        if (verts.length * 3 != normals.length * 4) {
            foreach (ref n; gen_normals) {
                n.xyz /= n.w;
            }
        }
        if (intermedTris.length && !uvs.length)
            uvs ~= vec2(0, 0);

        foreach (ref tri; intermedTris) {
            dg.onTriangle(SbObj_Triangle([
                SbObj_TriVert( verts[tri.v0], tri.hasNormals ? normals[tri.n0] : gen_normals[tri.v0].xyz, uvs[tri.t0] ),
                SbObj_TriVert( verts[tri.v1], tri.hasNormals ? normals[tri.n1] : gen_normals[tri.v1].xyz, uvs[tri.t1] ),
                SbObj_TriVert( verts[tri.v2], tri.hasNormals ? normals[tri.n2] : gen_normals[tri.v2].xyz, uvs[tri.t2] ),
            ]));
        }
    }

    void changeMtl ( string name ) {
        if (prevMtl && intermedTris.length) {
            dg.onMtl( prevMtl, intermedTris.length );
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

    

    string parseLine ( uint lineNum, string line ) {
        line = line.findSplitBefore("#")[0];
        if (line.length == 0)
            return "";

        if (line.length < 6) {
            dg.onUnhandledLine( lineNum, line );
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
            dg.onMtlLib(s[6..$].strip);

        } else if (s[0..2] == "g ") {
            dg.onGroup(s[2..$].strip);
        
        } else if (s[0..2] == "o ") {
            dg.onObject(s[2..$].strip);
    
        } else if (s[0..6] == "usemtl") {
            //import std.stdio;
            //writefln("mtl! '%s'", s[6..$].strip);
            changeMtl( s[6..$].strip );

        } else {
            dg.onUnhandledLine( lineNum, line );
        }
        return s;
    }
    uint lineNum = 0;
    foreach (line; fileContents.splitLines) {
        try {
            parseLine(lineNum, line);
        } catch (Exception e) {
            dg.onParseError( e.msg, lineNum, line );
        }
        ++lineNum;
    }
    changeMtl(null);
}

enum MtlTextureChannel : uint {
    R = 0x1, G = 0x2, B = 0x4,
    M = 0x8, L = 0x10, Z = 0x20,
}
enum MtlReflectionMapType : uint {
    NONE = 0, SPHERE, CUBE_TOP, CUBE_BOTTOM, CUBE_FRONT, CUBE_BACK, CUBE_LEFT, CUBE_RIGHT
}

struct MtlTextureInfo {
    string path;
    uint   channels;  // see MtlTextureChannel

    auto   origin = vec3(0,0,0);
    auto   scale  = vec3(1,1,1);
    auto   turbulence = vec3(0,0,0);
    auto   mapType = MtlReflectionMapType.NONE;
}

public interface MtlLoaderDelegate {
    void onNewMtl        (string name);
    void onUnhandledLine (uint lineNum, string line);
    void onParseError    (string msg, uint lineNum, string line);

    //
    // default params (standardized, so 'd' <=> 'Tr', 'bump' <=> 'norm', etc)
    //

    // ambient
    void Ka     (vec3 color);
    void Ka_map (MtlTextureInfo);

    // diffuse
    void Kd     (vec3 color);
    void Kd_map (MtlTextureInfo);

    // specular
    void Ks     (vec3 color);
    void Ks_map (MtlTextureInfo);

    // shininess (specular)
    void Ns     (float shininess);
    void Ns_map (MtlTextureInfo);

    // transparency (note: for our purposes this is actually _opacity_ w/ 1.0 => fully opaque, 0.0 => transparent)
    void Tr     (float transparency);
    void Tr_map (MtlTextureInfo);

    // normal, displacement, stencil maps
    void bump_map (MtlTextureInfo);
    void disp_map (MtlTextureInfo);
    void decal_map (MtlTextureInfo);
    void refl_map (MtlTextureInfo);

    // can probably ignore this...
    void illum_model (uint);

    //
    // stuff used by raytracers (can safely ignore this)
    //

    // refraction index
    void Ni     (float refraction_index);
    void Ni_map (MtlTextureInfo);

    // transmission filter
    void Tf     (vec3 transmission_filter);
    void Tf_map (MtlTextureInfo);


    //
    // PBR (http://exocortex.com/blog/extending_wavefront_mtl_to_support_pbr)
    //

    // roughness
    void Pr     (float);
    void Pr_map (MtlTextureInfo);

    // metallic
    void Pm     (float);
    void Pm_map (MtlTextureInfo);

    // sheen
    void Ps     (float);
    void Ps_map (MtlTextureInfo);

    // clearcoat thickness, roughness
    void Pc     (float);
    void Pcr    (float);

    // emissive
    void Ke     (vec3 color);
    void Ke_map (MtlTextureInfo);

    // anisotropy, rotation
    void aniso  (vec3);
    void anisor (vec3);
}
void sbLoadMtl (string fileContents, MtlLoaderDelegate dg) {
    float[] tempValues;

    MtlTextureInfo parseTexture (string s) {
        return MtlTextureInfo(s.strip);
    }
    vec3 parseVec3 (string s) {
        tempValues.length = 0;
        s = s.strip;
        parseFloats(s, tempValues, 3, 3);
        enforce(!s.length, format("extra chars while parsing float3: '%s'", s));
        return vec3(tempValues[0], tempValues[1], tempValues[2]);
    }
    float parseFloat (string s) {
        tempValues.length = 0;
        s = s.strip;
        parseFloats(s, tempValues, 1, 1);
        enforce(!s.length, format("exta chars while parsing float: '%s'", s));
        return tempValues[0];
    }
    void parseLine (uint lineNum, string line) {
        if (line.length > 7 && line[0..4] == "map_") {
            switch (line[4..7]) {
                case "Ka ": dg.Ka_map(parseTexture(line[7..$])); return;
                case "Kd ": dg.Kd_map(parseTexture(line[7..$])); return;
                case "Ks ": dg.Ks_map(parseTexture(line[7..$])); return;
                case "Ns ": dg.Ns_map(parseTexture(line[7..$])); return;
                case "Ni ": dg.Ns_map(parseTexture(line[7..$])); return;
                case "Tf ": dg.Tf_map(parseTexture(line[7..$])); return;
                case "Tr ": dg.Tr_map(parseTexture(line[7..$])); return;
                case "Pr ": dg.Pr_map(parseTexture(line[7..$])); return;
                case "Pm ": dg.Pm_map(parseTexture(line[7..$])); return;
                case "Ps ": dg.Ps_map(parseTexture(line[7..$])); return;
                case "Ke ": dg.Ke_map(parseTexture(line[7..$])); return;
                default:
            }
            if (line[4..6] == "d ") { dg.Tr_map(parseTexture(line[7..$])); return; }
            else if (line.length > 10) {
                if (line[4..9] == "bump ") { dg.bump_map(parseTexture(line[9..$])); return; }
                if (line[4..9] == "norm ") { dg.bump_map(parseTexture(line[9..$])); return; }
                if (line[4..9] == "disp ") { dg.disp_map(parseTexture(line[9..$])); return; }
                if (line[4..9] == "refl ") { dg.refl_map(parseTexture(line[9..$])); return; }
                if (line[4..10] == "decal ") { dg.decal_map(parseTexture(line[10..$])); return; }
            }
        }

        else if (line.length >= 3 && (line[0] == 'K' || line[0] == 'P' || line[0] == 'T' || line[0] == 'N')) {
            switch(line[0..3]) {
                case "Ka ": dg.Ka(parseVec3(line[3..$])); return;
                case "Kd ": dg.Kd(parseVec3(line[3..$])); return;
                case "Ks ": dg.Ks(parseVec3(line[3..$])); return;
                case "Ns ": dg.Ns(parseFloat(line[3..$])); return;
                case "Ni ": dg.Ns(parseFloat(line[3..$])); return;
                case "Tf ": dg.Tf(parseVec3(line[3..$])); return;
                case "Tr ": dg.Tr(1.0 - parseFloat(line[3..$])); return;
                case "Pr ": dg.Pr(parseFloat(line[3..$])); return;
                case "Pm ": dg.Pm(parseFloat(line[3..$])); return;
                case "Ps ": dg.Ps(parseFloat(line[3..$])); return;
                case "Pc ": dg.Pc(parseFloat(line[3..$])); return;
                case "Pcr": if (line[4] == ' ') { dg.Pcr(parseFloat(line[4..$])); return; } else break;
                case "Ke ": dg.Ke(parseVec3(line[3..$])); return;
                default:
            }
        }

        else {
            if (line.length >= 7) {
                if (line[0..7] == "newmtl ") { dg.onNewMtl(line[7..$].strip); return;}
                if (line[0..5] == "bump ") { dg.bump_map(parseTexture(line[5..$])); return; }
                if (line[0..5] == "norm ") { dg.bump_map(parseTexture(line[5..$])); return; }
                if (line[0..5] == "disp ") { dg.disp_map(parseTexture(line[5..$])); return; }
                if (line[0..5] == "refl ") { dg.refl_map(parseTexture(line[5..$])); return; }
                if (line[0..6] == "decal ") { dg.decal_map(parseTexture(line[6..$])); return; }
                if (line[0..6] == "illum ") {
                    line = line[6..$];
                    dg.illum_model(line.parse!uint);
                    return;
                }
            }
            if (line.length >= 2 && line[0..2] == "d ") {
                dg.Tr(parseFloat(line[2..$])); return;
            }
        }
        dg.onUnhandledLine(lineNum, line);
    }

    uint lineNum = 0;
    foreach (line; fileContents.splitLines) {
        line = line.findSplitBefore("#")[0].strip;
        if (line.length) {
            try {
                parseLine(lineNum, line);
            } catch (Exception e) {
                dg.onParseError( e.msg, lineNum, line );
            }
        }
        ++lineNum;
    }
}










