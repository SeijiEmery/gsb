
module gsb.components.collisiontest;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.window;
import gsb.core.color;
import gsb.text.textrenderer;
import gsb.text.font;

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
    abstract void onInit ();
    abstract void onTeardown ();
    abstract void draw ();
    abstract bool handleEvent (UIEvent);
}

private class TestModule : UIComponent {
    UIElement root;

    UITextElement[string] buttons;
    SubModule[string] modules;
    SubModule activeModule = null;

    immutable auto UI_BACKGROUND_COLOR = Color(0.0, 0.65, 0.65, 0.55);
    immutable auto UI_BORDER_COLOR     = Color(0.25, 0.25, 0.25, 0.85);
    immutable auto UI_TEXT_COLOR       = Color(1.0, 1.0, 1.0, 0.95);
    immutable float BORDER_WIDTH = 2.0;

    immutable auto ACTIVE_BTN_COLOR = Color(1.0, 0.0, 0.0, 0.80);
    immutable auto INACTIVE_BTN_COLOR = Color(0.0, 1.0, 0.0, 0.80);

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
        modules["Point-rect test"]   = new PointRectTest();
        activateModule(modules["point-circle test"]);

        auto font = new Font(FONT, fontSize);
        foreach (k, v; modules)
            buttons[k] = new UITextElement(vec2(), vec2(), vec2(BUTTON_BORDER, BUTTON_BORDER + BUTTON_SPACING), k, font, UI_TEXT_COLOR, UI_TEXT_COLOR);

        auto contents = [
            new UITextElement(vec2(), vec2(), vec2(BUTTON_BORDER, BUTTON_BORDER + BUTTON_SPACING), "CollisionTest", font, UI_TEXT_COLOR, UI_TEXT_COLOR)
        ];
        contents ~= buttons.values();


        root = new UIDecorators.Draggable!UILayoutContainer(
            RelLayoutDirection.VERTICAL, RelLayoutPosition.TOP_LEFT,
            vec2(20, 20), vec2(0, 0), vec2(10, 10), cast(UIElement[])contents);
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


class PointCircleTest : SubModule {
    override void onInit () {}
    override void onTeardown () {}
    override void draw () {}
    override bool handleEvent (UIEvent event) { return false; }
}
class PointRectTest : SubModule {
    override void onInit () {}
    override void onTeardown () {}
    override void draw () {}
    override bool handleEvent (UIEvent event) { return false; }
}








