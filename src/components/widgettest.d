
module gsb.components.widgettest;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.window;
import gsb.utils.color;
import gsb.text.textrenderer;
import gsb.text.font;

import gsb.core.ui.uielements;

import gl3n.linalg;

private immutable string FONT = "menlo";

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new TestModule(), "widgetTest", false);
    });
}

private class TestModule : UIComponent {
    UIElement root;
    UILayoutContainer inner;

    UITextElement text1, text2, text3;


    float fontSize = 30.0;

    override void onComponentInit () {
        root = new UIDecorators.Draggable!UILayoutContainer(
            LayoutDir.VERTICAL, Layout.TOP_CENTER,
            vec2(200, 300), vec2(400, 600), vec2(10, 12), 0.0, cast(UIElement[])[
                text1 = new UITextElement(
                    vec2(300, 400), vec2(200, 100), vec2(5,5), "Hello World!", 
                    new Font(FONT, fontSize), Color(1f,1f,0f,1f), Color("#feefde")),
                inner = new UILayoutContainer(
                    LayoutDir.HORIZONTAL, Layout.TOP_CENTER,
                    vec2(0, 0), vec2(0, 0), vec2(5, 5), 0.0, cast(UIElement[])[
                        text2 = new UITextElement(
                            vec2(300, 400), vec2(200, 100), vec2(5,5), "Foo", 
                            new Font(FONT, fontSize), Color("#00fe00fe"), Color("#feefde")),
                        text3 = new UITextElement(
                            vec2(300, 400), vec2(200, 100), vec2(5,5), "bar", 
                            new Font(FONT, fontSize), Color("#0000fefe"), Color("#feefde")),
                    ])
            ]);
    }
    override void onComponentShutdown () {}

    enum { RED, GREEN, BLUE, ALPHA };
    int cc = RED;

    override void handleEvent (UIEvent event) {
        event.handle!(
            (FrameUpdateEvent ev) {
                root.recalcDimensions();
                root.doLayout();
                root.render();
            },
            (MouseButtonEvent ev) {
                if (root.mouseover && ev.pressed && ev.isRMB) {
                    auto x = cast(UIDecorators.Draggable!UILayoutContainer)root;
                    if (!ev.shift) {
                        x.layout     = nextLayout(x.layout);
                        inner.layout = nextLayout(inner.layout);
                    } else {
                        x.direction = cast(LayoutDir)((x.direction + 1) % 2);
                        inner.direction = cast(LayoutDir)((inner.direction + 1) % 2);
                        x.dim = inner.dim = vec2(0, 0);
                    }
                    log.write("set to %s, %s", x.direction, x.layout);
                } else if (root.mouseover && ev.pressed && ev.isLMB) {
                    cc = (cc + 1) % 4;
                    root.handleEvents(event);
                } else {
                    root.handleEvents(event);
                }
            },
            (ScrollEvent ev) {

                log.write("scroll");
                if (root.mouseover) {
                    float clamp (float x, float n, float m) {
                        return max(min(x, m), n);
                    }
                    void adjustColor (UITextElement elem) {
                        if (elem.mouseover) {
                            log.write("ac?");

                            auto delta = ev.dir.y * 0.05;
                            elem.color = Color(
                                cc == RED   ? clamp(elem.color.r + delta, 0f, 1f) : elem.color.r,
                                cc == BLUE  ? clamp(elem.color.r + delta, 0f, 1f) : elem.color.r,
                                cc == GREEN ? clamp(elem.color.r + delta, 0f, 1f) : elem.color.r,
                                cc == ALPHA ? clamp(elem.color.r + delta, 0f, 1f) : elem.color.r
                            );
                            log.write("set color %s", elem.color);
                        }
                    }

                    adjustColor(text1);
                    adjustColor(text2);
                    adjustColor(text3);
                }
            },
            () {
                root.handleEvents(event);
            }
        )();
    }
}











