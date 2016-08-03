import sb.platform;
import sb.gl;
import sb.events;
import sb.model_loaders.tk_objfile;

import std.stdio;
import std.datetime: StopWatch;
import core.time;
import std.conv;
import gl3n.linalg;
import gl3n.math;
import std.exception: enforce;
import std.format;
import std.path: baseName;
import std.algorithm: endsWith;
import std.string: fromStringz;

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
        string name;
        size_t triCount;
        float[] packedData;
        this (string name, size_t triCount) { 
            this.name = name; 
            this.triCount = triCount;
        }
    }
    auto centroid = vec3(0, 0, 0);
    SubMesh[] meshes;
    auto addMesh ( string name, size_t triCount ) { 
        auto mesh = new SubMesh(name, triCount);
        meshes ~= mesh;
        return mesh;
    }
}
RawModelData loadObj ( string obj_file_contents, RawModelData model = null ) {
    if (!model)
        model = new RawModelData();
    RawModelData.SubMesh mesh = null;
    Exception exc = null;

    double cx = 0, cy = 0, cz = 0; size_t vertCount = 0;
    tkParseObj( obj_file_contents,
        (const(char)* mtlName, size_t triCount) {
            mesh = model.addMesh( mtlName.fromStringz.dup, triCount );
        },
        (TK_Triangle tri) {
            assert( mesh, "Null mesh!" );
            void writev ( TK_TriangleVert v, ref float[] packedData ) {
                cx += v.pos[0]; cy += v.pos[1]; cz += v.pos[2]; ++vertCount;
                packedData ~= [ v.pos[0], v.pos[1], v.pos[2], v.st[0], v.st[1], v.nrm[0], v.nrm[1], v.nrm[2] ];
            }
            writev( tri.vertA, mesh.packedData );
            writev( tri.vertB, mesh.packedData );
            writev( tri.vertC, mesh.packedData );
        },
        (ref TK_ObjDelegate _) {
            writefln("Finished reading obj file");
        },
        (ref TK_ObjDelegate obj, string error) {
            exc = new Exception(format("Error reading obj file:\n\t%s\n%s", obj, error));
        }
    );
    if (exc) throw exc;

    if (!vertCount) vertCount = 1;
    model.centroid += vec3( cx / vertCount, cy / vertCount, cz / vertCount );
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

    void render () {
        foreach (ref item; renderItems) {
            item.vao.drawArrays( item.primitive, cast(uint)item.start, cast(uint)item.count );
        }
    }
    // Generate from mesh part data
    this ( RawModelData.SubMesh mesh, GLShaderRef shader, IGraphicsContext gl, GLResourcePoolRef resourcePool ) {
        this.name = mesh.name;
        void genTris ( float[] packedData_v3_s2_n3, size_t count ) {
            auto vbo = resourcePool.createVBO();
            gl.getLocalBatch.execGL({ bufferData(vbo, packedData_v3_s2_n3, GLBuffering.STATIC_DRAW); });

            auto vao = resourcePool.createVAO();
            vao.bindVertexAttrib( 0, vbo, 3, GLType.FLOAT, GLNormalized.FALSE, float.sizeof * 8, 0 );
            vao.bindVertexAttrib( 1, vbo, 2, GLType.FLOAT, GLNormalized.FALSE, float.sizeof * 8, float.sizeof * 3 );
            vao.bindVertexAttrib( 2, vbo, 3, GLType.FLOAT, GLNormalized.FALSE, float.sizeof * 8, float.sizeof * 5 );
            vao.bindShader( shader );

            renderItems ~= RenderItem( vao, GLPrimitive.TRIANGLES, 0, count * 3 );
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
    void render () {
        foreach (ref part; parts)
            part.render();
    }
}


void main (string[] args) {
    SbPlatformConfig platformConfig = {
        backend: SbPlatform_Backend.GLFW3,
        glVersion: SbPlatform_GLVersion.GL_410,
    };
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
        meshShader.rawSource(ShaderType.VERTEX, `
            #version 410
            layout(location=0) in vec3 vertPosition;
            layout(location=1) in vec2 vertUV;
            layout(location=2) in vec3 vertNormal;

            uniform mat4 modelViewMatrix;
            uniform mat3 normalMatrix;
            uniform mat4 mvp;

            out vec3 position;
            out vec3 normal;
            
            void main () {
                normal = normalize(normalMatrix * vertNormal);
                position = vec3(modelViewMatrix * vec4(vertPosition, 1.0));
                gl_Position = mvp * vec4(vertPosition, 1.0);
            }
        `);
        meshShader.rawSource(ShaderType.FRAGMENT, `
            #version 410
            in vec3 position;
            in vec3 normal;

            struct LightInfo {
                vec4 position;
                vec3 intensity;
            };
            struct MaterialInfo {
                vec3 Ka;
                vec3 Kd;
                vec3 Ks;
                float shininess;
            };
            uniform LightInfo    light;
            uniform MaterialInfo material;

            layout(location=0) out vec4 fragColor;

            subroutine vec3 shadingModel ();
            subroutine uniform shadingModel calcLighting;

            subroutine (shadingModel)
            vec3 phongModel_noHalfwayVector () {
                vec3 n = normalize(normal);
                vec3 s = normalize(vec3(light.position) - position);
                vec3 v = normalize(vec3(-position));
                vec3 r = reflect(-s, n);

                return light.intensity * (
                    material.Ka +
                    material.Kd * max(dot(s, n), 0.0) +
                    material.Ks * pow(max(dot(r, v), 0.0), material.shininess)
                );
            }

            subroutine (shadingModel)
            vec3 phongModel_halfwayVector () {
                vec3 n = normalize(normal);
                vec3 s = normalize(vec3(light.position) - position);
                vec3 v = normalize(vec3(-position));
                vec3 h = normalize(v + s);

                return light.intensity * (
                    material.Ka +
                    material.Kd * max(dot(s, n), 0.0) +
                    material.Ks * pow(max(dot(h, n), 0.0), material.shininess)
                );
            }

            void main () {
                fragColor = vec4(calcLighting(), 1.0);
            }
        `);
        
        struct LightInfo {
            vec3 pos;
            vec3 intensity = vec3(1.0);
            //vec3 ambient = vec3(0.2);
            //vec3 diffuse = vec3(0.5);
            //vec3 specular = vec3(1.0);
        }
        struct MaterialInfo {
            vec3 ambient  = vec3(0.5,0.5,1);
            vec3 diffuse  = vec3(1,0,0);
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

        float MIN_SHININESS = 1, MAX_SHININESS = 300, SHININESS_CHANGE_RATE = 0.4;
        float MIN_INTENSITY = 0.1, MAX_INTENSITY = 10.0, INTENSITY_CHANGE_RATE = 0.5;

        void setUseHalfwayVector (bool useHalfwayVector) {
            g_useHalfwayVector = useHalfwayVector;
            gl.getLocalBatch.execGL({
                meshShader.useSubroutine(ShaderType.FRAGMENT, useHalfwayVector ?
                    "phongModel_halfwayVector" :
                    "phongModel_noHalfwayVector");
            });
        }
        setUseHalfwayVector(g_useHalfwayVector);

        void setLight (ref CameraInfo camera, ref LightInfo light) {
            meshShader.setv("light.position",  camera.view * vec4(light.pos, 1.0));
            meshShader.setv("light.intensity", light.intensity);
            //meshShader.setv("useHalfwayVector", cast(int)g_useHalfwayVector);
            //meshShader.setv("light.La", light.ambient);
            //meshShader.setv("light.Ld", light.diffuse);
            //meshShader.setv("light.Ls", light.specular);
        }
        void setModel (ref mat4 model, ref CameraInfo camera, ref MaterialInfo material) {
            meshShader.setv("material.Ka", material.ambient);
            meshShader.setv("material.Kd", material.diffuse);
            meshShader.setv("material.Ks", material.specular);
            meshShader.setv("material.shininess", material.shininess);
            
            auto vp = camera.view * model;
            meshShader.setv("modelViewMatrix", vp);
            meshShader.setv("normalMatrix", mat3(vp).inverse.transposed);
            meshShader.setv("mvp", camera.proj * vp);
        }
        RenderableMesh[] meshes;
        GLResourcePoolRef[string] resourcePools;

        void loadMesh ( string path, vec3 pos, vec3 scale, quat rotation, bool useCentroid = true ) {
            auto isZip = path.endsWith(".zip");
            auto fileName = isZip ? baseName(path, ".zip") : baseName(path);
            try {
                StopWatch sw; sw.start();
                auto contents = isZip ? readArchive(path, fileName) : readFile(path);
                auto modelData = loadObj(cast(string)contents);
                if (!useCentroid)
                    modelData.centroid = vec3(0, 0, 0);

                writefln("Loaded '%s' in %s. %s parts:", fileName, sw.peek.to!Duration, modelData.meshes.length);
                foreach (mesh; modelData.meshes)
                    writefln("\t'%s' | %s tris", mesh.name, mesh.triCount);
                writefln("\tcentroid: %s", modelData.centroid);
                writeln("");

                auto pool = resourcePools[fileName] = gl.createResourcePrefix( fileName );
                meshes ~= RenderableMesh(
                    modelData, 
                    meshShader, gl, pool,
                    pos, scale, rotation
                );
            } catch (Exception e) {
                writefln("Failed to load '%s':\n%s", fileName, e);
            }
        }
        void drawMeshes ( CameraInfo camera, ref LightInfo light, ref MaterialInfo material ) {
            gl.getLocalBatch.execGL({
                setLight(camera, light);
                foreach (ref mesh; meshes) {
                    setModel(mesh.transform, camera, material);
                    mesh.render();
                }
            });
        }
        loadMesh( "/Users/semery/misc-projects/GLSandbox/assets/cube/cube.obj",
            vec3(5, 0, 0), vec3(1, 1, 1), quat.identity);
        loadMesh( "/Users/semery/misc-projects/GLSandbox/assets/teapot/teapot.obj",
            vec3(0, 1, 0), vec3(0.025, 0.025, 0.025), quat.xrotation(PI), false);
        loadMesh( "/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj.zip",
            vec3(-10, 0, 0), vec3(1, 1, 1), quat.identity);

        auto shader = resourcePool.createShader();
        shader.rawSource(ShaderType.VERTEX, `
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
        shader.rawSource(ShaderType.FRAGMENT, `
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
            bufferData( vbo, position_color_data, GLBuffering.STATIC_DRAW );
            vao.bindVertexAttrib( 0, vbo, 3, GLType.FLOAT, GLNormalized.FALSE, float.sizeof * 6, 0 );
            vao.bindVertexAttrib( 1, vbo, 3, GLType.FLOAT, GLNormalized.FALSE, float.sizeof * 6, float.sizeof * 3 );

            bufferData( instance_vbo, instanceGridData, GLBuffering.STATIC_DRAW );
            vao.bindVertexAttrib( 2, instance_vbo, 3, GLType.FLOAT, GLNormalized.FALSE, 0, 0 );
            vao.setVertexAttribDivisor( 2, 1 );

            vao.bindShader( shader );
        });

        auto CAMERA_ORIGIN = vec3( 0, 0, -5 );
        auto CAMERA_START_ANGLES = vec3(0, PI / 2, 0);

        auto cam_pos    = CAMERA_ORIGIN;
        auto cam_angles = CAMERA_START_ANGLES;
        auto CAM_LOOK_SPEED = 100.0.radians;
        auto CAM_MOVE_SPEED = 15.0;

        auto light_pos = vec3(0,0,0);
        auto LIGHT_Kd = vec3(0.5,0.5,0.5);
        auto LIGHT_Ld = vec3(0.9,0.9,0.9);

        float MAX_FOV = 360.0, MIN_FOV = 0.5, FOV_CHANGE_SPEED = 120.0;
        float MIN_FAR = 10, MAX_FAR = 2e3, FAR_CHANGE_SPEED = 1e2;

        float fov = 60.0, near = 0.1, far = 1e3;
        bool drawTriArray = false; // draw instanced triangles

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
            auto wasd_axes = vec3(0, 0, 0);
            if (input.keys[SbKey.KEY_A].down || input.keys[SbKey.KEY_LEFT].down)  wasd_axes.x -= 1.0;
            if (input.keys[SbKey.KEY_D].down || input.keys[SbKey.KEY_RIGHT].down) wasd_axes.x += 1.0;
            if (input.keys[SbKey.KEY_S].down || input.keys[SbKey.KEY_DOWN].down)  wasd_axes.y -= 1.0;
            if (input.keys[SbKey.KEY_W].down || input.keys[SbKey.KEY_UP].down)    wasd_axes.y += 1.0;
            if (input.keys[SbKey.KEY_SPACE].down || input.keys[SbKey.KEY_Q].down) wasd_axes.z += 1.0;
            if (input.keys[SbKey.KEY_CTRL].down || input.keys[SbKey.KEY_E].down) wasd_axes.z -= 1.0;

            auto mouse_axes = input.buttons[SbMouseButton.RMB].down ?
                input.cursorDelta * 0.25 :
                vec2(0, 0);
            auto scroll_axis = input.scrollDelta.y * 0.25;

            platform.events.onEvent!(
                (const SbGamepadAxisEvent ev) {
                    cam_pos -= right * (wasd_axes.x + ev.axes [ AXIS_LX ]) * dt * CAM_MOVE_SPEED;
                    cam_pos += fwd   * (wasd_axes.y - ev.axes [ AXIS_LY ]) * dt * CAM_MOVE_SPEED;
                    cam_pos += up    * (wasd_axes.z + ev.axes [ AXIS_BUMPERS ]) * dt * CAM_MOVE_SPEED;

                    cam_angles.x += (mouse_axes.y + ev.axes[AXIS_RY]) * dt * CAM_LOOK_SPEED;
                    cam_angles.y -= (mouse_axes.x + ev.axes[AXIS_RX]) * dt * CAM_LOOK_SPEED;

                    fov = max(MIN_FOV, min(MAX_FOV, fov + (ev.axes[AXIS_TRIGGERS] - scroll_axis) * dt * FOV_CHANGE_SPEED));

                    auto new_shininess = max(MIN_SHININESS, min(MAX_SHININESS, 
                        g_material.shininess + ev.axes[AXIS_DPAD_Y] * dt * (MAX_SHININESS - MIN_SHININESS) * SHININESS_CHANGE_RATE));
                    if (g_material.shininess != new_shininess) {
                        writefln("set shininess = %s", g_material.shininess = new_shininess);
                    }

                    auto new_intensity = max(MIN_INTENSITY, min(MAX_INTENSITY,
                        g_lightIntensity + ev.axes[AXIS_DPAD_X] * dt * (MAX_INTENSITY - MIN_INTENSITY) * INTENSITY_CHANGE_RATE));
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
                    if (ev.button == BUTTON_A && ev.pressed)
                        g_light.pos = cam_pos;
                    if (ev.button == BUTTON_B && ev.pressed) {
                        setUseHalfwayVector(!g_useHalfwayVector);
                        writefln("use halfway vector: %s", g_useHalfwayVector);
                    }
                }
            );
            auto view = mat4.look_at( cam_pos, cam_pos + fwd.normalized, up );

            // triangle rotates about y-axis @origin.
            auto modelMatrix = mat4.yrotation(t).scale( 0.25, 0.25, 0.25 );                

            auto mvp = proj * view * modelMatrix;

            if (drawTriArray) {
                gl.getLocalBatch.execGL({
                    shader.setv("vp", proj * view);
                    shader.setv("model", modelMatrix);
                    //vao.drawArrays( GLPrimitive.TRIANGLES, 0, 3 );
                    vao.drawArraysInstanced( GLPrimitive.TRIANGLES, 0, 3, GRID_DIM.x * GRID_DIM.y * GRID_DIM.z );
                });
            }

            //auto lightDist = 5.0;
            //auto lightPos  = lightDist * vec3( cos(t), 0, sin(t) );

            drawMeshes( 
                CameraInfo( cam_pos, view, proj ),
                g_light,
                g_material
            );
            platform.swapFrame();
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.teardown();
}
