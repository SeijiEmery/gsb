import sb.platform;
import sb.gl;
import sb.events;
import sb.model_loaders.tk_objfile;
import sb.model_loaders.loadobj;
import sb.image_loaders.stb_imageloader;

import std.stdio;
import std.datetime: StopWatch;
import core.time;
import std.conv;
import gl3n.linalg;
import gl3n.math;
import std.exception: enforce;
import std.format;
import std.path: baseName;
import std.algorithm: endsWith, move, any;
import std.string: fromStringz;
import core.sync.mutex;
import std.file;
import std.path;
import std.array;

immutable string ASSET_PACK_PATH = "./assets/models.zip";
immutable string[] ASSET_PRELOAD_EXTS = [ ".obj", ".zip", ".jpg" ];
auto ASSET_PATHS () {
    return [
        "cube.obj":         "cube/cube.obj",
        "teapot.obj":       "teapot/teapot.obj",
        "dragon.obj":       "dragon/dragon.obj.zip",
        "sibenik.obj":      "sibenik/sibenik.obj",
        "lost_empire.obj":  "lost-empire/lost_empire.obj",
    ];
}

class ArchivedAssetLoader {
    import std.file;
    import std.zip;
    import std.parallelism;

    Mutex           mutex;
    ZipArchive      archive;
    ubyte[][string] cachedFiles;
    string[string]  assetPaths;

    public static void loadAll (ArchivedAssetLoader loader, string archivePath) {
        synchronized (loader.mutex) {
            StopWatch sw; sw.start();
            loader.archive = new ZipArchive(read(archivePath));
            writefln("Preloaded asset pack '%s' in ", sw.peek.to!Duration);
        }
        foreach (ArchiveMember member; taskPool.parallel(loader.archive.directory.byValue)) {
            auto ext = member.name.extension;
            foreach (v; ASSET_PRELOAD_EXTS) {
                if (ext == v) {
                    writefln("Preloading asset '%s'", member.name);
                    loader.load(member.name);
                    break;
                }
            }
        }
    }

    this (string archivePath, string[string] assetPaths, ThreadManager manager) {
        enforce(exists(archivePath), format("Could not load asset pack '%s' (does not exist)", archivePath));
        this.assetPaths = assetPaths;
        this.archive = null;
        this.mutex   = new Mutex();
        taskPool.put(task!loadAll(this, archivePath));
    }
    ubyte[] load (string path) {
        string originalAssetPath = path;
        if (path in assetPaths)
            path = assetPaths[path];

        bool assetExists = false;
        synchronized {
            if (path in cachedFiles)
                return cachedFiles[path];
            assetExists = cast(bool)(path in archive.directory);
        }
        enforce(assetExists, format("Asset path '%s' does not exist!", path));

        StopWatch sw; sw.start();
        ubyte[] data = archive.expand(archive.directory[path]);
        while (path.endsWith(".zip")) {
            auto a2 = new ZipArchive(data);
            auto innerPath = baseName(path, ".zip");
            enforce(innerPath in a2.directory, 
                format("Could not unpack file: zipped asset '%s' does not contain '%s'!", path, innerPath));
            path = innerPath;
            data = a2.expand(a2.directory[innerPath]);
        }
        sw.stop();

        synchronized {
            if (path !in cachedFiles) {
                writefln("Loaded / unpacked '%s' in %s", originalAssetPath, sw.peek.to!Duration);
                return cachedFiles[path] = data;
            }
            return cachedFiles[path];
        }
    }
}

auto readFile (string path) {
    import std.file;

    enforce(exists(path), format("File does not exist: '%s'", path));
    return read(path);
}
auto readArchive (string path, string file) {
    import std.file;
    import std.zip;

    enforce(exists(path), format("File does not exist: '%s'", path));
    auto archive = new ZipArchive(read(path));
    enforce(file in archive.directory, 
        format("Archive '%s' does not contain file '%s'", path, file));
    return archive.expand(archive.directory[file]);
}
class RawModelData {
    static class SubMesh {
        string   name;
        size_t   triCount;
        float[]  packedData;
        Material material;

        this (string name, size_t triCount) { 
            this.name = name; 
            this.triCount = triCount;
        }
    }
    auto centroid = vec3(0, 0, 0);
    SubMesh[]        meshes;

    auto addMesh ( string name, size_t triCount ) { 
        auto mesh = new SubMesh(name, triCount);
        meshes ~= mesh;
        return mesh;
    }
    auto getMesh (string name, size_t triCount) {
        foreach (mesh; meshes) {
            if (mesh.name == name) {
                mesh.triCount += triCount;
                return mesh;
            }
        }
        return addMesh(name, triCount);
    }
}
struct Material {
    auto ambient  = vec3(0.0);
    auto diffuse  = vec3(0.5);
    auto specular = vec3(1.0);
    float shininess = 1.0;
    auto emissiveness = vec3(0.0);
    float opacity = 1.0;

    string diffuse_map  = null;
    string normal_map   = null;
    string specular_map = null;
    string emissive_map = null;
    string disp_map     = null;
}

