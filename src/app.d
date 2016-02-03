
import std.stdio;
import std.concurrency;

import Derelict.glfw3.glfw3;
import Derelict.opengl3.gl3;

import stb.truetype;

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


void graphicsThread (Tid mainThreadId) {

	writeln("Launched graphics thread");

	glfwMakeContextCurrent(g_mainWindow);
	glfwSwapInterval(1);

	DerelictGL3.reload();

	checkGlErrors();
	glEnable(GL_DEPTH_TEST);

	checkGlErrors();

	bool running = true;

	send(mainThreadId, ThreadSyncEvent.READY_FOR_NEXT_FRAME);

	writeln("Running GLSandbox");
	writefln("Renderer: %s", todstr(glGetString(GL_RENDERER)));
	writefln("Opengl version: ", todstr(glGetString(GL_VERSION)));

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
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
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