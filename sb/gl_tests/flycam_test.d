import sb.platform;
import sb.gl;
import sb.events;

import std.stdio;
import std.datetime: StopWatch;
import core.time;
import std.conv;
//import std.math;
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
            title: "flycam test",
            size_x: 1200, size_y: 780,
            showFps: true,
        };
        auto window = platform.createWindow("main-window", windowConfig);

        platform.initGL();

        //auto events = platform.getEventsInstance();
        auto gl           = platform.getGraphicsContext();
        auto resourcePool = gl.createResourcePrefix("flycam-test");

        auto shader = resourcePool.createShader();
        shader.rawSource(ShaderType.VERTEX, `
            #version 410
            layout(location=0) in vec3 vertPosition;
            layout(location=1) in vec3 vertColor;
            out vec3 color;

            uniform mat4 mvp;

            void main () {
                color = vertColor;
                gl_Position = mvp * vec4( vertPosition, 1.0 );
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

        auto vbo = resourcePool.createVBO();
        auto vao = resourcePool.createVAO();

        gl.getLocalBatch.execGL({
            bufferData( vbo, position_color_data, GLBuffering.STATIC_DRAW );
            vao.bindVertexAttrib( 0, vbo, 3, GLType.FLOAT, GLNormalized.FALSE, float.sizeof * 6, 0 );
            vao.bindVertexAttrib( 1, vbo, 3, GLType.FLOAT, GLNormalized.FALSE, float.sizeof * 6, float.sizeof * 3 );
            vao.bindShader( shader );
        });

        auto cam_pos = vec3( 0, 0, -5 );
        auto cam_angles = vec3(0, 0, 0);
        auto CAM_LOOK_SPEED = 100.0.radians;
        auto CAM_MOVE_SPEED = 15.0;

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

            float fov = 60.0, near = 0.1, far = 1e3;
            auto proj = mat4.perspective( 
                cast(float)window.windowSize.x, 
                cast(float)window.windowSize.y, 
                fov, near, far );

            import std.variant;

            foreach (event; platform.getEvents.m_events) {
                event.tryVisit!(
                    (SbGamepadAxisEvent ev) {
                        cam_pos -= CAM_MOVE_SPEED * dt * vec3(
                            ev.axes[ AXIS_LX ],
                            ev.axes[ AXIS_LTRIGGER ] - ev.axes[ AXIS_RTRIGGER ],
                            ev.axes[ AXIS_LY ],
                        );
                        cam_angles += CAM_LOOK_SPEED * dt * vec3(
                            ev.axes[ AXIS_RX ],
                            ev.axes[ AXIS_RY ],
                            0,
                        );
                    },
                    (){}
                );
            }

            auto view = (mat4.identity
                .rotatey( cam_angles.x )
                .rotatex( cam_angles.y ))
                * mat4.translation(cam_pos);

            // triangle rotates about y-axis @origin.
            auto model = mat4.yrotation(t);                

            auto mvp = proj * view * model;
            gl.getLocalBatch.execGL({
                shader.setv("mvp", mvp);
                vao.drawArrays( GLPrimitive.TRIANGLES, 0, 3 );
            });

            platform.swapFrame();
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.teardown();
}