RawModelData loadObj (string path, string obj_file_contents, RawModelData model = null) {
    if (!model)
        model = new RawModelData();
    RawModelData.SubMesh mesh = null;
    Exception exc = null;
    vec3 center; size_t vertCount;

    import std.path;
    Material[string] materials;
    auto objName = path.baseName;
    auto basePath = path.dirName;

    void loadMtlLib (string name) {
        void loadMaterials ( ubyte[] contents ) {
            string currentMtl = "";
            materials[currentMtl] = Material.init;

            void setTexture (out string texture, ref MtlTextureInfo info) {
                texture = cast(string)basePath.chainPath(info.path).array;
            }
            sbLoadMtl(cast(string)contents, new class MtlLoaderDelegate {
                override void onNewMtl (string name) {
                    if (name !in materials)
                        materials[name] = Material.init;
                    currentMtl = name; 
                }
                override void onUnhandledLine (uint lineNum, string line) {
                    writefln("Unhandled: %s, line %s '%s'", name, lineNum, line);
                }
                override void onParseError (string msg, uint lineNum, string line) {
                    writefln("Error parsing file %s, line %s: %s (line '%s')", name, lineNum, msg, line);
                }

                // useful stuff
                override void Ka (vec3 color) { materials[currentMtl].ambient = color; }
                override void Kd (vec3 color) { materials[currentMtl].diffuse = color; }
                override void Ks (vec3 color) { materials[currentMtl].specular = color; }
                override void Ns (float s)    { materials[currentMtl].shininess = s * 20; }
                override void Ke (vec3 color) { materials[currentMtl].emissiveness = color; }
                override void Tr (float opacity) { materials[currentMtl].opacity = opacity; }

                override void Ka_map (MtlTextureInfo info) {}
                override void Kd_map (MtlTextureInfo info) { setTexture(materials[currentMtl].diffuse_map, info); }
                override void Ks_map (MtlTextureInfo info) { setTexture(materials[currentMtl].specular_map, info); }
                override void Ke_map (MtlTextureInfo info) { setTexture(materials[currentMtl].emissive_map, info); }
                override void bump_map (MtlTextureInfo info) { setTexture(materials[currentMtl].normal_map, info); }
                override void disp_map (MtlTextureInfo info) { setTexture(materials[currentMtl].disp_map, info); }

                override void Ns_map (MtlTextureInfo info) {
                    writefln("unused shininess map: %s", info);
                }
                override void refl_map (MtlTextureInfo info) {
                    writefln("unused reflective map: %s", info);
                }

                // unused (as of yet)
                override void Tr_map (MtlTextureInfo info) {}

                // unused maps
                override void decal_map (MtlTextureInfo info) {}

                // unused PBR params
                override void Pr (float roughness) {}
                override void Pm (float metallicness) {}
                override void Ps (float sheen) {}
                override void Pc (float clearcoat) {}
                override void Pcr (float clearcoat_roughness) {}

                override void Pr_map (MtlTextureInfo info) {}
                override void Pm_map (MtlTextureInfo info) {}
                override void Ps_map (MtlTextureInfo info) {}

                override void aniso (vec3 v) {}
                override void anisor (vec3 v) {}

                // unused raytracer params
                override void Ni (float refraction) {}
                override void Tf (vec3 transmission_filter) {}
                override void Ni_map (MtlTextureInfo info) {}
                override void Tf_map (MtlTextureInfo info) {}

                // unused illum model
                override void illum_model (uint model) {}
            });
        }

        import std.file;
        import std.path;
        import std.array;
        auto localPath = path.dirName.chainPath(name).array;

        if (exists(localPath)) loadMaterials(cast(ubyte[])read(localPath));
        else if (exists(name)) loadMaterials(cast(ubyte[])read(name));
        else                   writefln("Could not load mtllib '%s'", name);
    }

    sbLoadObj(obj_file_contents, new class ObjLoaderDelegate {
        void onTriangle (SbObj_Triangle tri) {
            //assert( mesh, "Null mesh!" );
            foreach (ref vert; tri.verts) {
                mesh.packedData ~= [ vert.v.x, vert.v.y, vert.v.z, vert.t.x, vert.t.y, vert.n.x, vert.n.y, vert.n.z ];
                center += vert.v.xyz;
                ++vertCount;
            }
        }
        void onMtl (string mtlName, size_t triCount) {
            mesh = model.getMesh( mtlName, triCount );
            if (mtlName !in materials) {
                writefln("No material for '%s'", mtlName);
            } else {
                mesh.material = materials[mtlName];
            }
        }
        void onMtlLib (string mtlLibName) {
            loadMtlLib(mtlLibName);
        }
        void onGroup (string name) {}
        void onObject (string name) {}

        void onUnhandledLine (uint lineNum, string line) {
            writefln("Unhandled: line %s '%s'", lineNum, line);
        }
        void onParseError (string msg, uint lineNum, string line) {
            writefln("Error parsing file: %s (line %s, '%s')", msg, lineNum, line);
        }
    });

    //double cx = 0, cy = 0, cz = 0;// size_t vertCount = 0;
    //tkParseObj( obj_file_contents,
    //    (const(char)* mtlName, size_t triCount) {
    //        mesh = model.addMesh( mtlName.fromStringz.dup, triCount );
    //    },
    //    (TK_Triangle tri) {
    //        assert( mesh, "Null mesh!" );
    //        void writev ( TK_TriangleVert v, ref float[] packedData ) {
    //            cx += v.pos[0]; cy += v.pos[1]; cz += v.pos[2]; ++vertCount;
    //            packedData ~= [ v.pos[0], v.pos[1], v.pos[2], v.st[0], v.st[1], v.nrm[0], v.nrm[1], v.nrm[2] ];
    //        }

    //        // naive impl; probably wrong
    //        if (genNormals) {
    //            vec3 normal = -cross(
    //                vec3(tri.vertA.pos[0] - tri.vertB.pos[0],
    //                     tri.vertA.pos[1] - tri.vertB.pos[1],
    //                     tri.vertA.pos[2] - tri.vertB.pos[2]),
    //                vec3(tri.vertC.pos[0] - tri.vertB.pos[0],
    //                     tri.vertC.pos[1] - tri.vertB.pos[1],
    //                     tri.vertC.pos[2] - tri.vertB.pos[2]));
    //            tri.vertA.nrm[0] = tri.vertB.nrm[0] = tri.vertC.nrm[0] = normal.x;
    //            tri.vertA.nrm[1] = tri.vertB.nrm[1] = tri.vertC.nrm[1] = normal.y;
    //            tri.vertA.nrm[2] = tri.vertB.nrm[2] = tri.vertC.nrm[2] = normal.z;
    //        }

    //        writev( tri.vertA, mesh.packedData );
    //        writev( tri.vertB, mesh.packedData );
    //        writev( tri.vertC, mesh.packedData );
    //    },
    //    (ref TK_ObjDelegate _) {
    //        writefln("Finished reading obj file");
    //    },
    //    (ref TK_ObjDelegate obj, string error) {
    //        exc = new Exception(format("Error reading obj file:\n\t%s\n%s", obj, error));
    //    }
    //);
    if (exc) throw exc;

    //if (!vertCount) vertCount = 1;
    //model.centroid += center / cast(float)vertCount;
    return model;
}

