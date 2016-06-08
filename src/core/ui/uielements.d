
module gsb.core.ui.uielements;
import gsb.core.ui.uilayout;

import gsb.core.log;
import gsb.core.uievents;
import gsb.gl.debugrenderer;

import gsb.core.text;
import gsb.utils.color;

import gl3n.linalg;
import std.algorithm: min, max;
import std.math: abs;
import std.format;

private bool inBounds (vec2 pos, vec2 p1, vec2 p2) {
    return !(pos.x < p1.x || pos.x > p2.x || pos.y < p1.y || pos.y > p2.y);
}
private auto clamp (T) (T x, T minv, T maxv) {
    return min(max(x, minv), maxv);
}

class UIElement : IResource, IRenderable, ILayoutable {
    vec2 pos, dim;
    bool mouseover = false;

    this (vec2 pos, vec2 dim) {
        this.pos = pos; this.dim = dim;
    }

    void render () {}
    bool handleEvents (UIEvent event) { 
        return event.handle!(
            (MouseMoveEvent ev) {
                mouseover = inBounds(ev.position, pos, pos + dim);
                return false;
            },
            () { return false; });
    }
    void recalcDimensions () {}
    void doLayout () {}
    void release () {}
}

class UITextElement : UIElement {
    private TextFragment fragment;
    private vec2 padding;

    this (vec2 pos, vec2 dim, vec2 padding, string text, Font font, Color color, Color backgroundColor) {
        super(pos, dim);
        this.padding = padding;
        this.fragment = new TextFragment(text, font, color, this.pos * 2.0);
        this.backgroundColor = backgroundColor;
        recalcDimensions();
        doLayout();
    }
    this (vec2 padding, string text, Font font, Color color) {
        this(vec2(0,0), vec2(0,0), padding, text, font, color, Color());
    }

    override void release () {
        if (fragment) {
            fragment.detatch();
            fragment = null;
        }
    }

    @property auto text () { return fragment.text; }
    @property void text (string text) { fragment.text = text; }

    @property auto fontFamily () { return fragment.font.name; }
    @property void fontFamily (string name) { fragment.font = new Font(name, fragment.font.size); }

    @property auto fontSize () { return fragment.font.size; }
    @property void fontSize (float size) { fragment.font = new Font(fragment.font.name, size); }

    @property auto color () { return fragment.color; }
    @property void color (typeof(color) color) { fragment.color = color; }

    Color backgroundColor;

    override void render () {
        //DebugRenderer.drawRect(pos, pos + dim, backgroundColor);
        //DebugRenderer.drawLineRect(pos, pos + dim, backgroundColor, 0.0);
    }

    override bool handleEvents (UIEvent event) {
        return super.handleEvents(event);
    }
    override void recalcDimensions () {
        dim = fragment.bounds + padding * 2.0;
    }
    override void doLayout () {
        fragment.position = pos + padding;
    }
}

struct UIDecorators {
    class Draggable(T) : T {
        private vec2 lastMousePosition;
        private bool mouseover = false;
        private bool dragging  = false;
        private bool resizeLeft = false;
        private bool resizeRight = false;
        private bool resizeTop   = false;
        private bool resizeBtm   = false;

        public bool isDraggable = true;
        public bool isResizable = true;
        public float resizeWidth = 5.0;

        this (Args...)(Args args) if (__traits(compiles, new T(args))) {
            super(args);
        }

