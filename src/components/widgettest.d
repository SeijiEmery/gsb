
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
    float fontSize = 30.0;

    override void onComponentInit () {
        root = new UIDecorators.Draggable!UITextElement(
            vec2(300, 400), vec2(200, 100), "Hello World!", new Font(FONT, fontSize), Color("#affa10"), Color("#feefde"));
    }
    override void onComponentShutdown () {}
    override void handleEvent (UIEvent event) {
        event.handle!(
            (FrameUpdateEvent ev) {
                root.doLayout();
                root.render();
            },
            () {
                root.handleEvents(event);
            }
        )();
    }
}