struct RenderableMeshPart {
    string name;
    static struct RenderItem {
        GLVaoRef vao;
        GLPrimitive primitive;
        size_t start, count;
    }
    RenderItem[] renderItems;
    GLVboRef[]   vbos;
    Material     material;

    void render () {
        foreach (ref item; renderItems) {
            item.vao.drawArrays( item.primitive, cast(uint)item.start, cast(uint)item.count );
        }
    }
    // Generate from mesh part data
    this ( RawModelData.SubMesh mesh, GLShaderRef shader, IGraphicsContext gl, GLResourcePoolRef resourcePool ) {
        this.name = mesh.name;
        this.material = mesh.material;

        void genTris ( float[] packedData_v3_s2_n3, size_t count ) {
            auto vbo = resourcePool.createVBO();
            gl.getLocalBatch.execGL({ bufferData(vbo, packedData_v3_s2_n3, GLBufferUsage.GL_STATIC_DRAW); });

            auto vao = resourcePool.createVAO();
            vao.bindVertexAttrib( 0, vbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, float.sizeof * 8, 0 );
            vao.bindVertexAttrib( 1, vbo, 2, GLType.GL_FLOAT, GLNormalized.FALSE, float.sizeof * 8, float.sizeof * 3 );
            vao.bindVertexAttrib( 2, vbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, float.sizeof * 8, float.sizeof * 5 );
            vao.bindShader( shader );

            renderItems ~= RenderItem( vao, GLPrimitive.GL_TRIANGLES, 0, count * 3 );
        }
        genTris( mesh.packedData, mesh.triCount );
    }
}
struct RenderableMesh {
    mat4 transform;
    RenderableMeshPart[] parts;

    this ( 
        RawModelData model, GLShaderRef shader, IGraphicsContext gl, GLResourcePoolRef resourcePool,
        vec3 pos, vec3 scale, quat rot
    ) {
        this.transform =
            mat4.translation( pos - model.centroid) *
            mat4.scaling( scale.x, scale.y, scale.z ) *
            rot.to_matrix!(4,4);

        foreach (mesh; model.meshes) {
            parts ~= RenderableMeshPart( mesh, shader, gl, resourcePool );
        }
    }
}

class ThreadManager {
    Mutex mtTaskMutex;
    void delegate()[] mtTaskQueue;

    this () { mtTaskMutex = new Mutex(); }
    void runAsync (void delegate() task) {
        import core.thread;
        void runTask () {
            try {
                task();
            } catch (Throwable e) {
                writefln("%s", e);
            }
        }
        new Thread(&runTask).start();
    }
    void runOnMainThread (void delegate() task) {
        synchronized (mtTaskMutex) {
            mtTaskQueue ~= task;
        }
    }
    void runMainThreadTasks () {
        if (mtTaskQueue.length) {
            synchronized (mtTaskMutex) {
                foreach (task; mtTaskQueue) {
                    try {
                        task();
                    } catch (Throwable e) {
                        writefln("%s", e);
                    }
                }
                mtTaskQueue.length = 0;
            }
        }
    }
}

enum TextureSlot   { DIFFUSE, NORMAL }
enum TextureStatus { NOT_LOADED, LOADED, LOAD_ERROR }

struct TextureManager {
    ThreadManager        threading;
    GLResourcePoolRef    resourcePool;
    GLTextureRef[string] textures;
    TextureStatus[string] textureStatus;

    GLTextureRef[TextureSlot.max+1] defaultTextures;
    private uint numDefaultTexturesLoaded = 0;

    string[TextureSlot.max+1] lastBoundTexture = null;
    bool  [TextureSlot.max+1] isDefault = false;