        override bool handleEvents (UIEvent event) {
            return (super.handleEvents(event) || event.handle!(
                (MouseMoveEvent ev) {
                    if (!dragging) {
                        // No drag / resize event; check for mouseover + update flags
                        auto a = pos, b = pos + dim;
                        auto k = resizeWidth;

                        lastMousePosition = ev.position;
                        mouseover   = inBounds(ev.position, a, b);
                        resizeLeft  = resizeWidth && mouseover && inBounds(ev.position, vec2(a.x - k, a.y - k), vec2(a.x + k, b.y + k));
                        resizeRight = resizeWidth && mouseover && inBounds(ev.position, vec2(b.x - k, a.y - k), vec2(b.x + k, b.y + k));
                        resizeTop   = resizeWidth && mouseover && inBounds(ev.position, vec2(a.x - k, a.y - k), vec2(b.x + k, a.y + k));
                        resizeBtm   = resizeWidth && mouseover && inBounds(ev.position, vec2(a.x - k, b.y - k), vec2(b.x + k, b.y + k));
                    } else if (resizeLeft || resizeRight || resizeTop || resizeBtm) {
                        // Resize
                        pos += vec2(
                            resizeLeft ? ev.position.x - lastMousePosition.x : 0.0,
                            resizeTop  ? ev.position.y - lastMousePosition.y : 0.0);
                        dim += vec2(
                            resizeLeft ? lastMousePosition.x - ev.position.x : ev.position.x - lastMousePosition.x,
                            resizeTop  ? lastMousePosition.y - ev.position.y : ev.position.y - lastMousePosition.y);
                        lastMousePosition = ev.position;
                    } else {
                        // Drag
                        pos += ev.position - lastMousePosition;
                        lastMousePosition = ev.position;
                    }
                    return true;
                },
                (MouseButtonEvent ev) {
                    if (isDraggable && ev.pressed && mouseover) {
                        dragging = true;
                        return true;
                    } else if (dragging && ev.released) {
                        dragging = false;
                        return true;
                    }
                    return false;
                },
                () { return false; }
            ));
        }
    }

    class ClampedRelativeTo (T) : T {
        private UIElement target;
        private vec2 offset;

        this (Args...)(UIElement target, Args args) if (__traits(compiles, new T(args))) {
            super(args);
            this.target = target;
            this.offset = pos;
            recalcDimensions();
            doLayout();
        }
        override void recalcDimensions () {
            this.dim = target.dim;
            super.recalcDimensions();
        }
        override void doLayout () {
            this.pos = target.pos + offset;
            super.doLayout();
        }
    }

    class ClampedPositionTo (T) : T {
        private UIElement target;

        this (Args...)(UIElement target, Args args) if (__traits(compiles, new T(args))) {
            super(args);
            this.target = target;
            doLayout();
        }
        override void doLayout () {
            this.pos = target.pos;
            super.doLayout();
        }
    }

}

// Basic container w/ no bells and whistles.
class UIContainer : UIElement {
    UIElement[] elements;
    bool displayBorder = false;

    this (vec2 pos, vec2 dim, UIElement[] elements) {
        super(pos, dim);
        this.elements = elements;
    }
    override void recalcDimensions () {
        foreach (elem; elements)
            elem.recalcDimensions();
    }
    override void doLayout () {
        foreach (elem; elements)
            elem.doLayout();
    }
    override void render () {
        foreach (elem; elements)
            elem.render();
    }
    override bool handleEvents (UIEvent event) {
        bool handled = super.handleEvents(event);
        foreach (elem; elements)
            if (elem.handleEvents(event))
                handled = true;
        return handled;
    }
    override void release () {
        foreach (elem; elements)
            elem.release();
        elements.length = 0;
    }
}

enum LayoutDir : ubyte { HORIZONTAL = 0, VERTICAL = 1 };
enum Layout : ubyte {
    TOP_LEFT, TOP_CENTER, TOP_RIGHT,
    CENTER_LEFT, CENTER, CENTER_RIGHT,
    BTM_LEFT, BTM_CENTER, BTM_RIGHT
}
Layout nextLayout (Layout layout) { return cast(Layout)((layout + 1) % 9); }
Layout prevLayout (Layout layout) { return cast(Layout)((layout - 1) % 9); }

