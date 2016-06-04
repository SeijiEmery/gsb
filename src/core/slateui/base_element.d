module gsb.core.slateui.base_element;
public import gl3n.linalg;
public import gsb.core.uievents;

interface GlBatch {}
interface SlateEvh {}
struct FrameInfo {
    double dt;
}

class UIElementWrapper (Element, T) {
    Element target;
    this (Element target) { this.target = target; }

    auto pos (vec2 v) {
        return target.pos = v, cast(T)this;
    }
    auto mass (float v) {
        return target.mass = v, cast(T)this;
    }
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





