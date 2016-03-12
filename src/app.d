
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
import gsb.core.frametime;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.stats;
import gsb.core.color;

import gsb.glutils;
import gsb.text.font;
import gsb.text.textrenderer;
import gsb.triangles_test;
import gsb.text.textrendertest;

import gsb.ui.testui;
import gsb.gl.debugrenderer;

import std.datetime;


auto todstr(inout(char)* cstr) {
	import core.stdc.string: strlen;
	return cstr ? cstr[0 .. strlen(cstr)] : "";
}

enum ThreadSyncEvent {
	READY_FOR_NEXT_FRAME,        // sent from graphics thread => main thread
	NOTIFY_NEXT_FRAME,           // sent from main thread => graphics thread
	NOTIFY_SHOULD_DIE,           // sent from main thread => worker thread(s)
	NOTIFY_THREAD_DIED,          // sent from worker thread to main thread
}

void graphicsThread (Tid mainThreadId) {
	log.write("Launched graphics thread");
	setupThreadStats("graphics-thread");

	g_graphicsFrameTime.init();  // start tracking per-frame time for graphics thread

	glfwMakeContextCurrent(g_mainWindow.handle);
	glfwSwapInterval(1);

	DerelictGL3.reload();

	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LESS);

    glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); 
	CHECK_CALL("setup gl state");
	bool running = true;

	log.write("Running GLSandbox");
	log.write("Renderer: %s", todstr(glGetString(GL_RENDERER)));
	log.write("Opengl version: %s", todstr(glGetString(GL_VERSION)));

	auto camera = new Camera();
	auto test = new TriangleRenderer();

	auto textRenderer = TextRenderer.instance.getGraphicsThreadHandle();

	int frame = 0;
	while (running) {
		auto evt = receiveOnly!(ThreadSyncEvent)();
		switch (evt) {
			case ThreadSyncEvent.NOTIFY_SHOULD_DIE: {
				log.write("Recieved kill event");
				running = false;
			} break;
			case ThreadSyncEvent.NOTIFY_NEXT_FRAME: {
				threadStats.timedCall("frame", {
					g_graphicsFrameTime.updateFromRespectiveThread(); // update g_graphicsTime and g_graphicsDt

					//log.write("on frame %d", frame++);

					//tryCall(glClear)(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
					glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

					//utfTest.render();
					//textRenderer.render();
					threadStats.timedCall("TextRenderer.renderFragments", {
						TextRenderer.instance.renderFragments();
					});

					threadStats.timedCall("DebugRenderer.render", {
						DebugRenderer.renderFromGraphicsThread();
					});

					threadStats.timedCall("send threadSync message", {
						send(mainThreadId, ThreadSyncEvent.READY_FOR_NEXT_FRAME);
					});
					threadStats.timedCall("swapBuffers", {
						glfwSwapBuffers(g_mainWindow.handle);
					});
				});
			} break;
			default: {
				log.write("Unexpected event: %d", evt);
			}
		}
	}
	prioritySend(mainThreadId, ThreadSyncEvent.NOTIFY_THREAD_DIED);	
}
void enterGraphicsThread (Tid mainThreadId) {
	log = g_graphicsLog = new Log("graphics-thread");

	log.write("ENTERING GRAPHICS THREAD");
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

	g_eventFrameTime.init(); // start tracking event thread time
	setupThreadStats("main-thread");

	// Setup event logging
	g_mainWindow.onScreenScaleChanged.connect(delegate(float x, float y) {
		log.write("WindowEvent: Screen scale changed: %0.2f, %0.2f", x, y);	
	});
	g_mainWindow.onFramebufferSizeChanged.connect(delegate(float x, float y) {
		log.write("WindowEvent: Framebuffer size set to %0.2f, %0.2f", x, y);
	});
	g_mainWindow.onScreenSizeChanged.connect(delegate(float x, float y) {
		log.write("WindowEvent: Window size set to %0.2f, %0.2f", x, y);
	});

	UIComponentManager.onComponentRegistered.connect((UIComponent component, string name) {
		log.write("Registered component %s (active = %s)", name, component.active ? "true" : "false");
	});
	UIComponentManager.onComponentActivated.connect((UIComponent component) {
		log.write("Activated component %s", component.name);
	});
	UIComponentManager.onComponentDeactivated.connect((UIComponent component) {
		log.write("Deactivated component %s", component.name);
	});
	UIComponentManager.onEventSourceRegistered.connect((IEventCollector collector) {
		log.write("Registered event source");
	});
	UIComponentManager.onEventSourceUnregistered.connect((IEventCollector collector) {
		log.write("Unregistered event source");
	});

	registerDefaultFonts();

	auto text2 = new TextFragment(
		"Hello world!\nü@asdlfj;\n",
		new Font("menlo", 32),
		Color("#ffaaff"),
		vec2(0,0));

	UIComponentManager.init();

	log.write("Window: %d,%d, %d,%d, %f,%f",
		g_mainWindow.pixelDimensions.x, g_mainWindow.pixelDimensions.y,
		g_mainWindow.screenDimensions.x, g_mainWindow.screenDimensions.y,
		g_mainWindow.screenScale.x, g_mainWindow.screenScale.y);

	int frameCount = 0;

	while (!glfwWindowShouldClose(g_mainWindow.handle)) {
		threadStats.timedCall("frame", {
			// update 'current' time for this frame. Note: graphics and event frame time is
			// always constant until the next frame; it does not change while we're doing updates.
			g_eventFrameTime.updateFromRespectiveThread(); // update g_eventTime, g_eventDt

			// Poll glfw + system events
			threadStats.timedCall("glfwPollEvents", {
				glfwPollEvents();
			});

			// poll gsb events for current frame + dispatch to all active UIComponents.
			// This effectively drives the entire application.
			threadStats.timedCall("UIComponents.update", {
				UIComponentManager.updateFromMainThread();
			});

			// Run textrenderer updates on any modified state. Does stuff like re-rasterize + repack
			// font glyphs and generate text geometry to be fed to the cpu. Includes tasks that we
			// don't want bottlenecking the graphics thread; could be moved to a worker thread.
			threadStats.timedCall("TextRenderer.update", {
				TextRenderer.instance.updateFragments();
			});

			// Notify graphics thread that it can begin processing the next frame. 
			send(graphicsThreadId, ThreadSyncEvent.NOTIFY_NEXT_FRAME);

			threadStats.timedCall("dumpStats", {
				dumpAllStats();
			});
		});

		// Wait for next frame or some other synchronized message (gthread terminated with
		// an exception, for example). Note: this is super-crappy synchronization, but we
		// won't change it until / if it's determined to be a performance problem.
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
	}

	log.write("Killing graphics thread");
	prioritySend(graphicsThreadId, ThreadSyncEvent.NOTIFY_SHOULD_DIE);

	// kill all running components (note: usually this doesn't do much, since component updates are dependent on the event loop)
	UIComponentManager.shutdown();
	{
		ThreadSyncEvent evt;
		while ((evt = receiveOnly!(ThreadSyncEvent)()) != ThreadSyncEvent.NOTIFY_THREAD_DIED) {
			writefln("[main-thread] Waiting on thread kill event (recieved %d)", evt);
		}
	}
gthreadDied:
}
void enterMainThread (Tid graphicsThreadId) {

	log.write("ENTERING MAIN THREAD");
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
	//log = g_mainLog = new Log("main-thread");
	log.write("launching gsb");

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

	// And then hand our gl context off to the graphics thread (via the __gshared window handle)
	auto gthreadHandle = spawn(&enterGraphicsThread, thisTid);

	// We'll finish initializing and run our control + event code on the main thread, but opengl
	// access is confined _strictly_ to the graphics thread.

	try {
		enterMainThread(gthreadHandle);
	} catch (Throwable e) {
		writeln(e);
	}

	// App shutdown code
	// Note: the main thread terminates iff
	// - app exits normally (cmd+q / window closed / etc)
	// - main thread threw an exception and must terminate
	// - a critical / core thread (like the graphics thread) threw an exception and terminated.
	//
	// In the first two cases, mainThread / enterMainThread will kill all worker threads and wait
	// for confirmation before returning
	//
	log.write("Shutting down");
	glfwDestroyWindow(g_mainWindow.handle);
	glfwTerminate();
}