private LayoutBitmask toBitmask (Layout layout) {
    immutable ubyte[9] bitmasks = [
        LayoutBitmask.TOP | LayoutBitmask.LEFT,
        LayoutBitmask.TOP | LayoutBitmask.XCENTER,
        LayoutBitmask.TOP | LayoutBitmask.RIGHT,
        
        LayoutBitmask.YCENTER | LayoutBitmask.LEFT,
        LayoutBitmask.YCENTER | LayoutBitmask.XCENTER,
        LayoutBitmask.YCENTER | LayoutBitmask.RIGHT,

        LayoutBitmask.BTM | LayoutBitmask.LEFT,
        LayoutBitmask.BTM | LayoutBitmask.XCENTER,
        LayoutBitmask.BTM | LayoutBitmask.RIGHT,
    ];
    assert(layout >= 0 && layout <= 9, format("Invalid layout %d", layout));
    return cast(LayoutBitmask)bitmasks[layout];
}

private enum LayoutBitmask : ubyte {
    LEFT       = 0x1,
    RIGHT      = 0x2,
    XCENTER    = 0x3,
    X_LAYOUT_MASK = 0x3,
    X_LAYOUT_SHIFT = 0,  // shift to put LEFT,RIGHT,XCENTER into range (0,4]

    TOP        = 0x4,
    BTM        = 0x8,
    YCENTER    = 0xC,
    Y_LAYOUT_MASK = 0xC,
    Y_LAYOUT_SHIFT = 2, // shift to put TOP,BTM,YCENTER into range (0,4]
}

private vec2 get_layout_scalars (LayoutBitmask layout) {
    immutable float[4] x_layout_scalars = [ float.nan, 0, 1, 0.5 ]; // UNDEFINED, LEFT, RIGHT, XCENTER
    immutable float[4] y_layout_scalars = [ float.nan, 0, 1, 0.5 ]; // UNDEFINED, TOP,  BTM,   YCENTER

    return vec2(
        x_layout_scalars[(layout & LayoutBitmask.X_LAYOUT_MASK) >> LayoutBitmask.X_LAYOUT_SHIFT],
        y_layout_scalars[(layout & LayoutBitmask.Y_LAYOUT_MASK) >> LayoutBitmask.Y_LAYOUT_SHIFT]);
}

// Dynamic, autolayouted element container.
class UILayoutContainer : UIContainer {
    private vec2 contentDim = vec2(0,0);
    public  vec2 padding;
    public  float spacing;

    public Layout    layout;
    public LayoutDir direction;

    this (LayoutDir dir, Layout layout, vec2 padding, float spacing, UIElement[] elements) {
        this(dir, layout, vec2(0,0), vec2(0,0), padding, spacing, elements);
    }
    this (T)(LayoutDir dir, Layout layout, vec2 padding, float spacing, T[] elements) {
        this(dir, layout, vec2(0,0), vec2(0,0), padding, spacing, cast(UIElement[])elements);
    }
    this (T)(LayoutDir dir, Layout layout, vec2 pos, vec2 dim, vec2 padding, float spacing, T[] elements) {
        this(dir, layout, pos, dim, padding, spacing, cast(UIElement[])elements);
    }
    this (LayoutDir layoutDir, Layout layout, 
        vec2 pos, vec2 dim, 
        vec2 padding, 
        float spacing, 
        UIElement[] elements
    ) {
        super(pos, dim, elements);
        this.layout    = layout;
        this.direction = layoutDir;
        this.padding = padding;
        this.spacing = spacing;
    }

