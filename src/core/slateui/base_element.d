module gsb.core.slateui.base_element;
public import gl3n.linalg;
public import gsb.core.uievents;
public import gsb.utils.attrib;
public import gsb.utils.signals;

interface GlBatch {}
interface SlateEvh {}
struct FrameInfo {
    double dt;
}

class UIElement {
    vec2 pos, vel;
    float mass, damping;

    vec2 dim, border;

    // call these three in sequence to relayout + rerender
    abstract void recalcDimensions ();
    abstract void relayout ();
    abstract void render   (GlBatch, ref FrameInfo);

    abstract bool onEvent (UIEvent);

    bool withinBounds (vec2 pt) {
        return true;
    }
}

mixin template UIElementWrapper (T) {
    T target;
    this (T target) { this.target = target; }

    auto get () { return target; }
    auto get (out T tref) { return tref = target, this; }

    auto pos (typeof(target.pos) v) {
        return target.pos = v, this;
    }
    auto mass (typeof(target.mass) v) {
        return target.border = v, this;
    }
    auto damping (typeof(target.damping) v) {
        return target.border = v, this;
    }
    auto border (typeof(target.border) v) {
        return target.border = v, this;
    }
}

mixin template UITextProperty () {
    union {
        private string delegate () m_getText;
        private string m_text = "";
    }
    private bool m_hasTextGetter = false;

    private void setTextSrc (typeof(m_getText) v) {
        m_getText = v; m_hasTextGetter = true;
    }
    private void setTextSrc (typeof(m_text) v) {
        m_text = v; m_hasTextGetter = false;
    }
    public auto @property text () {
        return m_hasTextGetter ?
            m_getText() :
            m_text;
    }
}





