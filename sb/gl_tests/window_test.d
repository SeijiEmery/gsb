import sb.platform;
import sb.gl;
import std.stdio;
import std.datetime: StopWatch;
import core.time;
import std.conv;
import std.math: sin;

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
            title: "gl_platform_test",
            size_x: 1200, size_y: 780,
            showFps: true,
        };
        auto window = platform.createWindow("main-window", windowConfig);

        platform.initGL();

        //auto events = platform.getEventsInstance();
        auto gl     = platform.getGraphicsContext();
        auto batch  = gl.getLocalBatch();

        StopWatch sw; sw.start();
        double prevTime = sw.peek.to!("seconds", double);
        while (!window.shouldClose) {
            auto time = sw.peek.to!("seconds", double);
            auto dt   = time - prevTime;
            prevTime  = time;

            window.setTitleFPS( 1.0 / dt );

            immutable auto PERIOD = 2.0; // 2 seconds
            auto c = sin( time / PERIOD );

            //gl.setClearColor(vec4( c, c, c, 1 ));
            platform.swapFrame();
            platform.pollEvents();

            //events.pollFrame();
            //events.writeEventDump(stdout);

            // ...
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.teardown();
}
