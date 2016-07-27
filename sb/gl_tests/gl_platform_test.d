import sb.platform;
import sb.gl;
import std.stdio;

void main (string[] args) {
    SbPlatformConfig platformConfig = {
        .backend   = SbPlatform_Backend.GLFW3,
        .glVersion = SbPlatform_GLVersion.GL_410,
    };

    auto platform = sbCreatePlatform(platformConfig);
    try {
        platform.init();
        platform.preInitGL();
        platform.initGL();

        auto events = platform.getEventsInstance();
        auto gl     = platform.getGraphicsContext();
        auto batch  = gl.getLocalBatch();

        SbWindowConfig windowConfig = {
            .title = "gl_platform_test",
            .size_x = 1200, .size_y = 780,
            .showFps = true,
        };
        auto window = platform.createWindow(windowConfig);

        StopWatch sw; sw.start();
        double prevTime = sw.peek.to!Duration.to!("seconds", double);
        while (!window.shouldClose) {
            auto time = sw.peek.to!Duration.to!("seconds", double);
            auto dt   = prevTime - time;
            prevTime  = time;

            window.setTitleFps( 1.0 / dt );

            immutable auto PERIOD = 2.0; // 2 seconds
            auto c = sin( time / PERIOD );

            gl.setClearColor(vec4( c, c, c, 1 ));
            platform.swapFrame();

            events.pollFrame();
            events.writeEventDump(stdout);

            // ...
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.shutdown();
}