    override void recalcDimensions () {
        contentDim = vec2(0, 0);
        if (direction == LayoutDir.HORIZONTAL) {
            if (elements.length)
                contentDim.x += spacing * (elements.length - 1);
            foreach (elem; elements) {
                elem.recalcDimensions();
                contentDim.x += elem.dim.x;
                contentDim.y = max(contentDim.y, elem.dim.y);
            }
        } else {
            if (elements.length)
                contentDim.y += spacing * (elements.length - 1);
            foreach (elem; elements) {
                elem.recalcDimensions();
                contentDim.x = max(contentDim.x, elem.dim.x);
                contentDim.y += elem.dim.y;
            }
        }
        dim = vec2(
            max(dim.x, contentDim.x + padding.x * 2.0),
            max(dim.y, contentDim.y + padding.y * 2.0));
    }
    override void doLayout () {
        if (!elements.length)
            return;

        // Why the hell doesn't gl3n have this?!
        vec2 component_mul (vec2 a, vec2 b) {
            return a.x *= b.x, a.y *= b.y, a;
        }

        // layout scalars: LEFT/TOP = 0.0, RIGHT/BTM = 1.0, CENTER = 0.5
        auto layoutScalars = get_layout_scalars(layout.toBitmask);
        auto inner = component_mul(layoutScalars, dim - padding * 2 - contentDim);

        auto next = inner + pos + padding;
        if (direction == LayoutDir.HORIZONTAL) {
            auto koffs = layoutScalars.y;
            foreach (elem; elements) {
                elem.pos = next + vec2(0, koffs * (contentDim.y - elem.dim.y));
                next.x += elem.dim.x + spacing;
                elem.doLayout();
            }
        } else {
            auto koffs = layoutScalars.x;
            foreach (elem; elements) {
                elem.pos = next + vec2(koffs * (contentDim.x - elem.dim.x), 0);
                next.y += elem.dim.y + spacing;
                elem.doLayout();
            }
        }
    }
    override void render () {
        DebugRenderer.drawLineRect(pos, pos + dim, Color("#fe202050"), 1);
        foreach (elem; elements)
            elem.render();
    }
}




// Basic element container where items have fixed positions (and once moved, elements will _stay_ there).
class UIFixedContainer : UIContainer {
    public  vec2 padding;
    private vec2 lastPos;

    this (vec2 pos, vec2 dim, vec2 padding, UIElement[] elements) {
        super(pos, dim, elements); 
        this.lastPos = this.pos;
        this.padding = padding;
        this.elements = elements;
    }

    override void recalcDimensions () {
        // update position constraint
        auto rel = pos - lastPos;
        foreach (elem; elements)
            elem.pos += rel;
        lastPos = pos;

        // reset bounds + grow to fit content
        vec2 a = pos - padding, b = pos + padding;
        foreach (elem; elements) {
            elem.recalcDimensions();
            a.x = min(a.x, elem.pos.x);
            a.y = min(a.y, elem.pos.y);
            b.x = max(b.x, elem.pos.x + elem.dim.x);
            b.y = max(b.y, elem.pos.y + elem.dim.y);
        }

        lastPos = pos = a - padding;
        dim = b - a + padding * 2.0;
        // Only enforce as min bounds though -- user can resize dim if they want.
        //dim = vec2(
        //    max(dim.x, b.x - a.x),
        //    max(dim.y, b.y - a.y));
    }

    override void doLayout () {
        foreach (elem; elements)
            elem.doLayout();
    }
    override void render () {
        DebugRenderer.drawLineRect(pos, pos + dim, Color("#fe202050"), 1);
        foreach (elem; elements)
            elem.render();
    }
}

class UIGraphView : UIElement {
    struct DataSet {
        Color color;
        float[] delegate() getValues;
    }
    DataSet[] datasets;
    float lineWidth = 0;
    float lineSamples = 1;

    this (vec2 pos, vec2 dim, DataSet[] datasets) {
        super(pos, dim);
        this.datasets = datasets;
    }

