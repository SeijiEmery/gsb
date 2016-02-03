
import std.stdio;
import Derelict.glfw3.glfw3;
import Derelict.opengl3.gl3;

auto todstr(inout(char)* cstr) {
	import core.stdc.string: strlen;
	return cstr ? cstr[0 .. strlen(cstr)] : "";
}

void main()
{
	DerelictGLFW3.load();
	DerelictGL3.load();

	if (!glfwInit()) {
		writeln("Failed to initialize glfw");
		return;
	}

	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, true);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

	auto window = glfwCreateWindow(800, 600, "GL Sandbox", null, null);
	if (!window) {
		writeln("Failed to create window");
		return;
	}

	glfwMakeContextCurrent(window);
	glfwSwapInterval(1);

	DerelictGL3.reload();

	glEnable(GL_DEPTH_TEST);

	writeln("Running GLSandbox");
	writefln("Renderer: %s", todstr(glGetString(GL_RENDERER)));
	writefln("Opengl version: ", todstr(glGetString(GL_VERSION)));

	while (!glfwWindowShouldClose(window)) {

		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		glfwSwapBuffers(window);
		glfwPollEvents();
	}

	glfwDestroyWindow(window);
	glfwTerminate();
}