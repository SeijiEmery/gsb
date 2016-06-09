module gsb.components.colortest;
import gsb.core.slate2d;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.window;
import gsb.utils.color;
import gsb.text.textrenderer;
import gsb.text.font;
import gsb.core.ui.uielements;
import gl3n.linalg;
import std.format;
import std.algorithm: min, max;
import gsb.utils.husl;

private immutable string FONT = "menlo";

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new TestModule(), "color-test", true);
    });
}

enum ColorType { RGB, HSV, HUSL };

private class TestModule : UIComponent {
    UIElement root;
    UILayoutContainer inner;

    UIBox cbox;
    UITextElement ctext, cstats;

    UITextElement[ColorType] buttons;

    UISlider[4] sliders;
    float fontSize = 22.0;
    float smallFontSize = 16.0;

    auto ACTIVE_BUTTON_COLOR   = Color(0.85, 0.85, 0.85, 0.95);
    auto INACTIVE_BUTTON_COLOR = Color(0.35, 0.35, 0.35, 0.95);

    auto inputType = ColorType.RGB;

    override void onComponentInit () {
        auto SLIDER_COLOR     = Color(0.85, 0.85, 0.85, 0.85);
        auto BACKGROUND_COLOR = Color(0.35, 0.35, 0.35, 0.65);

        root = new UIDecorators.Draggable!UILayoutContainer(LayoutDir.HORIZONTAL, Layout.CENTER, 
            vec2(200, 100), vec2(0,0), vec2(10,12), 10.0, [
                new UILayoutContainer(LayoutDir.VERTICAL, Layout.TOP_CENTER, vec2(10,10), 0.0, [
                    ctext = new UITextElement(vec2(), vec2(), vec2(10,10), "Color Demo", new Font(FONT, fontSize), Color(1,0,0,1), Color(1,0,0,1)),
                    cbox = new UIBox(vec2(0,0), vec2(200,180), Color(1,0,0,1)),
                ]),
                new UILayoutContainer(LayoutDir.VERTICAL, Layout.CENTER, vec2(10,10), 0.0, [
                    new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.TOP_LEFT, vec2(2,2), 0.0, [
                        buttons[ColorType.RGB]  = new UITextElement(vec2(),vec2(),vec2(3,3), "RGB", new Font(FONT,fontSize), ACTIVE_BUTTON_COLOR, INACTIVE_BUTTON_COLOR),
                        buttons[ColorType.HUSL] = new UITextElement(vec2(),vec2(),vec2(3,3), "HUSL", new Font(FONT,fontSize), INACTIVE_BUTTON_COLOR, INACTIVE_BUTTON_COLOR),
                        buttons[ColorType.HSV]  = new UITextElement(vec2(),vec2(),vec2(3,3), "HSV", new Font(FONT,fontSize), INACTIVE_BUTTON_COLOR, INACTIVE_BUTTON_COLOR),
                        
                    ]),
                    sliders[0] = new UISlider(vec2(), vec2(250,24), vec2(5,5), vec2(24,15), 1, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),
                    sliders[1] = new UISlider(vec2(), vec2(250,24), vec2(5,5), vec2(24,15), 0, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),
                    sliders[2] = new UISlider(vec2(), vec2(250,24), vec2(5,5), vec2(24,15), 0, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),
                    sliders[3] = new UISlider(vec2(), vec2(250,24), vec2(5,5), vec2(24,15), 1, 0, 1, SLIDER_COLOR, BACKGROUND_COLOR),

                    cstats = new UITextElement(vec2(), vec2(), vec2(0,0), "", new Font(FONT, smallFontSize), Color(1,1,1,0.97), Color(0,0,0,0)),
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

                string fmtVec (vec4 v) { return format("(%0.3f,%0.3f,%0.3f,%0.3f)", v.x, v.y, v.z, v.w); }

                auto inputs = vec4(sliders[0].value, sliders[1].value, sliders[2].value, sliders[3].value);
                vec4 rgba = inputs;
                final switch (inputType) {
                    case ColorType.RGB: break;
                    case ColorType.HSV:  rgba = vec4(hsv_to_rgb(inputs.xyz), inputs.w); break;
                    case ColorType.HUSL: break;//rgba = vec4(huslpct_to_rgb(inputs.xyz), inputs.w); break;
                }
                auto color = Color(rgba);
                cbox.color = color;
                ctext.color = color;
                ctext.backgroundColor = color;

                rgba.x = max(0.0, min(1.0, rgba.x));
                rgba.y = max(0.0, min(1.0, rgba.y));
                rgba.z = max(0.0, min(1.0, rgba.z));

                cstats.text = format("rgb: %s\nhsv: %s\nrgb2: %s\n%s", 
                    fmtVec(rgba),
                    fmtVec(vec4(rgb_to_hsv(rgba.xyz), rgba.w)),
                    fmtVec(vec4(rgb_to_hsv(rgba.xyz).hsv_to_rgb, rgba.w)),
                    rgb_to_hex(rgba.xyz)
                );
                root.render();
            },
            (MouseButtonEvent ev) {
                if (ev.pressed && (buttons[ColorType.RGB].mouseover || buttons[ColorType.HSV].mouseover)) {
                    auto color = vec4(sliders[0].value, sliders[1].value, sliders[2].value, sliders[3].value);
                    if (buttons[ColorType.RGB].mouseover && inputType != ColorType.RGB) {
                        final switch (inputType) {
                            case ColorType.HSV:  color = vec4(hsv_to_rgb(color.xyz), color.w); break;
                            case ColorType.HUSL: color = vec4(husl_to_rgb(color.xyz), color.w); break;
                            case ColorType.RGB: break;
                        }
                        buttons[inputType].color = INACTIVE_BUTTON_COLOR;
                        buttons[inputType = ColorType.RGB].color = ACTIVE_BUTTON_COLOR;

                    //} else if (buttons[ColorType.HUSL].mouseover && inputType != ColorType.HUSL) {
                    //    if (inputType == ColorType.HSV)
                    //        color = vec4(hsv_to_rgb(color.xyz), color.w);

                    //    color.x = max(0.0, min(1.0, color.x));
                    //    color.y = max(0.0, min(1.0, color.y));
                    //    color.z = max(0.0, min(1.0, color.z));

                    //    color = vec4(rgb_to_husl(color.xyz), color.w);

                    //    buttons[inputType].color = INACTIVE_BUTTON_COLOR;
                    //    buttons[inputType = ColorType.HUSL].color = ACTIVE_BUTTON_COLOR;

                    } else if (buttons[ColorType.HSV].mouseover && inputType != ColorType.HSV) {
                        final switch (inputType) {
                            case ColorType.RGB:  color = vec4(rgb_to_hsv(color.xyz), color.w); break;
                            case ColorType.HUSL: color = vec4(rgb_to_hsv(husl_to_rgb(color.xyz)), color.w); break;
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
            (MouseMoveEvent ev) {
                root.handleEvents(event);
                buttons[ColorType.HUSL].color = 
                    buttons[ColorType.HUSL].mouseover ?
                        ACTIVE_BUTTON_COLOR :
                        INACTIVE_BUTTON_COLOR;
            },
            () {
                root.handleEvents(event);
            }
        )();
    }
}











