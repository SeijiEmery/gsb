
module gsb.components.colortest;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.window;
import gsb.core.color;
import gsb.text.textrenderer;
import gsb.text.font;
import gsb.core.colorutils;

import gsb.core.ui.uielements;

import gl3n.linalg;

private immutable string FONT = "menlo";

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new TestModule(), "color-test", true);
    });
}

enum ColorType { RGB, HSL, HSV };

private class TestModule : UIComponent {
    UIElement root;
    UILayoutContainer inner;

    UIBox cbox;
    UITextElement ctext;

    UITextElement[ColorType] buttons;

    UISlider[4] sliders;
    float fontSize = 30.0;

    auto ACTIVE_BUTTON_COLOR = Color(1.0, 1.0, 0.8, 1);
    auto INACTIVE_BUTTON_COLOR = Color(0.8, 0.8, 0.8, 1);

    auto inputType = ColorType.RGB;

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
                        //new UILayoutContainer(RelLayoutDirection.HORIZONTAL, RelLayoutPosition.CENTER, vec2(), vec2(), vec2(10,10), cast(UIElement[])[
                            buttons[ColorType.RGB] = new UITextElement(vec2(),vec2(),vec2(3,3), "RGB", new Font(FONT,fontSize), ACTIVE_BUTTON_COLOR, INACTIVE_BUTTON_COLOR),
                            buttons[ColorType.HSV] = new UITextElement(vec2(),vec2(),vec2(3,3), "HSV", new Font(FONT,fontSize), INACTIVE_BUTTON_COLOR, INACTIVE_BUTTON_COLOR),
                            buttons[ColorType.HSL] = new UITextElement(vec2(),vec2(),vec2(3,3), "HSL", new Font(FONT,fontSize), INACTIVE_BUTTON_COLOR, INACTIVE_BUTTON_COLOR),
                        //]),
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

                string fmtVec (vec4 v) { return format("(%0.2f,%0.2f,%0.2f,%0.2f)", v.x, v.y, v.z, v.w); }

                auto color = vec4(sliders[0].value, sliders[1].value, sliders[2].value,sliders[3].value);
                if (inputType == ColorType.HSV)      color = vec4(hsv_to_rgb(color.xyz), color.w);
                else if (inputType == ColorType.HSL) color = vec4(hsl_to_rgb(color.xyz), color.w);

                auto color_ = Color(color);
                cbox.color  = color_;
                ctext.color = color_;
                ctext.backgroundColor = color_;

                ctext.text = format("Color Demo\nrgb: %s\nhsv: %s\nrgb2: %s\n", 
                    fmtVec(color),
                    fmtVec(vec4(rgb_to_hsv(color.xyz), color.w)),
                    fmtVec(vec4(rgb_to_hsv(color.xyz).hsv_to_rgb, color.w)));
                root.render();
            },
            (MouseButtonEvent ev) {
                if (ev.pressed && (buttons[ColorType.RGB].mouseover || buttons[ColorType.HSV].mouseover)) {
                    auto color = vec4(sliders[0].value, sliders[1].value, sliders[2].value, sliders[3].value);
                    if (buttons[ColorType.RGB].mouseover && inputType != ColorType.RGB) {
                        final switch (inputType) {
                            case ColorType.HSV: color = vec4(hsv_to_rgb(color.xyz), color.w); break;
                            case ColorType.HSL: color = vec4(hsl_to_rgb(color.xyz), color.w); break;
                            case ColorType.RGB: break;
                        }
                        buttons[inputType].color = INACTIVE_BUTTON_COLOR;
                        buttons[inputType = ColorType.RGB].color = ACTIVE_BUTTON_COLOR;
                    } else if (buttons[ColorType.HSV].mouseover && inputType != ColorType.HSV) {
                        final switch (inputType) {
                            case ColorType.RGB: color = vec4(rgb_to_hsv(color.xyz), color.w); break;
                            case ColorType.HSL: color = vec4(rgb_to_hsv(hsl_to_rgb(color.xyz)), color.w); break;
                            case ColorType.HSV: break;
                        }
                        buttons[inputType].color = INACTIVE_BUTTON_COLOR;
                        buttons[inputType = ColorType.HSV].color = ACTIVE_BUTTON_COLOR;
                    }
                    sliders[0].value = color.x;
                    sliders[1].value = color.y;
                    sliders[2].value = color.z;
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