    this (ThreadManager threadManager, GLResourcePoolRef resourcePool) {
        this.threading = threadManager;
        this.resourcePool = resourcePool;
        for (auto i = TextureSlot.max; i --> 0; ) {
            defaultTextures[i] = resourcePool.createTexture();
        }
    }
    @disable this(this);

    // Not implicitely threadsafe -- call this only from main thread!
    void loadTexture (string path, void delegate() postAction = null) {
        if (path !in textures) {
            textures[path] = resourcePool.createTexture();

            if (!path.exists) {
                writefln("Cannot load texture: '%s' does not exist", path);
                textureStatus[path] = TextureStatus.LOAD_ERROR;
                if (postAction) postAction();
                return;
            }
            textureStatus[path] = TextureStatus.NOT_LOADED;
            threading.runAsync({
                try {
                    auto texture = stb_loadImage(path, cast(ubyte[])read(path));
                    enforce( texture.data, "null data!" );
                    threading.runOnMainThread({
                        writefln("Loaded texture: '%s' | %s x %s, bit-depth %s",
                            path, texture.width, texture.height, texture.componentDepth);

                        TextureSrcFormat fmt;
                        switch (texture.componentDepth) {
                            case 1: fmt = TextureSrcFormat.RED; break;
                            case 3: fmt = TextureSrcFormat.RGB; break;
                            case 4: fmt = TextureSrcFormat.RGBA; break;
                            default: enforce(0, format("Unsupported texture component(s): %s", texture.componentDepth));
                        }
                        textures[path].fromBytes(texture.data, vec2i(cast(int)texture.width, cast(int)texture.height), fmt);

                        textureStatus[path] = TextureStatus.LOADED;
                        if (postAction) postAction();
                    });
                } catch (Exception e) {
                    writefln("Failed to load texture '%s':\n%s", path, e);
                    textureStatus[path] = TextureStatus.LOAD_ERROR;
                    if (postAction) threading.runOnMainThread(postAction);
                }
            });
        }
    }
    void loadDefaultTexture (TextureSlot slot, string path) {
        loadTexture(path, {
            enforce(textureStatus[path] == TextureStatus.LOADED,
                format("Could not load default %s texture '%s'! (texture status = %s)", 
                    slot, path, textureStatus[path]));

            assert(path in textures, format("%s, %s", path, textures));
            defaultTextures[slot] = textures[path];
            ++numDefaultTexturesLoaded;
        });
    }
    void bindTexture (string name, TextureSlot slot) {
        if (name != lastBoundTexture[slot]) {
            lastBoundTexture[slot] = name;

            if (name && name in textures) {
                //writefln("Binding %s = %s", slot, name);
                isDefault[slot] = false;
                textures[name].bindTo( cast(int)slot );
            
            } else if (!isDefault[slot]) {
                //writefln("Binding %s = default: %s", slot, defaultTextures[slot]);

                isDefault[slot] = true;
                defaultTextures[slot].bindTo( cast(int)slot );
            }
        }
    }
}


