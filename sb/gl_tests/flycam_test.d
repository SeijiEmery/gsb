import sb.platform;
import sb.gl;
import std.stdio;
import std.datetime: StopWatch;
import core.time;
import std.conv;
import std.math;
import gl3n.linalg;

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
        auto resourcePool = gl.createResourcePrefix("window-test");
        scope(exit) resourcePool.release();

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

            gl.getLocalBatch.execGL({
                shader.setv("mvp", mat4.yrotation(t));
                vao.drawArrays( GLPrimitive.TRIANGLES, 0, 3 );
            });

            platform.swapFrame();
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.teardown();
}
