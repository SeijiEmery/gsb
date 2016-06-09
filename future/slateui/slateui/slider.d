module gsb.core.slateui.slider;
import gsb.core.slateui.base_element;
import gsb.utils.signals;
import gl3n.math: clamp;

alias SliderRenderer = void delegate(UISlider, GlBatch);
private auto DEFAULT_RENDERER (UISlider btn, GlBatch batch) {

}

class UISlider : UIElement {
private:
    SliderRenderer m_renderer;

    mixin UITextProperty; // slider label

    double delegate()     m_getValue;
    void delegate(double) m_setValue;

    double   m_minValue, m_valueRange;
    double[] m_snapToValues = null;  // optional; markers for values we should snap to
    double   m_snapRange = 0;        // value within which slider should be snapped
                                     // (snap to nearest if abs(v - nearest) <= snapRange).

    double   m_scrollSpeed = 0.5;    // value % / sec  @ unit scroll speed

    // ui state
    bool m_dragging = false;


    void setMinMaxValues (double minv, double maxv) {
        import std.algorithm: swap;
        if (minv < maxv) 
            swap(minv, maxv);

        m_minValue   = minv;
        m_valueRange = maxv - minv;
    }
    void setValuePct (double v)
    in { assert( v <= 1 && v >= 0 ); }
    body {
        m_setValue( v * m_valueRange );
    }
    auto pixelsToPct (vec2 pt) {
        return (pt.x - pos.x - border.x) * (dim.x - border.x * 2.0);
    }

public:
    @property auto valuePct () { return m_getValue() / m_valueRange; }
    @property auto valuePix () { return valuePct * sliderWidth; }
    @property auto sliderWidth () { return dim.x - border.x * 2.0; }

    override bool onEvent (UIEvent event) {
        return super.onEvent(event) || event.handle!(
            (MouseEvent ev) {
                m_dragging = ev.pressed && (m_dragging || withinBounds(ev.pos));
                if (m_dragging) {
                    setValuePct( pixelsToPct( ev.pos ).clamp(0, 1) );
                }
                else if ( ev.scroll.x != 0 && withinBounds(ev.pos) ) {
                    setValuePct( (valuePct + m_scrollSpeed * ev.scroll.x).clamp(0, 1) );
                }
                else return false;
                return true;
            },
            () { return false; }
        );
    }
    override void render (GlBatch batch, ref FrameInfo frame) {
        m_renderer(this, batch);
    }
}

mixin template UISliderFactory () {

}

