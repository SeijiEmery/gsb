
module gsb.core.ui.uielements;
import gsb.core.ui.uilayout;

import gsb.core.log;
import gsb.core.uievents;
import gsb.gl.debugrenderer;

import gsb.text.textrenderer;
import gsb.core.color;
import gsb.text.font;

import gl3n.linalg;

private bool inBounds (vec2 pos, vec2 p1, vec2 p2) {
    return !(pos.x < p1.x || pos.x > p2.x || pos.y < p1.y || pos.y > p2.y);
}

enum RelLayoutDirection : ubyte { HORIZONTAL, VERTICAL };
enum RelLayoutPosition  : ubyte {
    CENTER, CENTER_LEFT, CENTER_RIGHT, CENTER_TOP, CENTER_BTM,
    TOP_LEFT, TOP_RIGHT, BTM_LEFT, BTM_RIGHT
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
        DebugRenderer.drawLineRect(pos, pos + dim, backgroundColor, 0.0);
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

// Dynamic, autolayouted element container.
class UILayoutContainer : UIContainer {
    private vec2 contentDim;
    public  vec2 padding;

    public RelLayoutDirection relDirection;
    public RelLayoutPosition  relPosition;

    this (typeof(relDirection) relDirection, typeof(relPosition) relPosition, 
        vec2 pos, vec2 dim, vec2 padding,
        UIElement[] elements
    ) {
        super(pos, dim, elements);
        this.relDirection = relDirection;
        this.relPosition = relPosition;
        this.padding = padding;
    }

    override void recalcDimensions () {
        contentDim = vec2(0, 0);
        final switch (relDirection) {
            case RelLayoutDirection.HORIZONTAL: {
                foreach (elem; elements) {
                    elem.recalcDimensions();
                    contentDim.x += elem.dim.x;
                    if (elem.dim.y > contentDim.y)
                        contentDim.y = elem.dim.y;
                }
            } break;
            case RelLayoutDirection.VERTICAL: {
                foreach (elem; elements) {
                    elem.recalcDimensions();
                    contentDim.y += elem.dim.y;
                    if (elem.dim.x > contentDim.x)
                        contentDim.x = elem.dim.x;
                }
            } break;
        }
        dim = vec2(
            max(dim.x, contentDim.x + padding.x * 2.0),
            max(dim.y, contentDim.y + padding.y * 2.0));
    }
    override void doLayout () {
        if (!elements.length)
            return;

        bool horizontal = relDirection == RelLayoutDirection.HORIZONTAL;
        auto flex = dim - contentDim;

        vec2 center, offs;
        final switch (relPosition) {
            case RelLayoutPosition.CENTER: {
                if (horizontal) {
                    center = flex * 0.5;
                    offs   = vec2(0.0, 0.0);
                } else {
                    center = flex * 0.5 + elements[0].dim * 0.5;
                    offs   = vec2(0.5, 0.5);
                } 
            } break;
            case RelLayoutPosition.CENTER_TOP: {
                if (horizontal) {
                    center = vec2(flex.x * 0.5, padding.y);
                    offs   = vec2(0.0, 0.0);
                } else {
                    center = vec2(flex.x * 0.5, padding.y) + elements[0].dim * 0.5;
                    offs   = vec2(0.5, 0.5);
                }
            } break;
            case RelLayoutPosition.CENTER_BTM: {
                if (horizontal) {
                    center = vec2(flex.x * 0.5, flex.y - padding.y);
                    offs   = vec2(0.0, 0.0);
                } else {
                    center = vec2(flex.x * 0.5, flex.y - padding.y) + elements[0].dim * 0.5;
                    offs   = vec2(0.5, 0.5);
                }
            } break;

            case RelLayoutPosition.CENTER_LEFT: {
                center = vec2(padding.x, flex.y * 0.5);
                offs   = vec2(0, 0);
            } break;
            case RelLayoutPosition.TOP_LEFT: {
                center = padding;
                offs   = vec2(0, 0);
            } break;
            case RelLayoutPosition.BTM_LEFT: {
                center = vec2(padding.x, flex.y - padding.y);
                offs   = vec2(0, 0);
            } break;

            case RelLayoutPosition.CENTER_RIGHT: {
                if (horizontal) {
                    center = vec2(flex.x - padding.x, flex.y * 0.5);
                    offs   = vec2(0, 0);
                } else {
                    center = vec2(dim.x - padding.x, flex.y * 0.5);
                    offs   = vec2(1, 0);
                }
            } break;            
            case RelLayoutPosition.TOP_RIGHT: {
                if (horizontal) {
                    center = vec2(flex.x - padding.x, padding.y);
                    offs   = vec2(0, 0);
                } else {
                    center = vec2(dim.x - padding.x, padding.y);
                    offs   = vec2(1, 0);
                }
            } break;
            case RelLayoutPosition.BTM_RIGHT: {
                if (horizontal) {
                    center = vec2(flex.x - padding.x, flex.y - padding.y);
                    offs   = vec2(0, 0);
                } else {
                    center = vec2(dim.x, flex.y) - padding;
                    offs   = vec2(1, 0);  
                }
            } break;
        }

        if (horizontal) {
            foreach (elem; elements) {
                elem.pos = pos + center - vec2(elem.dim.x * offs.x, elem.dim.y * offs.y);
                center.x += elem.dim.x;
                elem.doLayout();
            }
        } else {
            foreach (elem; elements) {
                elem.pos = pos + center - vec2(elem.dim.x * offs.x, elem.dim.y * offs.y);
                center.y += elem.dim.y;
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
        DebugRenderer.drawLineRect(pos, pos + dim, Color("#207f2050"), 1);

        // tbd: draw lines...
    }
}



































































