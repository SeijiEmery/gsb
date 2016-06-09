module gsb.core.slateui.impl.layout_impl;
import gl3n.linalg;
import gl3n.aabb;


private alias AABB = AABBT!float;

enum LayoutDir { HORIZONTAL, VERTICAL };

struct RectLayout {
    AABB bounds;
    LayoutDir dir;

    this (vec3 topLeft, LayoutDir dir) {
        this.bounds = AABB(topLeft, topLeft);
        this.dir    = dir;
    }
}

AABB layoutRect (Style)(vec3 topLeft, Style st, LayoutDir dir, out AABB inner) {

    auto horizontal = dir == LayoutDir.HORIZONTAL;
    auto w = st.width,  lw = st.leftMargin, rw = st.rightMargin;
    auto h = st.height, lh = st.topMargin,  rh = st.btmMargin;

    if (!horizontal) {
        swap(w, h);
        swap(lw, rh);
        swap(rw, rh);
    }

    // Inner rect
    inner = AABB( 
        topLeft + vec3(lw, lh, 0), 
        topLeft + vec3(lw + w, lh + h, 0));

    // Outer (bounds) rect
    return AABB(
        topLeft,
        topLeft + vec3(lw + w + rw, lh + h + rh, 0));
}


// So... here's our problem with imgui:
// - to draw, say, a slider, we need to know where the slider is (and whether the mouse is over it).
// - however, we _don't_ actually know exactly where the slider is at the time of the call b/c of
//   layouts that can have alignment (eg. stuff is centered, so we _could_ have spacing to the left/right,
//   or not, depending on whether anything we draw after this element is wider or not)
// - aaaannd... our code expects that the slider call runs once + terminates immediately after the call.
//   If we moved the slider with the mouse, the call _must_ detect this and change the value reference
//   before returning. But we don't know whether the slider moved, so...
//
// Probably the main problem is that our "default" way of implementing ui is to use multiple passes:
// - we calculate slider (and all elements) dimensions in a bottom-up sweep (parents depend on child dimensions)
// - we layout slider (and all elements) using a top-down pass once we have the dimensions (child xy depends on parent xy)
// - value checking is/can be done separately: we handle ui events, then fire setters if our value changed.
//
// 


/+

mixin template BaseFrame {
    vec2 dim; vec2 topLeft;
    float depth;
}
struct SliderFrame {
    mixin BaseFrame;
    double* value; double minValue, maxValue;
}
enum Kind : ubyte { LABEL, BUTTON, SLIDER, TEXTFIELD, TEXTAREA };

struct RetainedFrame {
    vec2 dim, topLeft;
    float depth;
    Kind  type;

    union {
        string label;
        struct { double* value; double minValue, maxValue; }
        struct {  }
    }
}


struct imui_singlepass {
    SliderFrame[] slider_frames;

    void beginFrame (vec3 initialPos, LayoutDir initialDir) {

    }
    void beginLayout (LayoutDir dir) {

    }
    void endLayout () {

    }

    void slider (uint id, ref double value, double minValue, double maxValue, SliderStyle st) {
        m_sliders ~= SliderFrame(
            vec2( st.width, st.height ).maybeSwizzleXY( !m_horizontal ),
            m_topLeft,
            m_currentDepth,
            &value, minValue, maxValue
        );
    }
}



struct imui_simple_onepass {
    Tuple!(AABB, bool)[] m_layouts;

    bool m_horizontal = true;
    AABB m_layout;

    vec3   m_topLeft;
    vec2   m_localMousePos;
    vec2   m_deltaMousePos;
    double m_dt;
    float  m_layerDepth = 0.0001;