void main (string[] args) {
    auto threading = new ThreadManager();
    //auto assetLoader = new ArchivedAssetLoader(ASSET_PACK_PATH, ASSET_PATHS, threading);

    SbPlatformConfig platformConfig = {
        backend: SbPlatform_Backend.GLFW3,
        glVersion: SbPlatform_GLVersion.GL_410,
    };
    StopWatch initTime; initTime.start();

    auto platform = sbCreatePlatformContext(
        sbCreateGraphicsLib(GraphicsLibVersion.GL_410),
        platformConfig);
    try {
        platform.init();
        SbWindowConfig windowConfig = {
            title: "model viewer",
            size_x: 1200, size_y: 780,
            showFps: true,
        };
        auto window = platform.createWindow("main-window", windowConfig);

        platform.initGL();
        auto gl           = platform.getGraphicsContext();
        auto resourcePool = gl.createResourcePrefix("model-viewer");

        auto meshShader = resourcePool.createShader();
        meshShader.rawSource(GLShaderType.VERTEX, `
            #version 410
            layout(location=0) in vec3 vertPosition;
            layout(location=1) in vec2 vertUV;
            layout(location=2) in vec3 vertNormal;

            uniform mat4 modelViewMatrix;
            uniform mat3 normalMatrix;
            uniform mat4 mvp;

            out vec3 position;
            out vec3 normal;
            out vec2 uv;
            
            void main () {
                uv = vertUV;
                normal = normalize(normalMatrix * vertNormal);
                position = vec3(modelViewMatrix * vec4(vertPosition, 1.0));
                gl_Position = mvp * vec4(vertPosition, 1.0);
            }
        `);
        meshShader.rawSource(GLShaderType.FRAGMENT, `
            #version 410
            in vec3 position;
            in vec3 normal;
            in vec2 uv;

            struct LightInfo {
                vec4 position;
                vec3 intensity;
            };
            struct MaterialInfo {
                vec4 Ka;
                vec4 Kd;
                vec4 Ks;
                float shininess;
            };
            uniform LightInfo    light;
            uniform MaterialInfo material;

            uniform sampler2D Tex1;
            uniform sampler2D Tex2;

            layout(location=0) out vec4 fragColor;

            subroutine vec4 shadingModel ();
            subroutine uniform shadingModel activeShadingModel;

            void getLightValues (out vec3 n, out vec3 s, out vec3 v) {
                n = normalize(normal);
                v = normalize(vec3(-position));
                
                if (light.position.w == 0.0)
                    s = normalize(vec3(light.position.xyz));
                else
                    s = normalize(vec3(light.position.xyz - position));
            }

            subroutine (shadingModel)
            vec4 phongModel_noHalfwayVector () {
                vec3 n, s, v; getLightValues(n, s, v);
                vec3 r = reflect(-s, n);

                vec4 texColor = texture( Tex1, vec2(uv.x, 1-uv.y) );
                vec4 bump     = texture( Tex2, uv );

                vec4 diffuse  = material.Ka + material.Kd * max(dot(s, n), 0.0);
                vec4 specular = material.Ks * pow(max(dot(r, v), 0.0), material.shininess);

                return vec4(light.intensity, 1.0) * (diffuse * texColor.rgba + specular);
            }

            subroutine (shadingModel)
            vec4 phongModel_halfwayVector () {
                vec3 n, s, v; getLightValues(n, s, v);
                vec3 h = normalize(v + s);

                return vec4(light.intensity, 1.0) * (
                    material.Ka +
                    material.Kd * max(dot(s, n), 0.0) +
                    material.Ks * pow(max(dot(h, n), 0.0), material.shininess)
                );
            }

            subroutine (shadingModel)
            vec4 debug_normals () {
                return vec4(normalize(normal), 1.0);
            }

            subroutine (shadingModel)
            vec4 debug_tex0 () {
                return texture( Tex1, uv ).rgba;
            }
            subroutine (shadingModel)
            vec4 debug_tex1 () {
                return texture( Tex1, vec2(uv.x, 1 - uv.y) ).rgba;
            }
            subroutine (shadingModel)
            vec4 debug_lightDir () {
                vec3 n, s, v; getLightValues(n, s, v);
                return vec4(s, 1.0);
            }
            subroutine (shadingModel)
            vec4 debug_alpha () {
                return phongModel_noHalfwayVector().aaaa;
            }
            subroutine (shadingModel)
            vec4 debug_uvs () {
                return vec4(uv, 0, 1);
            }
            //subroutine (shadingModel)
            //vec3 uniformColor_red () {
            //    return vec3(1,0,0);
            //}
            void main () {
                fragColor = activeShadingModel();
            }
        `);
        auto gl_init_time = initTime.peek;

        struct LightInfo {
            vec3 pos = vec3(-25, 9, 0);
            vec3 intensity = vec3(1.0);
            bool isDirectional = false;
            //vec3 ambient = vec3(0.2);
            //vec3 diffuse = vec3(0.5);
            //vec3 specular = vec3(1.0);
        }
        struct MaterialInfo {
            vec3 ambient  = vec3(1e-6);
            vec3 diffuse  = vec3(1);
            vec3 specular = vec3(1);
            float shininess = 150;
        }
        struct CameraInfo {
            vec3 pos; mat4 view, proj;
        }
        auto g_light    = LightInfo();
        auto g_material = MaterialInfo();
        float g_lightIntensity = 1.0;
        bool  g_useHalfwayVector = true;

        float MIN_SHININESS = 1, MAX_SHININESS = 300,    SHININESS_CHANGE_RATE = 0.4;
        float MIN_INTENSITY = 0.1, MAX_INTENSITY = 10.0, INTENSITY_CHANGE_RATE = 0.2;

        enum LightingModel : uint {
            phongModel_halfwayVector,
            phongModel_noHalfwayVector,
            debug_normals,
            debug_lightDir,
            debug_tex0,
            debug_tex1,
            debug_uvs,
            debug_alpha,
            //uniformColor_red,
        }
        LightingModel g_lightModel;
        void setLightModel (LightingModel lightModel) {
            writefln("Set lighting model = %s", g_lightModel = lightModel);
            gl.getLocalBatch.execGL({
                meshShader.useSubroutine(GLShaderType.FRAGMENT, "activeShadingModel", lightModel.to!string);
            });
        }
        void advLightModel (uint dir) {
            setLightModel( cast(LightingModel)((g_lightModel + dir) % (LightingModel.max+1)) );
        }

        void setLight (ref CameraInfo camera, ref LightInfo light) {
            auto eye_pos = camera.view * vec4(light.pos, 1.0);
            auto light_pos = vec4(eye_pos.xyz + vec3(0,1,0), light.isDirectional ? 0.0 : 1.0);

            meshShader.setv("light.position",  light_pos);
            meshShader.setv("light.intensity", light.intensity);
            //meshShader.setv("useHalfwayVector", cast(int)g_useHalfwayVector);
            //meshShader.setv("light.La", light.ambient);
            //meshShader.setv("light.Ld", light.diffuse);
            //meshShader.setv("light.Ls", light.specular);
        }
        void setModel (ref mat4 model, ref CameraInfo camera, ref MaterialInfo material) {
            //meshShader.setv("material.Ka", material.ambient);
            //meshShader.setv("material.Kd", material.diffuse);
            //meshShader.setv("material.Ks", material.specular);
            //meshShader.setv("material.shininess", material.shininess);
            
            auto vp = camera.view * model;
            meshShader.setv("modelViewMatrix", vp);
            meshShader.setv("normalMatrix", mat3(vp).inverse.transposed);
            meshShader.setv("mvp", camera.proj * vp);
        }
        RenderableMesh[] meshes;
        GLResourcePoolRef[string] resourcePools;

        auto textureManager = TextureManager(threading, gl.createResourcePrefix("textures"));
        bool[string] uniqueTextures;

        textureManager.loadDefaultTexture( TextureSlot.DIFFUSE, "./assets/teapot/default.png" );
        textureManager.loadDefaultTexture( TextureSlot.NORMAL,  "./assets/teapot/default.png" );

        void asyncLoadMesh ( string path, vec3 pos, vec3 scale, quat rotation, bool useCentroid = true) {
            auto isZip = path.endsWith(".zip");
            auto fileName = isZip ? baseName(path, ".zip") : baseName(path);
            try {
                StopWatch sw; sw.start();
                auto contents = isZip ? readArchive(path, fileName) : readFile(path);
                auto modelData = loadObj(path, cast(string)contents, null);
                if (!useCentroid)
                    modelData.centroid = vec3(0, 0, 0);
                auto loadTime = sw.peek.to!Duration; sw.stop();

                // Assemble set of used textures
                bool[string] usedTextures;
                void insertTexturePath (string texture) {
                    if (texture) usedTextures[texture] = true;
                }
                foreach (mesh; modelData.meshes) {
                    insertTexturePath( mesh.material.diffuse_map );
                    insertTexturePath( mesh.material.specular_map );
                    insertTexturePath( mesh.material.normal_map );
                }

                threading.runOnMainThread({
                    writefln("Loaded '%s' in %s. %s parts:", fileName, loadTime, modelData.meshes.length);
                    foreach (mesh; modelData.meshes)
                        writefln("\t'%s' | %s tris", mesh.name, mesh.triCount);
                    writefln("\tcentroid: %s", modelData.centroid);
                    writeln("");

                    // And load textures (async operation)
                    foreach (texture; usedTextures.keys)
                        textureManager.loadTexture(texture);

                    auto pool = resourcePools[fileName] = gl.createResourcePrefix( fileName );
                    auto mesh = RenderableMesh(modelData, meshShader, gl, pool, pos, scale, rotation);
                    meshes ~= move(mesh);
                });
            } catch (Exception e) {
                writefln("Failed to load '%s':\n%s", fileName, e);
            }
        }
        void loadMesh (string path, vec3 pos, vec3 scale, quat rotation, bool useCentroid = true, bool genNormals = false) {
            threading.runAsync({
                writefln("Loading '%s'...", path);
                asyncLoadMesh(path, pos, scale, rotation, useCentroid);
            });
        }

        void drawMeshes ( CameraInfo camera, ref LightInfo light, ref MaterialInfo material ) {
            gl.getLocalBatch.execGL({
                setLight(camera, light);

                meshShader.setv("Tex1", cast(int)TextureSlot.DIFFUSE);
                //meshShader.setv("Tex2", cast(int)TextureSlot.NORMAL);

                foreach (ref mesh; meshes) {
                    setModel(mesh.transform, camera, material);
                    foreach (part; mesh.parts) {
                        meshShader.setv("material.Ka", vec4(part.material.ambient, part.material.opacity));
                        meshShader.setv("material.Kd", vec4(part.material.diffuse, part.material.opacity));
                        meshShader.setv("material.Ks", vec4(part.material.specular, part.material.opacity));
                        meshShader.setv("material.shininess", part.material.shininess);

                        textureManager.bindTexture( part.material.diffuse_map, TextureSlot.DIFFUSE );
                        //textureManager.bindTexture( part.material.normal_map,  TextureSlot.NORMAL  );

                        part.render();
                    }
                }
            });
        }

        loadMesh( "./assets/cube/cube.obj",
            vec3(5, 0, 0), vec3(1, 1, 1), quat.identity);
        loadMesh( "./assets/teapot/teapot.obj",
            vec3(0, 1, 0), vec3(0.025, 0.025, 0.025), quat.xrotation(PI), false, true);
        loadMesh( "./assets/dragon/dragon.obj.zip",
            vec3(-10, 0, 0), vec3(10), quat.zrotation(PI));
        loadMesh( "./assets/sibenik/sibenik.obj",
            vec3(-10, 0, 0), vec3(1, 1, 1), quat.xrotation(PI), true, true);
        loadMesh( "./assets/lost-empire/lost_empire.obj",
            vec3(100, 0, 0), vec3(1,1,1), quat.xrotation(PI), true, true);

        // The wierd-ass textures in this one do not make opengl happy :(
        //loadMesh( "./assets/dabrovic-sponza/sponza.obj",
        //    vec3(-100, 0, 0), vec3(1,1,1), quat.xrotation(PI));


        auto load_mesh_time = initTime.peek - gl_init_time;

        auto shader = resourcePool.createShader();
        shader.rawSource(GLShaderType.VERTEX, `
            #version 410
            layout(location=0) in vec3 vertPosition;
            layout(location=1) in vec3 vertColor;
            layout(location=2) in vec3 instancePosition;
            out vec3 color;

            uniform mat4 vp;
            uniform mat4 model;

            void main () {
                color = vertColor;
                gl_Position = vp * (
                    vec4(instancePosition, 0) +
                    model * vec4(vertPosition, 1.0));
            }
        `);
        shader.rawSource(GLShaderType.FRAGMENT, `
            #version 410
            in vec3 color;
            out vec4 fragColor;

            void main () {
                fragColor = vec4( color, 1.0 );
            }
        `);
        const float[] position_color_data = [
            -0.8f, -0.8f, 0.0f,  1.0f, 0.0f, 0.0f,
             0.8f, -0.8f, 0.0f,  0.0f, 1.0f, 0.0f,
             0.0f,  0.8f, 0.0f,  0.0f, 0.0f, 1.0f
        ];

        auto vao = resourcePool.createVAO();
        auto vbo = resourcePool.createVBO();
        auto instance_vbo = resourcePool.createVBO();

        immutable auto GRID_DIM   = vec3i( 100, 50, 100 );
        immutable auto GRID_SCALE =  vec3( 100, 50, 100 );

        vec3[] instanceGridData;
        foreach (x; 0f .. GRID_DIM.x) {
            foreach (y; 0f .. GRID_DIM.y) {
                foreach (z; 0f .. GRID_DIM.z) {
                    instanceGridData ~= vec3(
                        (x - GRID_DIM.x * 0.5) * GRID_SCALE.x / GRID_DIM.x * 2.0,
                        (y - GRID_DIM.y * 0.5) * GRID_SCALE.y / GRID_DIM.y * 2.0,
                        (z - GRID_DIM.z * 0.5) * GRID_SCALE.z / GRID_DIM.z * 2.0,
                    );
               }
            }
        }
        gl.getLocalBatch.execGL({
            bufferData( vbo, position_color_data, GLBufferUsage.GL_STATIC_DRAW );
            vao.bindVertexAttrib( 0, vbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, float.sizeof * 6, 0 );
            vao.bindVertexAttrib( 1, vbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, float.sizeof * 6, float.sizeof * 3 );

            bufferData( instance_vbo, instanceGridData, GLBufferUsage.GL_STATIC_DRAW );
            vao.bindVertexAttrib( 2, instance_vbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, 0, 0 );
            vao.setVertexAttribDivisor( 2, 1 );

            vao.bindShader( shader );
        });

        auto CAMERA_ORIGIN = vec3( -1, 0, 0 );
        auto CAMERA_START_ANGLES = vec3(0, 2*PI, 0);

        //auto CAMERA_ORIGIN = vec3( -20, 20, -1 );
        //auto CAMERA_START_ANGLES = vec3(0, PI, 0);

        auto cam_pos    = CAMERA_ORIGIN;
        auto cam_angles = CAMERA_START_ANGLES;
        auto CAM_LOOK_SPEED = 100.0.radians;
        auto CAM_MOVE_SPEED = 15.0;

        float MAX_FOV = 360.0, MIN_FOV = 0.5, FOV_CHANGE_SPEED = 120.0;
        float MIN_FAR = 10, MAX_FAR = 2e3, FAR_CHANGE_SPEED = 1e2;

        float fov = 60.0, near = 0.1, far = 1e3;
        bool drawTriArray = false; // draw instanced triangles

        // Finish loading everything (hopefully)
        threading.runMainThreadTasks();

        writefln("Loaded in   %s", initTime.peek.to!Duration);
        writefln("gl-init:    %s", gl_init_time.to!Duration);
        writefln("model load: %s", load_mesh_time.to!Duration);
        initTime.stop();

        StopWatch sw; sw.start();
        double prevTime = sw.peek.to!("seconds", double);
        while (!window.shouldClose) {
            auto time = sw.peek.to!("seconds", double);
            auto dt   = time - prevTime;
            prevTime  = time;
            window.setTitleFPS( 1.0 / dt );

            immutable auto PERIOD = 2.0;
            auto t = (time % PERIOD) / PERIOD * 2 * PI;

            platform.pollEvents();

            auto proj = mat4.perspective( 
                cast(float)window.windowSize.x, 
                cast(float)window.windowSize.y, 
                fov, near, far );

            import std.variant;

            auto fwd = vec3(
                cam_angles.x.cos * cam_angles.y.cos,
                cam_angles.x.sin,
                cam_angles.x.cos * cam_angles.y.sin
            );
            auto right = fwd.cross(vec3(0, 1, 0));
            auto up    = fwd.cross(right);

            auto input = platform.input;
            auto cam_move_axes = vec3(0,0,0);
            auto cam_look_axes = vec3(0,0,0);
            auto fov_delta = 0.0f;

            auto wasd_axes = vec3(0, 0, 0);
            if (input.keys[SbKey.KEY_A].down || input.keys[SbKey.KEY_LEFT].down)  cam_move_axes.x -= 1.0;
            if (input.keys[SbKey.KEY_D].down || input.keys[SbKey.KEY_RIGHT].down) cam_move_axes.x += 1.0;
            if (input.keys[SbKey.KEY_S].down || input.keys[SbKey.KEY_DOWN].down)  cam_move_axes.y -= 1.0;
            if (input.keys[SbKey.KEY_W].down || input.keys[SbKey.KEY_UP].down)    cam_move_axes.y += 1.0;
            if (input.keys[SbKey.KEY_SPACE].down || input.keys[SbKey.KEY_Q].down) cam_move_axes.z += 1.0;
            if (input.keys[SbKey.KEY_CTRL].down || input.keys[SbKey.KEY_E].down)  cam_move_axes.z -= 1.0;

            if (input.buttons[SbMouseButton.RMB].down)
                cam_look_axes += vec3(
                    input.cursorDelta.x.isNaN ? 0 : input.cursorDelta.x,
                    input.cursorDelta.y.isNaN ? 0 : input.cursorDelta.y,
                    0
                ) * 0.5;
            fov_delta -= input.scrollDelta.y * 0.25;

            // Set lighting model w/ number keys
            for (auto i = 0; i < LightingModel.max; ++i) {
                if (input.keys[SbKey.KEY_1 + i].pressed) {
                    setLightModel(cast(LightingModel)(i));
                }
            }
            if (input.keys[SbKey.KEY_R].pressed) {
                writefln("Set light = %s, isDirectional = %s",
                    g_light.pos = cam_pos,
                    g_light.isDirectional = false);
            }
            if (input.keys[SbKey.KEY_T].pressed) {
                writefln("Set light = %s, isDirectional = %s",
                    g_light.pos = cam_pos,
                    g_light.isDirectional = false);
            }


            platform.events.onEvent!(
                (const SbGamepadAxisEvent ev) {
                    cam_move_axes.x += ev.axes[ AXIS_LX ];
                    cam_move_axes.y -= ev.axes[ AXIS_LY ];
                    cam_move_axes.z += ev.axes[ AXIS_BUMPERS ];

                    cam_look_axes.y += ev.axes[ AXIS_RY ];
                    cam_look_axes.x += ev.axes[ AXIS_RX ];
                    fov_delta       += ev.axes[ AXIS_TRIGGERS ];

                    auto new_shininess = max(MIN_SHININESS, min(MAX_SHININESS, 
                        g_material.shininess + ev.axes[AXIS_DPAD_X] * dt * (MAX_SHININESS - MIN_SHININESS) * SHININESS_CHANGE_RATE));
                    if (g_material.shininess != new_shininess) {
                        writefln("set shininess = %s", g_material.shininess = new_shininess);
                    }
                    auto new_intensity = max(MIN_INTENSITY, min(MAX_INTENSITY,
                        g_lightIntensity + ev.axes[AXIS_DPAD_Y] * dt * (MAX_INTENSITY - MIN_INTENSITY) * INTENSITY_CHANGE_RATE));
                    if (new_intensity != g_lightIntensity) {
                        writefln("set intensity = %s", g_lightIntensity = new_intensity);
                        g_light.intensity = vec3(g_lightIntensity);
                    }
                },
                (const SbGamepadButtonEvent ev) {
                    if (ev.button == BUTTON_LSTICK && ev.pressed)
                        cam_pos = CAMERA_ORIGIN;
                    if (ev.button == BUTTON_RSTICK && ev.pressed)
                        cam_angles = CAMERA_START_ANGLES;
                    if (ev.button == BUTTON_Y && ev.pressed)
                        drawTriArray = !drawTriArray;
                    
                    else if (ev.button == BUTTON_A && ev.pressed) {
                        writefln("Set light = %s, isDirectional = %s",
                            g_light.pos = cam_pos,
                            g_light.isDirectional = false);
                    }
                    else if (ev.button == BUTTON_X && ev.pressed) {
                        writefln("Set light = %s, isDirectional = %s",
                            g_light.pos = fwd,
                            g_light.isDirectional = true);
                    }
                    if (ev.button == BUTTON_DPAD_LEFT && ev.pressed)  advLightModel(-1);
                    if (ev.button == BUTTON_DPAD_RIGHT && ev.pressed) advLightModel(+1);

                    if (ev.button == BUTTON_B && ev.pressed) {
                        advLightModel(+1);
                    }
                }
            );

            cam_pos -= right * cam_move_axes.x * dt * CAM_MOVE_SPEED;
            cam_pos += fwd   * cam_move_axes.y * dt * CAM_MOVE_SPEED;
            cam_pos -= up    * cam_move_axes.z * dt * CAM_MOVE_SPEED;

            cam_angles.x += cam_look_axes.y * CAM_LOOK_SPEED * dt;
            cam_angles.y -= cam_look_axes.x * CAM_LOOK_SPEED * dt;

            fov = max(MIN_FOV, min(MAX_FOV, fov + fov_delta * FOV_CHANGE_SPEED * dt));

            auto view = mat4.look_at( cam_pos, cam_pos + fwd.normalized, up );

            // triangle rotates about y-axis @origin.
            auto modelMatrix = mat4.yrotation(t).scale( 0.25, 0.25, 0.25 );                

            auto mvp = proj * view * modelMatrix;

            if (drawTriArray) {
                gl.getLocalBatch.execGL({
                    shader.setv("vp", proj * view);
                    shader.setv("model", modelMatrix);
                    //vao.drawArrays( GLPrimitive.TRIANGLES, 0, 3 );
                    vao.drawArraysInstanced( GLPrimitive.GL_TRIANGLES, 0, 3, GRID_DIM.x * GRID_DIM.y * GRID_DIM.z );
                });
            }

            //auto lightDist = 5.0;
            //auto lightPos  = lightDist * vec3( cos(t), 0, sin(t) );

            drawMeshes( 
                CameraInfo( cam_pos, view, proj ),
                g_light,
                g_material
            );

            // Run enqueued async operations for finishing file loads, etc
            threading.runMainThreadTasks();

            platform.swapFrame();
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.teardown();
}
