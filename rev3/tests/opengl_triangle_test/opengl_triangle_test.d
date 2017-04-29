import rev3.core.opengl;
import rev3.core.glfw_app;
import std.exception: enforce;
import std.string: toStringz;
import std.stdio;

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
