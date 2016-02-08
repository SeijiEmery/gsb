
import std.stdio;
import std.concurrency;
import std.traits;
import std.format;

import Derelict.glfw3.glfw3;
import Derelict.opengl3.gl3;
import gl3n.linalg;

import gsb.glutils;
import gsb.text.textrenderer;
import gsb.triangles_test;
import gsb.text.textrendertest;

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

//static string[GLenum] glErrors;

enum ThreadSyncEvent {
	READY_FOR_NEXT_FRAME,        // sent from graphics thread => main thread
	NOTIFY_NEXT_FRAME,           // sent from main thread => graphics thread
	NOTIFY_SHOULD_DIE,           // sent from main thread => worker thread(s)
	NOTIFY_THREAD_DIED           // sent from worker thread to main thread
}

static __gshared GLFWwindow * g_mainWindow = null;

__gshared Log g_graphicsLog = null;
__gshared Log g_mainLog     = null;  

Log log = null;    

void graphicsThread (Tid mainThreadId) {
	log = g_graphicsLog = new Log("graphics-thread");

	log.write("Launched graphics thread");

	glfwMakeContextCurrent(g_mainWindow);
	glfwSwapInterval(1);

	DerelictGL3.reload();

	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LESS);

	glEnable(GL_BLEND);
	glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	//glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
	//glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO);

	//auto call = tryCall(glEnable);
	//call(GL_DEPTH_TEST);
	//checkGlErrors();

	bool running = true;

	log.write("Running GLSandbox");
	log.write("Renderer: %s", todstr(glGetString(GL_RENDERER)));
	log.write("Opengl version: %s", todstr(glGetString(GL_VERSION)));

	auto camera = new Camera();
	auto test = new TriangleRenderer();

	Font font;
	TextBuffer text;

	//font = loadFont("/Library/Fonts/Arial.ttf");
	//font = loadFont("/Library/Fonts/Trattatello.ttf");
	font = loadFont("/Library/Fonts/Anonymous Pro.ttf");
	text = new TextBuffer(font);
	text.appendText("Hello world!");

	auto createView (Log targetLog, float width, float height, mat4 transform) {
		return new LogView(targetLog).setBounds(width, height).setTransform(transform);
	}

	LogView[string] logViews = [
		"graphics": createView(g_graphicsLog, 800, 200, mat4.translation(0, +0.5, 0)),
		"main": createView(g_mainLog, 800, 200, mat4.translation(0, -0.5, 0))
	];

	auto utfTest = StbTextRenderTest.defaultTest();

	int frame = 0;
	while (running) {
		auto evt = receiveOnly!(ThreadSyncEvent)();
		switch (evt) {
			case ThreadSyncEvent.NOTIFY_SHOULD_DIE: {
				log.write("Recieved kill event");
				running = false;
			} break;
			case ThreadSyncEvent.NOTIFY_NEXT_FRAME: {

				log.write("on frame %d", frame++);

				//tryCall(glClear)(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
				glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


				utfTest.render();

				//text.render(camera);
				//text.clear();
				//text.appendText(format("Hello World!\nCurrent frame is %d", frame));

				//foreach (logView; logViews.values) {
				//	logView.maybeUpdate();
				//}

				glfwSwapBuffers(g_mainWindow);
				checkGlErrors();

				send(mainThreadId, ThreadSyncEvent.READY_FOR_NEXT_FRAME);
			} break;
			default: {
				log.write("Unexpected event: %d", evt);
			}
		}
	}
	prioritySend(mainThreadId, ThreadSyncEvent.NOTIFY_THREAD_DIED);	
}
void enterGraphicsThread (Tid mainThreadId) {
	try {
		graphicsThread(mainThreadId);
	} catch (Error e) {
		if (g_graphicsLog)
			g_graphicsLog.write("Error: %s", e);
		else
			writefln("[graphics-thread] Error: %s", e);
		prioritySend(mainThreadId, ThreadSyncEvent.NOTIFY_THREAD_DIED);
	}
}
void enterMainThread (Tid graphicsThreadId) {
	try {
		mainThread(graphicsThreadId);
	} catch (Error e) {
		if (g_mainLog)
			g_mainLog.write("Error: %s", e);
		else
			writefln("[main-thread] Error: %s", e);
		prioritySend(graphicsThreadId, ThreadSyncEvent.NOTIFY_SHOULD_DIE);
	}
}

void mainThread (Tid graphicsThreadId) {
	log = g_mainLog = new Log("main-thread");

	while (!glfwWindowShouldClose(g_mainWindow)) {
		glfwPollEvents();

		send(graphicsThreadId, ThreadSyncEvent.NOTIFY_NEXT_FRAME);

		while (1) {
			auto evt = receiveOnly!(ThreadSyncEvent)();
			switch (evt) {
				case ThreadSyncEvent.READY_FOR_NEXT_FRAME: goto nextFrame;
				case ThreadSyncEvent.NOTIFY_THREAD_DIED: {
					log.write("Graphics thread terminated (unexpected!)");
					goto gthreadDied;
				}
				default: {
					log.write("Recieved unhandled event: %d", evt);
				}
			}
		}
	nextFrame:
	}
	log.write("Killing graphics thread");
	send(graphicsThreadId, ThreadSyncEvent.NOTIFY_SHOULD_DIE);
	{
		ThreadSyncEvent evt;
		while ((evt = receiveOnly!(ThreadSyncEvent)()) != ThreadSyncEvent.NOTIFY_THREAD_DIED) {
			log.write("Waiting on thread kill event (recieved %d)", evt);
		}
	}
gthreadDied:
	log.write("Shutting down");

	glfwDestroyWindow(g_mainWindow);
	glfwTerminate();
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
		writeln("Failed to create glfw window");
		glfwTerminate();
		return;
	}

	auto graphicsThread = spawn(&enterGraphicsThread, thisTid);

	enterMainThread(graphicsThread);
}