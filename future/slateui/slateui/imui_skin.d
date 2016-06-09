module gsb.core.slateui.imui_skin;
import gsb.core.slateui.imui;


class ImSkin {
    ImRenderer renderer;
    ImStyle    style;

    this (ImRenderer renderer, ImStyle style) {
        this.renderer = renderer;
        this.style    = style;
    }
}

alias AABB = AABBT!float;
class ImRenderer {
    //abstract void beginFrame (FrameInfo, GlBatch);
    //abstract void endFrame   ();

    abstract AABB drawButton (ImStyle style, vec3 topLeft, string label,     ButtonState st, double stTime);
    abstract AABB drawSlider (ImStyle style, vec3 topLeft, double sliderPct, SliderState st, double stTime);
    abstract AABB drawLabel  (ImStyle style, vec3 topLeft, string label);

    abstract AABB drawTextfield (ImStyle style, vec3 topLeft, string content, ref TextFieldState st);
    abstract AABB drawTextArea  (ImStyle style, vec3 topLeft, string content, ref TextAreaState  st);

    abstract AABB drawDropdown  (ImStyle style, vec3 topLeft, ref DropdownState st);
    abstract AABB drawSpacer    (ImStyle style, vec3 topLeft, float space);
}

class ImStyle {
    ImButtonStyle[ButtonState.max] btn;
    ImSliderStyle[SliderState.max] slider;
    ImLabelStyle                   label;
    ImTextboxStyle[TextboxState.max] text;  // textfield + textarea
}

enum ButtonState  { DISABLED = 0, DEFAULT, HOVER, PRESSED };
enum SliderState  { DISABLED = 0, DEFAULT, HOVER, PRESSED };
enum TextboxState { DISABLED = 0, INACTIVE, HOVER, SELECTED };

struct TextFieldState {
    string beforeSelect;
    string selected;
    string afterSelect;
}
struct TextAreaState {
    string beforeSelect;
    string selected;
    string afterSelect; 
}
struct DropdownState {
    string   top;
    string[] selections = null;
    uint     currentSelected = 0;   // 0 => top, [1..selections.length] => selections[i-1]
}


alias SRect = AABB;
struct SFontFamily {}

private mixin template BasicStyle () {
    float leftMargin = 0, rightMargin = 0, topMargin = 0, btmMargin = 0;
    SFontFamily font;
    SColor textColor;
}
private mixin template RectlikeStyle () {
    mixin BasicStyle;
    SColor backgroundColor, borderColor;
}

struct ImLabelStyle {
    mixin BasicStyle;
}
struct ImButtonStyle {
    mixin RectlikeStyle; 
}
struct ImSliderStyle {
    mixin RectlikeStyle;
    SColor knobColor, knobBorderColor;
    vec2 knobSize;
}

struct ImTextboxStyle {
    mixin RectlikeStyle;
    SColor selectedTextColor, textboxColor, cursorColor;
}






















