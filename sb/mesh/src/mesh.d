module sb.mesh.mesh;
import sb.model_loaders.loadobj;
import gl3n.linalg;

alias SbVertexCoord  = vec3;
alias SbVertexNormal = 
alias SbTexCoord     = vec2;
struct SbPrimitive { size_t[4] indices; }

enum SbMeshPrimitiveType { TRIANGLES, QUADS }

struct SbMesh {
    SbVertexCoord  [] vertices = null;
    SbVertexNormal [] normals  = null;
    SbTexCoord     [] uvs      = null;
    SbPrimitive    [] prims    = null;
    SbMeshPrimitiveType primType;
}

void loadObj (SbMesh ref mesh, string fileContents) {

    mesh.vertices = [];
    mesh.normals  = [];
    mesh.uvs      = [];
    mesh.prims    = [];

    sbLoadObj(fileContents, new ObjLoaderDelegate {
        void onTriangle (SbObj_Triangle tri) {
            for (auto i = 0; i < 3; ++i) {
                mesh.vertices ~= tri.verts[i].v;
                mesh.normals  ~= tri.verts[i].n;
                mesh.uvs      ~= tri.verts[i].t;
            }
            auto n = mesh.vertices.length;
            mesh.prims ~= SbPrimitive(n - 3, n - 2, n - 1);
        },
    });
}






















