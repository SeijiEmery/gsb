
module gsb.core.ui.uielements;
import gsb.core.ui.uilayout;

import gsb.core.uievents;
import gsb.gl.debugrenderer;

import gsb.text.textrenderer;
import gsb.core.color;
import gsb.text.font;

import gl3n.linalg;

private bool inBounds (vec2 pos, vec2 p1, vec2 p2) {
    return !(pos.x < p1.x || pos.x > p2.x || pos.y < p1.y || pos.y > p2.y);
}

class UIElement : IResource, IRenderable, ILayoutable {
    vec2 pos, dim;

    this (vec2 pos, vec2 dim) {
        this.pos = pos; this.dim = dim;
    }

    void render () {}
    bool handleEvents (UIEvent event) { return false; }
    void recalcDimensions () {}
    void doLayout () {}
    void release () {}
}

class UITextElement : UIElement {
    private TextFragment fragment;

    this (vec2 pos, vec2 dim, string text, Font font, Color color, Color backgroundColor) {
        super(pos, dim);
        fragment = new TextFragment(text, font, color, this.pos * 2.0);
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
        return false;
    }
    override void recalcDimensions () {
        dim = fragment.bounds;
    }
    override void doLayout () {
        fragment.position = pos * 2.0;
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
        public float resizeWidth = 0.0;

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
}

class UILayoutContainer : UIElement {
    UIElement[] elements;
    private vec2 contentDim;
    public  vec2 padding;

    public RelLayoutDirection relDirection;
    public RelLayoutPosition  relPosition;

    this (typeof(relDirection) relDirection, typeof(relPosition) relPosition, 
        vec2 pos, vec2 dim, vec2 padding,
        UIElement[] elements
    ) {
        super(pos, dim);
        this.relDirection = relDirection;
        this.relPosition = relPosition;
        this.padding = padding;
        this.elements = elements;
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
            min(dim.x, contentDim.x + padding.x),
            min(dim.y, contentDim.y + padding.y));
    }
    override void doLayout () {
        if (relPosition != RelLayoutPosition.CENTER)
            throw new Exception(format("Unsupported layout: %s", relPosition));

        immutable vec2[9] REL_VECTOR = [
            vec2(0.5, 0.5), vec2(0.0, 0.5), vec2(1.0, 0.5), vec2(0.5, 1.0), vec2(0.5, 0.0),
            vec2(0.0, 1.0), vec2(1.0, 1.0), vec2(0.0, 0.0), vec2(1.0, 0.0)
        ];
        immutable float[9] CENTERED_OFFSET = [
            1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0
        ];
        immutable float[9] SIGN = [ +1, +1, -1, +1, -1, +1, +1, -1, -1 ];
        immutable vec2[2] DIR = [ vec2(1, 0), vec2(0, 1) ];

        vec2 center = REL_VECTOR[relPosition];
        vec2 dir    = SIGN[relPosition] * DIR[relDirection];
        vec2 flex   = dim - contentDim;

        center = pos + vec2(dim.x * center.x, dim.y * center.y) + CENTERED_OFFSET[relPosition] * vec2(dir.x * flex.x, dir.y * flex.y);

        foreach (elem; elements) {
            elem.pos = center + elem.dim * 0.5;
            center += dir;
            elem.doLayout();
        }
    }
    override void release () {
        foreach (elem; elements)
            elem.release();
        elements.length = 0;
    }
    override bool handleEvents (UIEvent event) {
        bool handled = false;
        foreach (elem; elements)
            if (elem.handleEvents(event))
                handled = true;
        return handled;
    }
    override void render () {
        foreach (elem; elements)
            elem.render();
    }
}






































































