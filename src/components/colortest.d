
module gsb.components.colortest;
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
        UIComponentManager.registerComponent(new TestModule(), "colorTest", true);
    });
}

private class TestModule : UIComponent {
    UIElement root;
    UILayoutContainer inner;

    UIBox cbox;
    UITextElement ctext;

    UISlider[4] sliders;
    float fontSize = 30.0;

    override void onComponentInit () {
        auto SLIDER_COLOR     = Color(0.8, 0.6, 0.6, 0.5);
        auto BACKGROUND_COLOR = Color(0.5, 0.7, 0.5, 0.5);

        root = new UIDecorators.Draggable!UILayoutContainer(
            RelLayoutDirection.HORIZONTAL, RelLayoutPosition.CENTER,
            vec2(200, 100), vec2(0, 0), vec2(10, 12), cast(UIElement[])[
                //new UILayoutContainer(RelLayoutDirection.VERTICAL, RelLayoutPosition.CENTER, vec2(), vec2(), vec2(10, 10), cast(UIElement[])[
                    cbox = new UIBox(vec2(0,0), vec2(200,180), Color(1,0,0,1)),
                    ctext = new UITextElement(vec2(), vec2(), vec2(10,10), "Color Demo", new Font(FONT, fontSize), Color(1,0,0,1), Color(1,0,0,1)),
                //]),
                new UILayoutContainer(
                    RelLayoutDirection.VERTICAL, RelLayoutPosition.CENTER,
                    vec2(0,0), vec2(0,0), vec2(10,10), cast(UIElement[])[
                        sliders[0] = new UISlider(vec2(), vec2(300,40), vec2(5,5), vec2(40,30), 1, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),
                        sliders[1] = new UISlider(vec2(), vec2(300,40), vec2(5,5), vec2(40,30), 0, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),
                        sliders[2] = new UISlider(vec2(), vec2(300,40), vec2(5,5), vec2(40,30), 0, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),
                        sliders[3] = new UISlider(vec2(), vec2(300,40), vec2(5,5), vec2(40,30), 1, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),
                    ])
            ]);
    }
    override void onComponentShutdown () {
        if (root) {
            root.release();
            root = null;
        }
    }

    override void handleEvent (UIEvent event) {
        if (!root)
            return;
        event.handle!(
            (FrameUpdateEvent ev) {
                root.recalcDimensions();
                root.doLayout();

                auto color = Color(sliders[0].value, sliders[1].value, sliders[2].value, sliders[3].value);
                cbox.color = color;
                ctext.color = color;
                ctext.backgroundColor = color;
                ctext.text = format("Color Demo\n(%0.2f,%0.2f,%0.2f,%0.2f)", color.r, color.g, color.b, color.a);

                root.render();
            },
            () {
                root.handleEvents(event);
            }
        )();
    }
}











