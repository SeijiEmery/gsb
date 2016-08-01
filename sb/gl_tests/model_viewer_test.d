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

        auto obj_file = "/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj";
        auto obj_zip  = "/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj.zip";
        {
            import std.file;
            StopWatch sw; sw.start();
            auto contents = readText(obj_file);
            writefln("Opened '%s' in %s", obj_file, sw.peek.to!Duration);
        }
        {
            import std.file;
            import std.zip;
            StopWatch sw; sw.start();
            auto archive = new ZipArchive(read(obj_zip));
            auto inner   = archive.directory["dragon.obj"];
            writefln("'%s' compression: %s | compressed %s, expanded %s", 
                inner.name, inner.compressionMethod, inner.compressedSize, inner.expandedSize);

            auto contents = archive.expand(inner);
            writefln("Opened '%s' in %s", obj_zip, sw.peek.to!Duration);
            //writefln("\n\n\nCONTENTS:\n%s", cast(string)contents);
        }
        //auto model = sbLoadObjFile( "/Users/semery/misc-projects/GLSandbox/assets/cube/cube.obj" );
        {
            import std.file;
            import std.zip;
            //auto contents = readText("/Users/semery/misc-projects/GLSandbox/assets/cube/cube.obj");
            auto contents = readText("/Users/semery/misc-projects/GLSandbox/assets/teapot/teapot.obj");
            //auto contents = readText("/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj");
            //auto archive = new ZipArchive(read("/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj.zip"));
            //auto contents = archive.expand(archive.directory["dragon.obj"]);

            tkParseObj(cast(string)contents, 
                (const(char)* mtlName, size_t triCount) {
                    writefln("mtl '%s', tris = %s", mtlName, triCount);
                },
                (TK_Triangle tri) {
                    writefln("%s", tri);
                },
                (ref TK_ObjDelegate obj) {
                    writefln("Read obj file:\n\t %s", obj);
                },
                (ref TK_ObjDelegate obj, string error) {
                    writefln("Error reading obj file:\n\t%s\n%s", obj, error);
                }
            );
        }



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

        auto cam_pos    = vec3( 0, 0, -5 );
        auto cam_angles = vec3(0, 0, 0);
        auto CAM_LOOK_SPEED = 100.0.radians;
        auto CAM_MOVE_SPEED = 15.0;

        float MAX_FOV = 360.0, MIN_FOV = 0.5, FOV_CHANGE_SPEED = 120.0;
        float MIN_FAR = 10, MAX_FAR = 2e3, FAR_CHANGE_SPEED = 1e2;

        float fov = 60.0, near = 0.1, far = 1e3;

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
            if (input.keys[SbKey.KEY_SHIFT].down || input.keys[SbKey.KEY_E].down) wasd_axes.z -= 1.0;

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
                    far = max(MIN_FAR, min(MAX_FAR, far + ev.axes[AXIS_DPAD_Y] * dt * FAR_CHANGE_SPEED));
                },
                (const SbGamepadButtonEvent ev) {
                    if (ev.button == BUTTON_LSTICK && ev.pressed)
                        cam_pos = vec3(0, 0, -5);
                    if (ev.button == BUTTON_RSTICK && ev.pressed)
                        cam_angles = vec3(0, 0, 0);
                }
            );
            auto view = mat4.look_at( cam_pos, cam_pos + fwd.normalized, up );

            // triangle rotates about y-axis @origin.
            auto modelMatrix = mat4.yrotation(t).scale( 0.25, 0.25, 0.25 );                

            auto mvp = proj * view * modelMatrix;
            gl.getLocalBatch.execGL({
                shader.setv("vp", proj * view);
                shader.setv("model", modelMatrix);

                //vao.drawArrays( GLPrimitive.TRIANGLES, 0, 3 );
                vao.drawArraysInstanced( GLPrimitive.TRIANGLES, 0, 3, GRID_DIM.x * GRID_DIM.y * GRID_DIM.z );
            });

            platform.swapFrame();
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.teardown();
}