    private vec2[] tmp;
    override void render () {
        import std.algorithm.iteration;
        import std.range: enumerate;

        auto values = cache(datasets.map!"a.getValues()");
        float minv, maxv; int start = 0;
        foreach (xs; values) {
            if (!xs.length)
                continue;
            if (!start++) {
                minv = xs.reduce!"min(a,b)";
                maxv = xs.reduce!"max(a,b)";
            } else {
                minv = min(minv, xs.reduce!"min(a,b)");
                maxv = max(maxv, xs.reduce!"max(a,b)");
            }
        }
        //log.write("max, min: %0.2f,%0.2f", maxv, minv);
        //maxv *= 1.10;
        //minv /= 1.5;

        auto delta = maxv - minv;
        maxv += delta * 0.1;
        minv -= delta * 0.1;

        foreach (i, xs; values.enumerate()) {
            if (!xs.length)
                continue;
            tmp.length = 0;
            foreach (j, x; xs.enumerate)
                tmp ~= vec2(
                    pos.x + dim.x * (1 - cast(float)j / cast(float)(xs.length-1)),
                    pos.y + dim.y * (1 - (x - minv) / (maxv - minv)));
            DebugRenderer.drawLines(tmp, datasets[i].color, lineWidth, lineSamples);
        }
        DebugRenderer.drawLineRect(pos, pos + dim, Color("#207f20"), 1);

        // tbd: draw lines...
    }
}

class UIBox : UIElement {
    Color color;
    this (vec2 pos, vec2 dim, Color color) {
        super(pos, dim);
        this.color = color;
    }
    override void render () {
        DebugRenderer.drawRect(pos, pos + dim, color);
    }
}

class UISlider : UIElement {
    Color sliderColor;
    Color backgroundColor;
    vec2 padding, sdim;
    float value, minValue, maxValue;
    bool dragging = false;
    float scrollspeed = 1.0;

    private vec2 lastpos;

    this (vec2 pos, vec2 dim, vec2 padding, vec2 sliderdim, float value, float minValue, float maxValue, Color sliderColor, Color backgroundColor) {
        super(pos, dim);
        this.padding = padding;
        this.sdim = sliderdim;
        this.value = value;
        this.minValue = minValue;
        this.maxValue = maxValue;
        this.sliderColor = sliderColor;
        this.backgroundColor = backgroundColor;
        assert(maxValue > minValue);
    }

    override void render () {
        DebugRenderer.drawRect(pos + padding, pos + dim - padding * 2, backgroundColor);

        auto spos = pos + vec2(
            (dim.x - sdim.x) * (value - minValue) / (maxValue - minValue),
            0);
            //(sdim.y - dim.y) * 0.5);
        DebugRenderer.drawRect(spos, spos + sdim, sliderColor);
    }

    private final void updateDrag (vec2 pt) {
        value = clamp(minValue + (pt.x - pos.x) * (maxValue - minValue) / (dim.x - sdim.x), minValue, maxValue);
    }

    override bool handleEvents (UIEvent evt) {
        return super.handleEvents(evt) || evt.handle!(
            (MouseButtonEvent ev) {
                if (mouseover && ev.pressed && ev.isLMB) {
                    dragging = true; updateDrag(lastpos);
                    return true;
                } else if (dragging && ev.released) {
                    dragging = false;
                    return true;
                }
                return false;
            },
            (MouseMoveEvent ev) {
                if (dragging) {
                    updateDrag(ev.position);
                    return true;
                } else {
                    lastpos = ev.position;
                    return false;
                }
            },
            (ScrollEvent ev) {
                if (mouseover) {
                    // For nicer scrolling on mac trackpads, we support both vertical scrolling (default) and horizontal scrolling
                    // (for a horizontal slider, this feels much more natural; we _do_ need to invert horizontal scrolling though 
                    //  (ie. apple's "natural" scrolling), since it actually makes sense here (slider should follow finger movements)).
                    float delta = abs(ev.dir.y) > abs(ev.dir.x) ? ev.dir.y : -ev.dir.x;
                    
                    value = clamp(value + delta * scrollspeed * (maxValue - minValue) / (dim.x - sdim.x), minValue, maxValue);
                    return true;
                }
                return false;
            },
            () { return false; }
        );
    }


}







































































