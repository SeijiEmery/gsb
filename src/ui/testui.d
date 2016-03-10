
module gsb.ui.testui;

import gsb.gl.debugrenderer;
import gsb.core.window;
import gsb.core.pseudosignals;
import gsb.core.log;
import gsb.core.uimanager;

import gl3n.linalg;
import gsb.glutils;
import gsb.core.color;
import Derelict.glfw3.glfw3;

this () {
    UIComponentManager.registerComponent(new UITestModule(), "uiTestModule", true);
}

class UITestModule : UIComponent {
    auto lastPos = vec2(0, 0);
    float size = 50.0;
    vec2[] points;
    int lineSamples = 1;
    Color triangleColor = Color("#fadd4c");

    override void onComponentInit () {}
    override void onComponentShutdown () {}

    private void increaseLineSamples () {
        lineSamples += 1;
        log.write("Set line samples = %d", lineSamples);
    }
    private void decreaseLineSamples () {
        if (lineSamples > 0) {
            lineSamples -= 1;
            log.write("Set line samples = %d", lineSamples);
        }
    }
    override void handleEvent (UIEvent event) {
        event.tryVisit!(
            (MouseButtonEvent ev) => {
                if (btn.isLMB && btn.released)
                    points ~= Mouse.cursorPosition;
            },
            (KeyboardEvent key) => {
                if (key.keystr == "+") increaseLineSamples();
                if (key.keystr == "-") decreaseLineSamples();
            },
            (ScrollEvent scroll) => size += scroll.y,
            (GamepadButtonEvent ev) => {
                if (ev.button == GamepadButton.A) increaseLineSamples();
                if (ev.button == GamepadButton.B) decreaseLineSamples();
            },
            //(GamepadAxisEvent ev) => {
            //    if (ev.AXIS_LX || ev.AXIS_LY)
            //        panCamera(vec2(ev.AXIS_LX, ev.AXIS_RY) * cameraMoveSpeed);
            //    if (ev.AXIS_RY)
            //        zoomCamera(ev.AXIS_RY * cameraZoomSpeed);
            //},
            (FrameUpdateEvent frame) => {
                triangleColor.r += frame.dt * 0.5;
                if (triangleColor.r > 1.0) triangleColor.r -= 1.0;

                DebugRenderer.drawTri(lastPos, triangleColor, size, cast(float)lineSamples);

                if (points.length) {
                    if (points[$-1] != lastPos)
                        DebugRenderer.drawLines(points ~ [lastPos], Color("#e37f2d"), 0.1 * size, lineSamples);
                    else
                        DebugRenderer.drawLines(points, Color("#e37f2d"), 0.1 * size, cast(float)lineSamples);
                }
            }
        );
    }

    /+ Note: maybe in the future we could do something like this: 

    class UITestModule : UIComponent

    events.connect(MouseButtons.LEFT, KeyboardModifiers.ANY)({
        points ~= lastPos;
    });

    events.connect(MouseButtons.LEFT, Button.PRESSED, KeyboardModifiers.ANY)({
        
    });
    events.connect(MouseButtons.RIGHT, Button.EACH_SECOND(0.1), KeyboardModifiers.ANY)({
    
    })





    events.connect(MouseMoved)({
        
    })


    
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

    
}







































