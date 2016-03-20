
module gsb.components.collisiontest;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.window;
import gsb.core.color;
import gsb.text.textrenderer;
import gsb.text.font;
import gsb.core.collision2d;

import gsb.core.ui.uielements;

import gl3n.linalg;

import std.algorithm;

private immutable string FONT = "menlo";

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new TestModule(), "collision-test", true);
    });
}

class SubModule {
    public bool isActive = false;
    void onInit () {}
    void onTeardown () {}
    void draw () {}
    bool handleEvent (UIEvent) { return false; }
}

private class TestModule : UIComponent {
    UIElement root;

    UITextElement[string] buttons;
    SubModule[string] modules;
    SubModule activeModule = null;

    immutable auto UI_BACKGROUND_COLOR = Color(0.95, 0.95, 0.95, 0.10);
    immutable auto UI_BORDER_COLOR     = Color(0.25, 0.25, 0.25, 1.0);
    immutable auto UI_TEXT_COLOR       = Color(1.0, 1.0, 1.0, 0.95);
    immutable float BORDER_WIDTH = 2.0;

    immutable auto ACTIVE_BTN_COLOR   = Color(1.0, 0.0, 0.0, 0.80);
    immutable auto INACTIVE_BTN_COLOR = Color(0.25, 0.25, 0.25, 0.80);

    immutable float BUTTON_BORDER  = 2.0;
    immutable float BUTTON_SPACING = 4.0;

    float fontSize = 18.0;

    void activateModule (SubModule newModule) {
        if (newModule != activeModule) {
            if (activeModule) {
                activeModule.onTeardown();
                activeModule.isActive = false;
            }
            if (newModule) {
                newModule.onInit();
                newModule.isActive = true;
            }
            activeModule = newModule;
        }
    }

    override void onComponentInit () {
        modules["point-circle test"] = new PointCircleTest();
        modules["point-rect test"]   = new PointRectTest();
        modules["point-line test"]   = new PointLineTest();
        modules["line-circle test"]  = new LineCircleTest();
        activateModule(modules.values()[0]);

        auto font = new Font(FONT, fontSize);
        foreach (k, v; modules)
            buttons[k] = new UITextElement(vec2(), vec2(), vec2(BUTTON_BORDER, BUTTON_BORDER + BUTTON_SPACING), k, font, UI_TEXT_COLOR, UI_TEXT_COLOR);

        auto contents = [
            new UITextElement(vec2(), vec2(), vec2(BUTTON_BORDER, BUTTON_BORDER + BUTTON_SPACING), "CollisionTest", font, UI_TEXT_COLOR, UI_TEXT_COLOR)
        ];
        contents ~= buttons.values();


        root = new UIDecorators.Draggable!UILayoutContainer(LayoutDir.VERTICAL, Layout.TOP_LEFT,
            vec2(20, 20), vec2(0, 0), vec2(10, 10), 0.0, cast(UIElement[])contents);
    }
    override void onComponentShutdown () {
        if (root) {
            root.release();
            root = null;

            activateModule(null);
            foreach (k, v; modules)
                modules.remove(k);
        }
    }

    override void handleEvent (UIEvent event) {
        if (!root)
            return;
        event.handle!(
            (FrameUpdateEvent ev) {
                // force root container to be clamped to min size of its contents (ie. grows / shrinks accordingly)
                root.dim.x = root.dim.y = 0;   

                // Do relayouting, etc
                root.recalcDimensions();
                root.doLayout();

                // Calculate max button size and adjust all buttons to be the same width
                auto buttonWidth = reduce!"max(a, b.dim.x)"(0f, buttons);
                foreach (k, v; buttons)
                    v.dim.x = buttonWidth;

                // Render _manually_ (bypassing uielement.draw()):

                // Draw container w/ background + border
                DebugRenderer.drawRect(root.pos, root.pos     + root.dim, UI_BACKGROUND_COLOR);
                DebugRenderer.drawLineRect(root.pos, root.pos + root.dim, UI_BORDER_COLOR, BORDER_WIDTH);

                // Draw elements w/ manual spacing as background + border
                immutable auto offset = vec2(0, BUTTON_SPACING);
                foreach (k, v; buttons) {
                    DebugRenderer.drawRect(v.pos + offset, v.pos + v.dim - offset, modules[k].isActive ? ACTIVE_BTN_COLOR : INACTIVE_BTN_COLOR);
                }
                if (activeModule)
                    activeModule.draw();
                return true;
            },
            (MouseButtonEvent ev) {
                if (ev.pressed && ev.isLMB) {
                    foreach (k, v; buttons) {
                        if (v.mouseover) {
                            activateModule(modules[k]);
                            return true;
                        }
                    }
                }
                root.handleEvents(event);
                return false;
            },
            (ScrollEvent ev) {
                if (root.mouseover) {
                    fontSize += ev.dir.y;
                    foreach (k, v; buttons) {
                        v.fontSize = fontSize;
                    }
                    return true;
                }
                root.handleEvents(event);
                return false;
            },
            () {
                root.handleEvents(event);
                return false;
            }
        ) || (activeModule && activeModule.handleEvent(event));
    }
}

@property auto screenCenter () { return 0.5 * vec2(g_mainWindow.screenDimensions); }
float LINE_SAMPLES = 0;
auto immutable INACTIVE_COLOR = Color(0.35, 0.35, 0.35, 1.0);
auto immutable COLOR_RED     = Color(1, 0, 0, 1.0);
auto immutable COLOR_GREEN   = Color(0, 1, 0, 1.0);
auto immutable COLOR_BLUE    = Color(0.2, 0.2, 1, 1.0);
auto immutable COLOR_CYAN    = Color(0, 1, 1, 1.0);
auto immutable COLOR_MAGENTA = Color(1, 0, 1, 1.0);
auto immutable COLOR_ORANGE  = Color(1, 0.8, 0, 1.0);

