import rev3.core.opengl;
import derelict.glfw3.glfw3;
import std.exception: enforce;
import std.string: toStringz;
import std.stdio;

struct GLVersion { int major; int minor; }
struct AppConfig {
    string    windowTitle;
    GLVersion glVersion  = GLVersion(4, 1);
    vec2i     windowSize = vec2i(800, 600);
    bool      resizable  = true;
    bool      fullscreen = false;

    auto applyArgs (string[] args) {
        import std.getopt;
        int width = -1, height = -1;
        args.getopt(
            "glMajor", &glVersion.major, 
            "glMinor", &glVersion.minor,
            "width",   &width, 
            "height",  &height,
            "resizable", &resizable,
            "fullscreen", &fullscreen
        );
        if (width > 0) windowSize.x = width;
        if (height > 0) windowSize.y = height;
        return this;
    }
}
class GLFWApplication {
    GLFWwindow* window;
    GLContext   gl;

    this (AppConfig config) {
        writefln("config = %s", config);

        DerelictGLFW3.load();
        DerelictGL3.load();

        enforce(glfwInit(), "Failed to initialize glfw");

        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, config.glVersion.major);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, config.glVersion.minor);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
        glfwWindowHint(GLFW_RESIZABLE,             config.resizable);

        this.window = glfwCreateWindow(config.windowSize.x, config.windowSize.y, config.windowTitle.toStringz, null, null);
        enforce(this.window, "Failed to create glfw window");
        this.gl = new GLContext();
    }
    void run () {
        scope(exit) {
            onTeardown();
            glfwTerminate();
        }
        gl.Enable(GL_DEPTH_TEST);
        onInit();
        while (!window.glfwWindowShouldClose) {
            glfwPollEvents();
            gl.ClearColor(0, 0, 0, 0);
            gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            onFrame();
            window.glfwSwapBuffers();
        }
    }
    void onInit     () {}
    void onFrame    () {}
    void onTeardown () {}
}

class Application : GLFWApplication {
    this (string[] args) {
        super(AppConfig("Opengl Triangle Test").applyArgs(args));
    }
    override void onInit () {
        writefln("==== Initializing ====");
    }
    int frame = 0;
    override void onFrame () {
        writefln("==== Frame %s ====", frame++);
    }
    override void onTeardown () {
        writefln("==== Teardown ====");
    }
}

int main (string[] args) {
    new Application(args).run();
    return 0;
}
