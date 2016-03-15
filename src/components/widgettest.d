
module gsb.components.widgettest;
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

private immutable string FONT = "menlo";

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new TestModule(), "widgetTest", true);
    });
}

private class TestModule : UIComponent {
    UIElement root;
    UILayoutContainer inner;

    float fontSize = 30.0;

    override void onComponentInit () {
        root = new UIDecorators.Draggable!UILayoutContainer(
            RelLayoutDirection.VERTICAL, RelLayoutPosition.CENTER_TOP,
            vec2(200, 300), vec2(400, 600), vec2(10, 12), [
                cast(UIElement)(new UITextElement(
                    vec2(300, 400), vec2(200, 100), "Hello World!", 
                    new Font(FONT, fontSize), Color("#affa10"), Color("#feefde"))),
                inner = new UILayoutContainer(
                    RelLayoutDirection.HORIZONTAL, RelLayoutPosition.CENTER_TOP,
                    vec2(0, 0), vec2(0, 0), vec2(5, 5), [
                        cast(UIElement)(new UITextElement(
                            vec2(300, 400), vec2(200, 100), "Foo", 
                            new Font(FONT, fontSize), Color("#affa10"), Color("#feefde"))),
                        new UITextElement(
                            vec2(300, 400), vec2(200, 100), "bar", 
                            new Font(FONT, fontSize), Color("#affa10"), Color("#feefde")),
                    ])
            ]);
    }
    override void onComponentShutdown () {}
    override void handleEvent (UIEvent event) {
        event.handle!(
            (FrameUpdateEvent ev) {
                root.recalcDimensions();
                root.doLayout();
                root.render();
            },
            (MouseButtonEvent ev) {
                if (ev.pressed && ev.isRMB) {
                    auto x = cast(UIDecorators.Draggable!UILayoutContainer)root;
                    if (ev.shift) {
                        x.relPosition = cast(RelLayoutPosition)((x.relPosition + 1) % 9);
                        inner.relPosition = cast(RelLayoutPosition)((inner.relPosition + 1) % 9);
                    } else {
                        x.relDirection = cast(RelLayoutDirection)((x.relDirection + 1) % 2);
                        inner.relDirection = cast(RelLayoutDirection)((inner.relDirection + 1) % 2);
                        x.dim = inner.dim = vec2(0, 0);
                    }
                    log.write("set to %s, %s", x.relDirection, x.relPosition);
                } else {
                    root.handleEvents(event);
                }
            },
            () {
                root.handleEvents(event);
            }
        )();
    }
}