import std.range: cycle;

//immutable Color[6] _COLORS = ;
auto immutable COLORS = cycle([ COLOR_RED, COLOR_GREEN, COLOR_BLUE, COLOR_CYAN, COLOR_MAGENTA, COLOR_ORANGE ]);



class IShape {
    abstract void draw (Color color, float lineWidth);
}

class Shape(T) : IShape {
    T shape;
    this (Args...)(Args args) {
        shape = T(args);
    }
    override void draw (Color color, float lineWidth) {
        draw(shape, color, lineWidth);
    }
}

void drawShape (Collision2d.Circle circle, Color color, float lineWidth) {
    uint numPoints = 80;
    DebugRenderer.drawCircle(circle.center, circle.radius - lineWidth, color, lineWidth, numPoints, LINE_SAMPLES);
}
void drawShape (Collision2d.LineSegment line, Color color, float lineWidth) {

    DebugRenderer.drawLines( [ line.p1, line.p2 ], color, line.width, LINE_SAMPLES );

    // draw ends
    uint numPoints = 80;
    DebugRenderer.drawCircle(line.p1, line.width - lineWidth, color, lineWidth, numPoints, LINE_SAMPLES);
    DebugRenderer.drawCircle(line.p2, line.width - lineWidth, color, lineWidth, numPoints, LINE_SAMPLES);
}




//class AABBShape : Shape {
//    Collision2d.AABB box;
//    this (Collision2d.AABB box, vec2 pos, Color color) { this.box = box; super(pos, color); }

//    override void draw (float lineWidth) {
//        DebugRenderer.drawLineRect(box.p1, box.p2, color, lineWidth, LINE_SAMPLES);
//    }
//}
//class OBBShape : Shape {
//    Collision2d.OBB box;
//    this (Collision2d.OBB box, vec2 pos, Color color) { this.box = box; super(pos, color); }

//    override void draw (float lineWidth) {
//        throw new Exception("Unimplemented!");
//        //DebugRenderer.drawPolygon(points..., color, lineWidth, LINE_SAMPLES);
//    }
//}
//class CircleShape : Shape {
//    Collision2d.Circle circle;
//    this (Collision2d.Circle circle, vec2 pos, Color color) { this.circle = circle; super(pos, color); }

//    override void draw (float lineWidth) {
//        uint numPoints = 80;
//        DebugRenderer.drawCircle(circle.center, circle.radius, color, lineWidth, numPoints, LINE_SAMPLES);
//    }
//}
//class LineSegmentShape : Shape {
//    Collision2d.LineSegment line;
//    this (Collision2d.LineSegment line, vec2 pos, Color color) { this.line = line; super(pos, color); }

//    override void draw (float lineWidth) {
//        DebugRenderer.drawLines([ line.p1, line.p2 ], color, line.width, LINE_SAMPLES);
//    }
//}
//class PolyLineShape : Shape {
//    Collision2d.PolyLine line;
//    this (Collision2d.PolyLine line, vec2 pos, Color color) { this.line = line; super(pos, color); }

//    override void draw (float lineWidth) {
//        DebugRenderer.drawLines(line.points, color, line.width, LINE_SAMPLES);
//    }
//}

class PointCircleTest : SubModule {
    Collision2d.Circle circle;
    //Shape!(Collision2d.Circle) circle;
    vec2 mousePos = vec2(0,0);

    override void onInit () {
        circle = Collision2d.Circle( screenCenter, 50.0 );
        //circle = new Shape!Collision2d.Circle( screenCenter, 50.0 );
    }
    override void onTeardown () {
        //circle = null;
    }
    override void draw () {
        drawShape ( circle, Collision2d.intersects(circle, mousePos) ? COLOR_RED : INACTIVE_COLOR, 1 );
    }
    override bool handleEvent (UIEvent event) {
        event.handle!(
            (MouseMoveEvent ev) {
                mousePos = ev.position;
            },
            () {}
        );
        return false;
    }
}
class PointRectTest : SubModule {
    override void onInit () {}
    override void onTeardown () {}
    override void draw () {}
    override bool handleEvent (UIEvent event) { return false; }
}

class PointLineTest : SubModule {
    Collision2d.LineSegment line;
    vec2 mousePos;

    override void onInit () {
        line = Collision2d.LineSegment( screenCenter - vec2(200, 200), screenCenter + vec2(200, 200), 50 );
    }
    override void draw () {
        auto color = Collision2d.intersects(line, mousePos) ? COLOR_RED : INACTIVE_COLOR;
        drawShape(line, color, 1);
    }
    override bool handleEvent (UIEvent event) {
        event.handle!((MouseMoveEvent ev) { mousePos = ev.position; }, () {});
        return false;
    }
}

class LineCircleTest : SubModule {
    Collision2d.Circle circle;
    Collision2d.LineSegment line;

    override void onInit () {
        line = Collision2d.LineSegment( vec2(900, 600), vec2(0, 0), 10 );
        circle = Collision2d.Circle ( screenCenter, 100 );
    }
    override void draw () {
        auto hit = Collision2d.intersects(circle, line);

        drawShape(line, hit ? COLOR_GREEN : INACTIVE_COLOR, 1);
        drawShape(circle, hit ? COLOR_RED : INACTIVE_COLOR, 1);
    }
    override bool handleEvent (UIEvent event) {
        event.handle!(
            (MouseMoveEvent ev) { line.p2 = ev.position; }, 
            (MouseButtonEvent ev) { if (ev.pressed) line.p1 = line.p2; },
            (){});
        return false;
    }
}











