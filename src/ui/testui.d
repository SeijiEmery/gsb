
module gsb.ui.testui;

import gsb.gl.debugrenderer;
import gsb.core.window;
import gsb.core.pseudosignals;
import gsb.core.log;

import gl3n.linalg;
import gsb.glutils;
import gsb.core.color;
import Derelict.glfw3.glfw3;


class UITestModule {
    auto lastPos = vec2(0, 0);
    float size = 50.0;
    vec2[] points;

    int lineSamples = 1;

    ISlot[] slots;
    struct KeyHandler { int key, allMods, anyMods; void delegate() cb; }
    KeyHandler[] keyHandlers;

    private void setup () {
        disconnectAllSlots();

        int GLFW_MOD_ANY = GLFW_MOD_SHIFT | GLFW_MOD_CONTROL | GLFW_MOD_ALT | GLFW_MOD_SUPER;
        void onMouseMoved (void delegate(vec2) cb) {
            slots ~= g_mainWindow.onMouseMoved.connect(cb);
        }
        void onMouseButtonPressed (int buttonMask, int allMods, int anyMods, void delegate() cb) {
            slots ~= g_mainWindow.onMouseButtonPressed.connect((Window.MouseButton evt) {
                if (evt.button & buttonMask && (evt.mods == allMods || evt.mods & anyMods)) { cb(); }
            });
        }
        void onScroll (void delegate(vec2) cb) {
            slots ~= g_mainWindow.onScrollInput.connect(cb);
        }
        keyHandlers.length = 0;
        slots ~= g_mainWindow.onKeyPressed.connect((Window.KeyPress evt) {
            foreach (handler; keyHandlers) {
                if (evt.key == handler.key && (evt.mods == handler.allMods || evt.mods & handler.anyMods))
                    handler.cb();
            }
        });
        void onKeyPressed (int key, int allMods, int anyMods, void delegate() cb) {
            keyHandlers ~= KeyHandler(key, allMods, anyMods, cb);
        }
        void onGamepadAxes (void delegate(float[]) cb) {
            slots ~= g_mainWindow.onGamepadAxesUpdate.connect(cb);
        }

        onMouseMoved((vec2 pos) {
            lastPos = pos;
        });
        onMouseButtonPressed(GLFW_MOUSE_BUTTON_LEFT, 0, GLFW_MOD_ANY, {
            points ~= lastPos;
        });
        // '+' button (shift+'+'): increase line samples, '-' button: decrease samples
        onKeyPressed('=', GLFW_MOD_SHIFT, 0, {
            lineSamples += 1; log.write("Set lineSamples = %d", lineSamples);
        });
        onKeyPressed('-', 0, GLFW_MOD_SHIFT, {
            lineSamples = max(lineSamples-1, 0); log.write("Set lineSamples = %d", lineSamples);
        });
        onScroll((vec2 scroll) { size += scroll.y; });
    }

    /+ Note: maybe in the future we could do something like this: 

    class UITestModule : UIComponent
    
    this () {
        UIManager.setupOnce(this, events => {
            events.onMouseMoved( pos => lastPos = pos );
            events.onPressed ( MouseButtons.LEFT, KeyboardModifiers.ANY, => {
                points ~= lastPos;
            });
            events.onPressed ( Keys.ascii('+'), PressDuration.every(0.1), => {
                lineSamples += 1;
                log.write("Set lineSamples = %d", lineSamples);
            });
            events.onPressed ( Keys.ascii('-'), PressDuration.every(0.1), => {
                if (lineSamples > 0) {
                    lineSamples -= 1;
                    log.write("Set lineSamples = %d", lineSamples);
                }
            });
            events.onScroll (scroll => size += scroll.y);
        });
    }
    ~this () {
        UIManager.unbindEvents(this);
    }

    class AppController : BaseAppController {
        void init () {
            //UI.createComponent!UITestModule();
            UI.registerComponents!(UITestModule);
            
            // enable / disable components
            UI.setActive("UITestModule", false);
            UI.setActive("UITestModule", true);

            // iter components
            foreach (component; UI.components) {
                if (component.name == "UITestModule")
                    component.setActive(true);        // equivalent
            }
        }
    }

    void mainThread () {
        // ...
    
        auto stats      = new StatsCollector(STATS_METACATEGORY_MAINTHREAD);  
        auto controller = new AppController();
        auto uiworker   = new UIWorker();
        auto textRenderer = new TextRenderer();
        auto graphicsworker = new GraphicsWorker();

        // stats.timeIt("Initializing", {
        //    appController = new AppController();    
        // });

        while (...) {
            case PREPARE_NEXT_FRAME: {
                stats.beginFrame();
                stats.collectPerFrame(controller,     => controller.update());
                stats.collectPerFrame(uiworker,       => uiworker.update());
                stats.collectPerFrame(textRenderer,   => textRenderer.update());
                stats.collectPerFrame(graphicsworker, => graphicsWorker.update());
                stats.endFrame();

                send(graphicsThreadId, ThreadSyncEvent.NOTIFY_NEXT_FRAME);
                goto nextFrame;
            } break;

        nextFrame:
        }

        controller.shutdown();
    }

    class StatsCollector {
        final void collectPerFrame (T)(T _, delegate(void) stuff) {
            frameStats[fullyQualifiedName!T] = timeit(stuff);
        }
        final void endFrame () {
            presentStats(frameStats);
            foreach (k; frameStats.keys)
                frameStats[k] = typeof(frameStats[k]).init;
        }
    }
    +/

    private void disconnectAllSlots () {
        if (slots.length) {
            foreach (slot; slots)
                slot.disconnect();
            slots.length = 0;
        }
    }
    this () {
        setup();
    }
    ~this () {
        disconnectAllSlots();
    }

    void update () {
        DebugRenderer.drawTri(lastPos, Color("#fadd4c"), size, cast(float)lineSamples);

        if (points.length) {
            //foreach (point; points) {
            //    DebugRenderer.drawTri(point, Color(0.0, 1.0, 0.0), 10);
            //}

            // vec2[2] nextSeg = [ points[$-1], lastPos ];
            //DebugRenderer.drawLines(nextSeg, Color("#90cc80"), 15);

            //DebugRenderer.drawLines([ points[$-1], lastPos ], Color("#e80202"), 0.1 * size);
            if (points[$-1] != lastPos)
                DebugRenderer.drawLines(points ~ [lastPos], Color("#e37f2d"), 0.1 * size, lineSamples);
            else
                DebugRenderer.drawLines(points, Color("#e37f2d"), 0.1 * size, cast(float)lineSamples);
        }
    }
}







































