module rev3.core.glfw_app;
import rev3.core.opengl;
import derelict.glfw3.glfw3;
import std.exception: enforce, assumeWontThrow;
import std.string: toStringz, fromStringz;
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

shared static this () {
    debug writefln("Loading Derelict Libraries");
    DerelictGLFW3.load();
    DerelictGL3.load();

    // Init GLFW
    enforce(glfwInit(), "Failed to initialize glfw");

    // Set global GLFW Error callback
    extern(C) void errorCallback (int err, const(char)* msg) nothrow @safe {
        assumeWontThrow(writefln("GLFW ERROR (%d): %s", err, msg));
    }
    glfwSetErrorCallback(&errorCallback);
}
shared static ~this () {
    debug writefln("Shutting down GLFW");
    glfwTerminate();
    debug writefln("Unloading Derelict Libraries");
    DerelictGLFW3.unload();
    DerelictGL3.unload();
}

class GLFWApplication {
    GLFWwindow* window;
    GLContext   gl;

    this (AppConfig config) {
        // Print application config (debugging)
        debug writefln("%s", config);

        // Create main window
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, config.glVersion.major);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, config.glVersion.minor);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
        glfwWindowHint(GLFW_RESIZABLE,             config.resizable);

        this.window = glfwCreateWindow(config.windowSize.x, config.windowSize.y, config.windowTitle.toStringz, null, null);
        enforce(this.window, "Failed to create glfw window");
        window.glfwMakeContextCurrent();
        
        // Create "GLContext" mock object (note: this is a high-level object that adds a nice
        // abstraction layer with better error handling, call tracing, and introspection; 
        // despite the name, it does NOT own the opengl context, and will only have accurate,
        // authoritative state info if all calls are passed through it).
        this.gl = new GLContext();
    }
    // Separate method so the derived class's constructor can finish running.
    // Expected to be called immediately after this class's constructor.
    // This method begins the app's main event loop, and returns only on successful termination 
    // and/or exceptions.
    void run () {
        // Do pre-init (setup common settings, etc).
        writefln("Renderer: %s\nGL Version: %s",
            gl.GetString(GL_RENDERER).fromStringz,
            gl.GetString(GL_VERSION).fromStringz
        );
        gl.Enable(GL_DEPTH_TEST);
        gl.DepthFunc(GL_LESS);

        // Run Application initialization (create shaders, etc., here).
        onInit();
        
        // Main event loop
        while (!window.glfwWindowShouldClose) {
            glfwPollEvents();
            gl.ClearColor(0, 0, 0, 0);
            gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            
            // Run application per-frame code
            onFrame();
            
            window.glfwSwapBuffers();
        }

        // This gets invoked when we exit from this scope, including via thrown exceptions.
        scope(exit) {
            onTeardown();
        }
    }
    void onInit     () {}
    void onFrame    () {}
    void onTeardown () {}
}
