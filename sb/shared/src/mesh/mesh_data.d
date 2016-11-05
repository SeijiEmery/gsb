module sb.mesh.mesh_data;
import gl3n.linalg;
import std.typecons;

class SbModelData {
    string name;
    SbMeshData[] meshes;

    this (string name) {
        this.name = name;
    }

    auto getMesh (string name) {
        foreach (mesh; meshes) {
            if (mesh.name == name)
                return mesh;
        }
        auto mesh = new SbMeshData(name);
        meshes ~= mesh;
        return mesh;
    }
}

enum SbVertexFormat {
    INTERLEAVED_V3_N3_T2
}
class SbMeshData {
    string   name;
    //ushort[] indices;
    //vec3[]   vertices;
    //vec2[]   uvs;
    //vec3[]   normals;
    float[]  packedData;
    SbVertexFormat dataFormat;

    this (string name) { this.name = name; }
}
class SbSubMesh {}

SbModelData sbLoadObjFile ( string path, SbModelData model = null ) {
    import std.stdio;
    import std.file;
    import std.exception;
    import std.format;
    import std.conv: parse;
    import std.string;
    enforce(exists(path), format("File does not exist: '%s'", path));

    if (!model) model = new SbModelData( path );
    auto mesh = model.getMesh("root");
    try {
        writefln("Loading '%s'", path);
        string start_line;

        auto parsef ( ref string s, string skip = " \t" ) {
            s.munch(skip);
            auto r = s.munch("-0123456789.");
            return r.parse!float;
        }

        // Store data in temporaries, then write in batch to:
        // - fixup varying indices (wavefront allows verts to have different indices than normals; we do not)
        // - sanity check indices (bounds checks, etc)
        // - pack data into our own data structures, split large meshes into multiple parts, etc
        vec3[] vertices, normals; vec2[] uvs;
        Tuple!(uint, uint, uint)[] tris;
        bool hasVaryingIndices = false;

        void writeMesh () {
            mesh.dataFormat = SbVertexFormat.INTERLEAVED_V3_N3_T2;
            foreach (elem; tris) {
                enforce( elem[0] < vertices.length, format("Vertex range violation: %s (%s)", elem[0], vertices.length ));
                enforce( elem[1] < normals.length,  format("Normal range violation: %s (%s)", elem[1], normals.length));
                enforce( elem[2] < uvs.length, format("UV range violation: %s (%s)", elem[2], uvs.length));
                vec3 v = vertices[elem[0]];
                vec3 n = normals[elem[1]];
                vec2 t = uvs[elem[2]];
                mesh.packedData ~= [ v.x, v.y, v.z, n.x, n.y, n.t, t.x, t.y ];
                writefln("Interleaved: %s, %s, %s", v, n, t);
            }
        }

        // temporaries
        int[4] v_indices, vn_indices, vt_indices;

        foreach (line; path.readText.splitLines) {
            if (line.length <= 2 || line[0] == '#')
                continue;

            try {
                start_line = line[0..$];
                switch (line[0..2]) {
                    case "v ": {
                        vertices ~= vec3( 
                            parsef(line, " \tv"),
                            parsef(line),
                            parsef(line),
                        );
                        //writefln("Vertex %s '%s'", mesh.vertices[$-1], start_line);
                    } break;
                    case "vt": {
                        uvs ~= vec2( parsef(line, " \tvt"), parsef(line) ); 
                        //writefln("Vertex UV: %s '%s'", mesh.uvs[$-1], start_line);
                    } break;
                    case "vn": {
                        normals ~= vec3( parsef(line, " \tvn"), parsef(line), parsef(line)); 
                        //writefln("Vertex Normal: %s '%s'", mesh.normals[$-1], start_line);
                    } break;
                    case "f ": {
                        line.munch("f \t");
                        uint i = 0;
                        while (line.length) {
                            v_indices[i] = parse!int( line );
                            if (line.munch("/").length) {
                                vn_indices[i] = parse!int( line );
                                if (line.munch("/").length)
                                    vt_indices[i] = parse!int( line );
                                else
                                    vt_indices[i] = v_indices[i];
                            } else {
                                vt_indices[i] = vn_indices[i] = v_indices[i];
                            }
                            line.munch(" \t");
                            enforce(++i <= 4, format("Invalid: > 4 indices (not tri / quad) '%s' here: '%s'", start_line, line));
                        }
                        enforce( i == 3 || i == 4, format("Invalid # of index pairs: %s in '%s'", i, start_line ));
                        enforce( i != 4, format("Quads unsupported: '%s'", start_line));
                        foreach (k; 0 .. 3 ) {
                            auto v = v_indices[k], n = vn_indices[k], t = vt_indices[k];
                            hasVaryingIndices = hasVaryingIndices || v != n || v != t;
                            if ( v < 0 ) v = cast(int)(vertices.length - v);
                            if ( n < 0 ) n = cast(int)(normals.length  - n);
                            if ( t < 0 ) t = cast(int)(uvs.length - t);
                            tris ~= tuple( cast(uint)v, cast(uint)n, cast(uint)t );
                        }
                    } break;
                    case "g ": {
                        auto newMesh = model.getMesh( line[2..$].strip );
                        if (newMesh != mesh) {
                            writeMesh();
                        }
                        mesh = newMesh;
                    } break;
                    default:
                        if (line.length >= 6 && line[0..6] == "usemtl") {

                        } else if (line.length >= 6 && line[0..6] == "mtllib") {

                        } else {
                            writefln("Unhandled line '%s'", line);
                        }
                }
            } catch (Exception e) {
                writefln("Failed to parse line '%s' '%s':\n%s", start_line, line, e);
            }
        }
        writeMesh();
        return model;
    } catch (Exception e) {
        throw new Exception(format("While parsing '%s': %s", path, e));
    }
}