    void beginLayout (LayoutDir dir) {
        m_layouts ~= tuple(m_layout, m_horizontal);

        m_layout.min.z += m_layerDepth;
        if ((m_horizontal = dir == LayoutDir.HORIZONTAL)) {
            m_layout.max = vec3( m_layout.max.x, m_layout.min.y, m_layout.min.z );
        } else {
            m_layout.max = vec3( m_layout.min.x, m_layout.max.y, m_layout.min.z );
        }
    }
    void endLayout (LayoutDir dir) {
        auto prev    = m_layouts[$-1][0];
        m_horizontal = m_layouts[$-1][1];
        m_layouts.length--;

        if (m_horizontal) {
            prev.max.x  = m_layout.max.x;
            prev.max.y  = max(prev.max.y, m_layout.max.y);
        } else {
            prev.max.x = max(prev.max.x, m_layout.max.x);
            prev.max.y = m_layout.max.y;
        }
        m_layout = prev;
    }
    private AABB growRect (vec2 dim) {

    }
    void slider (uint id, ref double value, double minValue, double maxValue, SliderStyle st) {
        auto valuePct = (value - minValue) / abs(maxValue - minValue);

        auto dim = vec2( st.width, st.height ).maybeSwizzleXY( !m_horizontal );
        auto bounds = addRect( dim );

        bool mouseover = hasMouseover( bounds );
        bool pressed   = m_mouseDown && (mouseover || hasPressFocus(id));

        if (pressed) {
            setPressFocus(id);
            valuePct = ((m_localMousePos.x - bounds.min.x) / dim.x).clamp(0, 1);
            value    = valuePct * abs(maxValue - minValue) + minValue;
        }
        // note:
        // scroll.x, scroll.y: x/y signed scroll components. 
        // scroll.z: signed absmax(scroll.x, scroll.y), where absmax(x,y) = abs(x) >= abs(y) ? x : y
        else if (mouseover && m_scroll.z) {
            valuePct = (valuePct * (1 + st.scrollSpeed * m_dt * m_scroll.z)).clamp(0, 1);
            value = valuePct * abs(maxValue - minValue) + minValue;
        }

        // Fire event handlers as appropriate
        handleMouseover(id, mouseover);

        auto pressState = pressed ? SliderState.PRESSED : mouseover ? SliderState.MOUSEOVER : SliderState.DEFAULT;
        auto lastState  = id && id in m_sliderRetainedState ?
            m_sliderRetainedState[id] :
            ImSlider( pressState, 0 );

        if (lastState.state != pressState) {
            lastState.state  = pressState;
            lastState.time   = 0;
        } else {
            lastState.time += m_dt;
        }
        m_sliderRetainedState[id] = lastState;


        auto knobOffset = vec3( dim.x * valuePct, 0, 0 ).maybeSwizzleXY( !m_horizontal );
        auto knobSize   = vec3(st.knobSize).maybeSwizzleXY( !m_horizontal );

        auto knobBox    = AABB( 
            bounds.min + knobOffset - knobSize * 0.5, 
            bounds.min + knobOffset + knobSize * 0.5
        );

        m_renderer.drawSlider( dim, knobBox, lastState.state, lastState.time, st );
    }

}

struct imui_calcDimPass {
    vec2[] m_rects;
    bool   m_horizontal = true;
    uint[] m_layoutOffsets;
    vec2[] m_layoutRects;

    void beginFrame (vec3 initialPos, LayoutDir initialDir) {
        m_rects.length = 0; 
        m_horizontal = initialDir == LayoutDir.HORIZONTAL;
        m_layoutOffsets.length = 0;
        beginLayout(initialDir);
    }
    void endFrame () {
        endLayout();
    }

    void beginLayout (LayoutDir dir) {
        m_layoutOffsets ~= m_rects.length;
    }
    void endLayout () {
        auto subrects = m_rects[ m_layoutOffsets[$-1] .. m_rects.length ];
        if (subrects.length) {
            auto rect = subrects.length == 1 ? subrects[0] :
                m_horizontal ?
                    subrects.reduce!((vec2 a, vec2 b) => vec2( a.x + b.x, max(a.x, a.y) )) :
                    subrects.reduce!((vec2 a, vec2 b) => vec2( max(a.x, b.x), a.y + b.y));

            m_layoutRects ~= rect;
        }
        m_layoutOffsets.length--;
    }

    void slider (uint id, ref double value, double minValue, double maxValue, SliderStyle st) {
        m_rects ~= vec2( st.width, st.height ).maybeSwizzleXY( !m_horizontal );
    }
}

+/








