
import std.stdio;
import std.concurrency;
import std.traits;
import std.format;

import std.parallelism;

import Derelict.glfw3.glfw3;
import Derelict.opengl3.gl3;
import gl3n.linalg;

import gsb.core.log;
import gsb.core.window;
import gsb.core.events;

import gsb.glutils;
import gsb.text.font;
import gsb.text.textrenderer;
import gsb.triangles_test;
import gsb.text.textrendertest;
import gsb.core.color;

import std.datetime;


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
	NOTIFY_THREAD_DIED ,          // sent from worker thread to main thread

	// sent when gl state is potentially invalid (framebuffer/monitor changed?), 
	// and should be regenerated.
	// This is basically a hook so the main thread can make the graphics thread emit a 
	// GraphicsEvent.glStateInvalidated() signal before the next frame
	//NOTIFY_GL_STATE_INVALIDATED, 

}

void graphicsThread (Tid mainThreadId) {
	log = g_graphicsLog = new Log("graphics-thread");

	log.write("Launched graphics thread");

	glfwMakeContextCurrent(g_mainWindow.handle);
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

	auto textRenderer = TextRenderer.instance.getGraphicsThreadHandle();

	//auto utfTest = StbTextRenderTest.defaultTest();

	//GraphicsEvents.glStateInvalidated.connect(() {
	//	log.write("Recieved glStateInvalidated");
	//});

	int frame = 0;
	while (running) {
		auto evt = receiveOnly!(ThreadSyncEvent)();
		switch (evt) {
			case ThreadSyncEvent.NOTIFY_SHOULD_DIE: {
				log.write("Recieved kill event");
				running = false;
			} break;
			//case ThreadSyncEvent.NOTIFY_GL_STATE_INVALIDATED: {
			//	log.write("emitting GL_STATE_INVALIDATED");
			//	GraphicsEvents.glStateInvalidated.emit();
			//} break;
			case ThreadSyncEvent.NOTIFY_NEXT_FRAME: {
				send(mainThreadId, ThreadSyncEvent.READY_FOR_NEXT_FRAME);

				//log.write("on frame %d", frame++);

				//tryCall(glClear)(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
				glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

				//utfTest.render();
				//textRenderer.render();
				TextRenderer.instance.renderFragments();

				glfwSwapBuffers(g_mainWindow.handle);
				checkGlErrors();
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
	} catch (Throwable e) {
		if (g_graphicsLog)
			g_graphicsLog.write("Error: %s", e);
		else
			writefln("[graphics-thread] Error: %s", e);
		prioritySend(mainThreadId, ThreadSyncEvent.NOTIFY_THREAD_DIED);
	}
}

void mainThread (Tid graphicsThreadId) {
	// Setup event logging
	WindowEvents.instance.onScreenScaleChanged.connect(delegate(float x, float y) {
		log.write("WindowEvent: Screen scale changed: %0.2f, %0.2f", x, y);	
	});
	WindowEvents.instance.onFramebufferSizeChanged.connect(delegate(float x, float y) {
		log.write("WindowEvent: Framebuffer size set to %0.2f, %0.2f", x, y);
	});
	WindowEvents.instance.onScreenSizeChanged.connect(delegate(float x, float y) {
		log.write("WindowEvent: Window size set to %0.2f, %0.2f", x, y);
	});

	g_mainWindow.setupDefaultEventLogging();

	registerDefaultFonts();  // from gsb.text.font


	//auto loadFontTime = benchmark!loadFonts(1);
	//log.write("Loaded fonts in %s ms", loadFontTime[0].msecs);

	//auto font = new Font("arial", 40);
	//auto elem = new TextFragment("Hello World!", font, Color("#ffbf9d"), vec2(200, 200));

	//auto text = TextRenderer.instance.createTextElement("menlo", 32);
	//text.append("Hello world!\nü@asdlfj;\n");

	auto text2 = new TextFragment(
		"Hello world!\nü@asdlfj;\n",
		new Font("menlo", 32),
		Color("#ffaaff"),
		vec2(0,0));

	//auto text = TextRenderer.instance.createTextElement()
	//	.style("console")
	//	.fontSize(22)
	//	.position(TextRenderer.RelPos.TOP_LEFT, 10, 10)
	//	.bounds(800, 400)
	//	.color("#ffaadd")
	//	.scroll(true);

	//text.append("Hello World!");
	//auto curLine = g_mainLog.lines.length;
	//text.append(join(g_mainLog.lines[0..curLine], "\n"));

	//taskPool.put(task!loadFonts());
	//log.write("parallelism -- cpus = %u", totalCPUs);
	//log.write("parallelism -- default work threads = %u", defaultPoolThreads);

	//auto stuff = new int[100];
	//foreach (i, ref elem; taskPool.parallel(stuff, 1)) {
	//	createWorkerLog().write("foo %d", i);
	//}

	//bool glStateInvalidated = false;
	//auto conn = WindowEvents.instance.onScreenScaleChanged.connect(delegate(float x, float y) {
	//	log.write("gl state may be invalid!");
	//	glStateInvalidated = true;
	//});

	int frameCount = 0;

	while (!glfwWindowShouldClose(g_mainWindow.handle)) {

		//log.write("Starting frame %d", frameCount);

		glfwPollEvents();
		g_mainWindow.runEventUpdates();
		WindowEvents.instance.updateFromMainThread();
		TextRenderer.instance.updateFragments();

		//if (glStateInvalidated) {
		//	log.write("Invalidating gl state!");
		//	glStateInvalidated = false;
		//	send(graphicsThreadId, ThreadSyncEvent.NOTIFY_GL_STATE_INVALIDATED);
		//}

		send(graphicsThreadId, ThreadSyncEvent.NOTIFY_NEXT_FRAME);
		//log.write("Sent frame %d", frameCount++);

		while (1) {
			auto evt = receiveOnly!(ThreadSyncEvent)();
			switch (evt) {
				case ThreadSyncEvent.READY_FOR_NEXT_FRAME: 
					goto nextFrame;
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
		//if (g_mainLog.lines.length != curLine) {
		//	auto n = g_mainLog.lines.length;
		//	text.append(join(g_mainLog.lines[curLine..n], "\n"));
		//	curLine = n;
		//}
	}
	log.write("Killing graphics thread");
	prioritySend(graphicsThreadId, ThreadSyncEvent.NOTIFY_SHOULD_DIE);
	{
		ThreadSyncEvent evt;
		while ((evt = receiveOnly!(ThreadSyncEvent)()) != ThreadSyncEvent.NOTIFY_THREAD_DIED) {
			writefln("[main-thread] Waiting on thread kill event (recieved %d)", evt);
		}
	}
gthreadDied:
}
void enterMainThread (Tid graphicsThreadId) {
	try {
		mainThread(graphicsThreadId);
	} catch (Throwable e) {
		if (g_mainLog)
			g_mainLog.write("Error: %s", e);
		else
			writefln("[main-thread] Error: %s", e);
		prioritySend(graphicsThreadId, ThreadSyncEvent.NOTIFY_SHOULD_DIE);
		ThreadSyncEvent evt;
		while ((evt = receiveOnly!(ThreadSyncEvent)()) != ThreadSyncEvent.NOTIFY_THREAD_DIED) {
			writefln("[main-thread] Waiting on thread kill event (recieved %d)", evt);
		}
	}
}

void main()
{
	defaultPoolThreads(16);
	log = g_mainLog = new Log("main-thread");

	// Preload gl + glfw
	DerelictGLFW3.load();
	DerelictGL3.load();

	if (!glfwInit()) {
		writeln("Failed to initialize glfw");
		return;
	}

	// Create window
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, true);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

	g_mainWindow = new Window(glfwCreateWindow(800, 600, "GL Sandbox", null, null), false);
	if (!g_mainWindow) {
		writeln("Failed to create glfw window");
		glfwTerminate();
		return;
	}

	WindowEvents.instance.init(g_mainWindow);

	// And then hand our gl context off to the graphics thread (via the __gshared window handle)
	auto gthreadHandle = spawn(&enterGraphicsThread, thisTid);

	// We'll finish initializing and run our control + event code on the main thread, but opengl
	// access is confined _strictly_ to the graphics thread.

	try {
		enterMainThread(gthreadHandle);
	} catch (Error e) {
		writeln(e);
	}

	// Finally, we run our shutdown code here.
	// Note: the main thread terminates iff
	// - app exits normally (cmd+q / window closed / etc)
	// - main thread threw an exception and must terminate
	// - a critical / core thread (like the graphics thread) threw an exception and terminated.
	//
	// In the first two cases, mainThread / enterMainThread will kill all worker threads and wait
	// for confirmation before returning
	//
	log.write("Shutting down");
	WindowEvents.instance.deinit();
	glfwDestroyWindow(g_mainWindow.handle);
	glfwTerminate();
}