module sb.resource_loader.mesh_data;
//import gl3n.linalg;
import std.typecons;

struct vec2 { float x, y; }
struct vec3 { float x, y, z; }
struct vec4 { float x, y, z, w; static vec4 identity () { return vec4(0,0,0,1); } }
alias quat = vec4;

struct MeshImportSettings {
    auto origin = vec3(0);
    auto scale  = vec3(1);
    auto rotation = quat.identity;

    // Calculate centroid from vertex data?
    // If true, sets origin to centroid calculated by centroidMethod.
    //  NONE          => disabled; centroid is _not_ used for import origin
    //  RECALC_LINEAR => centroid calculated as linear-weighted average of all vertex positions
    //
    enum CentroidRecalc { NONE, RECALC_LINEAR }
    auto centroidMethod = CentroidRecalc.NONE;
    
    // If mesh does not have surface normals or forceNormalRecalc = true, 
    // recalculates normal + tangent information from vertex + tri/quad data 
    // using normalMethod:
    //     SMOOTH => smoothly interpolates shared vertex normals (default)
    //     FLAT   => normals are calculated per-primitive + not interpolated
    //
    enum NormalRecalc { SMOOTH, FLAT }
    auto normalMethod   = NormalRecalc.SMOOTH;
    bool forceNormalRecalc = false;
}

struct MeshImport {
    ImportObject[]   objects;
    Material[]       materials;
    TextureData[]    embeddedTextures;  // used by .fbx files that contain textures

    auto addObject (T, Args...)(Args args) if (__traits(compiles, new T(args))) {
        auto obj = new T(args);
        objects ~= obj;
        return obj;
    }
    auto getObject (T)(string name) {
        auto t = objectTypeOf!T;
        foreach (object; objects) {
            if (object.name == name && object.type == type) {
                return cast(T)object;
            }
        }
        return null;
    }

    Material* addMaterial (string name) {
        materials ~= Material(name);
        return &materials[$-1];
    }
    void addEmbeddedTextureData (string name, uint[] data) {
        embeddedTextures ~= Texture(name, data);
    }

    enum ObjectType { EMPTY, MESH, CAMERA, LIGHT }
    auto objectTypeOf (T)() {
        static if (is(T == ImportObject)) return ObjectType.EMPTY;
        static if (is(T == MeshObject))   return ObjectType.MESH;
        static if (is(T == CameraType))   return ObjectType.CAMERA;
        static if (is(T == LightType))    return ObjectType.LIGHT;
        static assert(0, format("Unsupported type: %s", T.classinfo));
    } 

    static class ImportObject {
        string name, parent = null;
        Transform transform;
        ObjectType type () { return ObjectType.EMPTY; }

        this (string name, string parent = null) {
            this.name = name; this.parent = parent;
        }
    }
    static struct Transform {
        vec3 pos, scale;
        quat rot;
    }
    static class MeshObject : ImportObject {
        override ObjectType type () { return ObjectType.MESH; }
        this (Args...)(Args args) { super(args); }

        uint materialIndex = 0;

        // Mesh attrib data
        vec3[] vertexData  = null;
        vec3[] normalData  = null;
        vec3[] tangentData = null;
        vec2[] uvData      = null;

        // Face indices in either tris _or_ quads.
        // faceCount = tris ? tris.length / 3 : quads ? quads.length / 4 : 0
        size_t faceCount = 0;
        uint[] tris = null;
        uint[] quads = null;
    }
    static enum CameraType { PERSPECTIVE, ORTHOGONAL }
    static class CameraObject : ImportObject {
        override ObjectType type () { return ObjectType.CAMERA; }
        this (Args...)(Args args, CameraType type) { super(args); this.type = type; }
        
        CameraType cameraType;
    }
    static enum LightType { POINT, DIRECTIONAL, SPOT }
    static class LightObject : ImportObject {
        override ObjectType type () { return ObjectType.LIGHT; }
        this (Args...)(Args args, LightType type) { super(args); this.type = type; }

        LightType lightType;

        // RGB: color, A: intensity
        vec4 colorAndIntensity;
        float distance, angle;

        @property auto color () { return colorAndIntensity.xyz; }
        @property auto color (vec3 v) { return colorAndIntensity.xyz = v; }
        @property auto intensity () { return colorAndIntensity.w; }
        @property auto intensity (float v) { return colorAndIntensity.w = v; }
    }

    enum MaterialAttrib { 
        AMBIENT, DIFFUSE, SPECULAR, SHININESS, EMISSIVE, TRANSPARENCY 
    }
    enum TextureAttrib {
        DIFFUSE, SPECULAR, SHININESS, EMISSIVE, TRANSPARENCY,
        BUMP, NORMAL, 
        REFL_SPHERE, REFL_CUBE_TOP, REFL_CUBE_BTM,
        REFL_CUBE_LEFT, REFL_CUBE_RIGHT,
        REFL_CUBE_FRONT, REFL_CUBE_BACK
    }
    static struct Material {
        string name;

        // Base material properties: diffuse, emissive, shininess, etc.
        // Stored in a vec4, but only the first N components are used
        // (diffuse => .xyz, shininess => .x)
        Tuple!(MaterialAttrib, vec4)[] properties;

        // Texture properties.
        Tuple!(TextureAttrib, TextureInfo)[] textures;
    }
    static struct TextureInfo {
        string path;    // absolute path to texture
        uint channels;  // bitmap: r => 0x1, g => 0x2, b => 0x4, a => 0x8
    }

    // Internally stored textures (used by .fbx imports); 
    // will be decoded using stb_image
    static struct TextureData {
        string name;
        ubyte[] data;
    }
}
