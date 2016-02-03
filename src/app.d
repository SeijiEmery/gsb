
import std.stdio;
import std.concurrency;

import Derelict.glfw3.glfw3;
import Derelict.opengl3.gl3;

import gsb.text.textrenderer;
import gsb.triangles_test;

auto todstr(inout(char)* cstr) {
	import core.stdc.string: strlen;
	return cstr ? cstr[0 .. strlen(cstr)] : "";
}

void checkGlErrors (string context = "") {
	GLenum err;
	while ((err = glGetError()) != GL_NO_ERROR) {
		switch (err) {
			case GL_INVALID_OPERATION: writefln("gl: INVALID OPERATION"); break;
			case GL_INVALID_ENUM:      writefln("gl: INVALID ENUM"); break;
			case GL_INVALID_VALUE:     writefln("gl: INVALID VALUE"); break;
			case GL_INVALID_FRAMEBUFFER_OPERATION: writeln("gl: INVALID FRAMEBUFFER OPERATION"); break;
			default:                   writefln("gl: UNKNOWN ERROR %d", err);
		}
	}
}

enum ThreadSyncEvent {
	READY_FOR_NEXT_FRAME,
	NOTIFY_NEXT_FRAME,
	NOTIFY_SHOULD_DIE,
	NOTIFY_THREAD_DIED
}

static __gshared GLFWwindow * g_mainWindow = null;

extern (C) void glErrorCallback (GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userdata) {
	const static string[GLenum] debugSources = [
		DEBUG_SOURCE_API: "Source API",
		DEBUG_SOURCE_WINDOW_SYSTEM: "Window System",
		DEBUG_SOURCE_SHADER_COMPILER: "Shader Compiler",
		DEBUG_SOURCE_THIRD_PARTY: "Third Party",
		DEBUG_SOURCE_APPLICATION: "Application",
		DEBUG_SOURCE_OTHER: "Other debug source"
	];
	const static string[GLenum] debugTypes = [
		DEBUG_TYPE_ERROR: "Error",
		DEBUG_TYPE_DEPRECATED_BEHAVIOR: "Deprecated behavior",
		DEBUG_TYPE_UNDEFINED_BEHAVIOR: "Undefined behavior",
		DEBUG_TYPE_PORTABILITY: "Non-portable",
		DEBUG_TYPE_PERFORMANCE: "Performance warning",
		DEBUG_TYPE_MARKER: "Command stream annotation",
		DEBUG_TYPE_PUSH_GROUP: "Group pushed",
		DEBUG_TYPE_POP_GROUP: "Group popped",
		DEBUG_TYPE_OTHER: "Other debug type"
	];
	const static string[GLenum] debugSeverity = [
		DEBUG_SEVERITY_HIGH: "High Severity",
		DEBUG_SEVERITY_MEDIUM: "Medium Severity",
		DEBUG_SEVERITY_LOW: "Low Severity",
		DEBUG_SEVERITY_NOTIFICATION: "Low-severity-notification"
	];

	string tryGetName (GLuint id) {
		const static string[GLenum] idTypes = [
			GL_BUFFER: "GL_BUFFER",
			GL_SHADER: "GL_SHADER",
			GL_PROGRAM: "GL_PROGRAM",
			GL_VERTEX_ARRAY: "GL_VERTEX_ARRAY",
			GL_QUERY: "GL_QUERY",
			GL_PROGRAM_PIPELINE: "GL_PROGRAM_PIPELINE",
			GL_TRANSFORM_FEEDBACK: "GL_TRANSFORM_FEEDBACK",
			GL_SAMPLER: "GL_SAMPLER",
			GL_TEXTURE: "GL_TEXTURE",
			GL_RENDERBUFFER: "GL_RENDERBUFFER",
			GL_FRAMEBUFFER: "GL_FRAMEBUFFER"
		];
		char[] name = new char [256]; GLsizei length = 0;
		foreach (idType; idTypes.byKeyValue()) {
			glGetObjectLabel(id, idType.key, 256, &length, &name[0]);
			if (length != 0) {
				return idType.value ~ " " ~ name[0 .. length];
			}
		}
		return sformat("%d", id);
	}

	writefln("GL_MESSAGE (%s | %s | %s)[%s]: %s", debugSources[source], debugTypes[type], debugSeverity[severity], tryGetName(id), message[0 .. length]);
}

void graphicsThread (Tid mainThreadId) {

	writeln("Launched graphics thread");

	glfwMakeContextCurrent(g_mainWindow);
	glfwSwapInterval(1);

	DerelictGL3.reload();

	glDebugMessageCallback(glErrorCallback, null);

	//checkGlErrors();
	glEnable(GL_DEPTH_TEST);

	//checkGlErrors();

	bool running = true;

	send(mainThreadId, ThreadSyncEvent.READY_FOR_NEXT_FRAME);

	writeln("Running GLSandbox");
	writefln("Renderer: %s", todstr(glGetString(GL_RENDERER)));
	writefln("Opengl version: ", todstr(glGetString(GL_VERSION)));

	auto camera = new Camera();
	auto test = new TriangleRenderer();

	int frame = 0;

	while (running) {
		auto evt = receiveOnly!(ThreadSyncEvent)();
		switch (evt) {
			case ThreadSyncEvent.NOTIFY_SHOULD_DIE: {
				writeln("Recieved kill event");
				running = false;
			} break;
			case ThreadSyncEvent.NOTIFY_NEXT_FRAME: {

				writefln("on frame %d", frame++);

				glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

				test.render(camera);

				glfwSwapBuffers(g_mainWindow);
				checkGlErrors();

				send(mainThreadId, ThreadSyncEvent.READY_FOR_NEXT_FRAME);
			} break;
			default: {

			}
		}
	}
	prioritySend(mainThreadId, ThreadSyncEvent.NOTIFY_THREAD_DIED);	
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

	g_mainWindow = glfwCreateWindow(800, 600, "GL Sandbox", null, null);
	if (!g_mainWindow) {
		writeln("Failed to create window");
		glfwTerminate();
		return;
	}

	auto graphicsThreadId = spawn(&graphicsThread, thisTid);

	bool initialized = false;
	while (!initialized) {
		receive (
			(ThreadSyncEvent evt) {
				if (evt == ThreadSyncEvent.READY_FOR_NEXT_FRAME) {
					initialized = true;
					writeln("Initialized.");
				} else {
					writeln("Recieved unexpected event");
				}
			}
		);
	}	

	while (!glfwWindowShouldClose(g_mainWindow)) {
		glfwPollEvents();

		send(graphicsThreadId, ThreadSyncEvent.NOTIFY_NEXT_FRAME);
		auto evt = receiveOnly!(ThreadSyncEvent)();

		while (evt != ThreadSyncEvent.READY_FOR_NEXT_FRAME) {
			evt = receiveOnly!(ThreadSyncEvent)();
		}
	}
	writeln("Killing graphics thread");
	send(graphicsThreadId, ThreadSyncEvent.NOTIFY_SHOULD_DIE);

	ThreadSyncEvent evt;
	while ((evt = receiveOnly!(ThreadSyncEvent)()) != ThreadSyncEvent.NOTIFY_THREAD_DIED) {
		writefln("Waiting on thread kill event (recieved %d)", evt);
	}

	writeln("Deinitializing");

	glfwDestroyWindow(g_mainWindow);
	glfwTerminate();
}