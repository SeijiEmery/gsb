
module gsb.text.textrenderer;

import gsb.core.log;
import gsb.core.window;
import gsb.core.events;
import gsb.core.errors;
import gsb.core.singleton;
import gsb.text.textshader;
import gsb.text.font;
import gsb.text.geometrybuffer;
import gsb.text.fontatlas;
import gsb.core.color;

import std.format;
import std.utf;
import std.conv;
import std.container.rbtree;
import std.algorithm.setops;
import std.algorithm.mutation : move, swap;
import std.algorithm.iteration;
import std.array;
import std.traits;
import std.typecons;
import std.math: approxEqual;
import core.sync.rwmutex;

import stb.truetype;
import gsb.glutils;
import derelict.opengl3.gl3;
import dglsl;


// Generalized text frontend
class TextFragment {
    // Double buffered so we can operate on (frontend ui code) and render
    // (backend text renderer) simultaneously
    struct State {
        string text;
        Font   font;
        Color  color;
        vec2   position;
    }
    private   State fstate; // frontend state
    protected State bstate; // backend / renderer state
    protected bool  dirtyState = true;
    private bool dirtyBounds = true;
    vec2   cachedBounds;

    ulong id;
    static private __gshared ulong _nextId = 0;

    this (string text, Font font, Color color, vec2 position) {
        fstate.text = text;
        fstate.font = font;
        fstate.color = color;
        fstate.position = position;
        id = _nextId++;
        attach();
    }
    void attach  () { TextRenderer.instance.attachFragment(this); }
    void detatch () { TextRenderer.instance.removeFragment(this); }
    ~this () { detatch(); }

    //int opCmp (TextFragment f) {
    //    return uid == f.uid ? 0 :
    //           uid < f.uid  ? -1 : 1;
    //}

    protected bool updateBackendState () {
        if (dirtyState) {
            synchronized { bstate = fstate; dirtyState = false; }
            return true;
        }
        return false;
    }
    public void forceUpdate () {
        synchronized { dirtyState = true; }
    }

    @property auto text () { return fstate.text; }
    @property void text (string v) { 
        synchronized { fstate.text = v; dirtyState = true; dirtyBounds = true; }
    }
    @property auto font () { return fstate.font; }
    @property void font (Font v) {
        synchronized { fstate.font = v; dirtyState = true; dirtyBounds = true; }
    }
    @property auto color () { return fstate.color; }
    @property void color (Color v) {
        synchronized { fstate.color = v; dirtyState = true; }
    }
    @property auto position () { return fstate.position; }
    @property void position (vec2 v) {
        synchronized { fstate.position = v; dirtyState = true; }
    }
    @property auto bounds () {
        synchronized { return dirtyBounds ? cachedBounds : calcBounds(); }
    }
    private auto calcBounds () {
        dirtyBounds = false;
        return cachedBounds = fstate.font.calcPixelBounds(fstate.text);
    }

    protected int currentAtlas = -1;
    protected int currentTextBuffer = -1;
}


// Shared singleton class accessed by lazy .instance
class TextRenderer {
    mixin LowLockSingleton;

    auto textShader = new TextShader();
    auto componentList = new GraphicsComponentList();

    interface IGraphicsComponent {
        void render ();
        bool active ();
    }
    static class GraphicsComponentList {
        IGraphicsComponent[] components;
        ReadWriteMutex       rwMutex;
        private auto @property doRead () { return rwMutex.reader(); }
        private auto @property doWrite () { return rwMutex.writer(); }

        void processFrame () {
            //log.write("TextRenderer -- preparing to draw frame");
            synchronized {
                for (auto i = cast(int)components.length - 1; i >= 0; --i) {
                    //log.write("-- checking component %d", i);
                    if (!components[i].active()) {
                        //log.write("-- removing component %d", i);
                        if (i != components.length - 1)
                            swap(components[i], components[$-1]);
                        components.length -= 1;
                    } else {
                        //log.write("-- rendering component %d", i);
                        components[i].render();
                    }
                }
            }
            //log.write("TextRenderer: Finished drawing frame");
        }
        void registerComponent (IGraphicsComponent component) {
            synchronized {
                components ~= component;
            }
            //log.write("registered component");
        }
    }

    void registerComponent (IGraphicsComponent component) {
        componentList.registerComponent(component);
    }

    // Graphics-thread handle used to render + buffer data for the TextRenderer instance
    // – The only instance of this should be owned by the graphics thread
    // - The graphics thread should not touch any other aspects of TextRenderer
    class GThreadHandle {
    final:
        public int curFrame = 0;
        void render () {
            componentList.processFrame();
        }
    }
    auto getGraphicsThreadHandle () {
        log.write("Creating new TextRenderer graphics thread handle");
        return new GThreadHandle();
    }


    //
    // New API / rendering subsystem:
    //

    alias TextFragmentSet = RedBlackTree!(TextFragment, "a.id < b.id");

    private TextFragmentSet fragments;
    private TextFragment[]  deletedFragments;

    void attachFragment (TextFragment fragment) {
        fragments.insert(fragment);
    }
    void removeFragment (TextFragment fragment) {
        if (fragment in fragments) {
            fragments.remove(fragments.equalRange(fragment));
            deletedFragments ~= fragment;
        }
    }
    struct SharedAtlas {
        PackedFontAtlas atlas;// = new PackedFontAtlas();
        int refcount = 0;

        static SharedAtlas create () {
            SharedAtlas s;
            s.atlas = new PackedFontAtlas();
            return s;
        }
    }
    private SharedAtlas[] atlases;
    private size_t[string] atlasLookup;

    struct SharedTGB {
        TextGeometryBuffer buffer;// = new TextGeometryBuffer();
        PackedFontAtlas    atlas = null;
        bool dflag = false;
        bool shouldRender = false;

        static SharedTGB create () {
            SharedTGB s;
            s.buffer = new TextGeometryBuffer();
            return s;
        }
    }
    private SharedTGB[] buffers;
    private size_t   [] freeBuffers;

    private auto tmp_charset = new RedBlackTree!dchar();

    // call from main thread
    void updateFragments () {
        TextFragment[] addList;
        bool anyBufferChanges = false;

        bool isVisible (TextFragment fragment) {
            return true;
        }

        // process deletions, additions, etc
        foreach (fragment; deletedFragments) {
            atlases[fragment.currentAtlas].refcount--;
            buffers[fragment.currentTextBuffer].dflag = true;
            anyBufferChanges = true;
        }
        foreach (fragment; fragments) {
            if (fragment.dirtyFontAttrib) {
                if (fragment.currentAtlas > 0)
                    atlases[fragment.currentAtlas].refcount--;
                fragment.currentAtlas = -1;
                assert(fragment.dirtyState);
            }
            if (fragment.dirtyState) {
                if (fragment.currentTextBuffer >= 0)
                    buffers[fragment.currentTextBuffer].dflag = true;
                else
                    addList ~= fragment;
                anyBufferChanges = true;
            }
        }
        if (anyBufferChanges) {
            foreach (fragment; fragments) {
                if (fragment.currentTextBuffer >= 0 && buffers[fragment.currentTextBuffer].dflag) {
                    fragment.currentTextBuffer = -1;
                    if (isVisible(fragment)) {
                        addList ~= fragment;
                    }
                }
            }
            synchronized {
                foreach (i; 0..buffers.length) {
                    if (buffers[i].dflag) {
                        buffers[i].dflag = false;
                        buffers[i].shouldRender = false;
                        freeBuffers ~= i;
                        buffers[i].clear();
                    }
                }
            }
            assert(addList.length > 0 && freeBuffers.length > 0);

            // update atlas + swap state
            foreach (fragment; addList) {
                // charset might have changed if text content changed, and it _definitely_ needs to be
                // re-added if the font atlas changed
                auto dirtyCharset = fragment.dirtyContent || fragment.currentAtlas == -1;

                if (fragment.currentAtlas == -1) {
                    auto fontid = format("%s:%d|%d|%d", fragment.font.name, 
                        to!int(fragment.font.size), fragment.font.samples.x, fragment.font.samples.y);
                    if (fontid !in atlasLookup) {
                        fragment.currentAtlas = atlasLookup[fontid] = atlases.length;
                        atlases ~= SharedAtlas.create();
                        atlases[$-1].refcount++;
                    } else {
                        fragment.currentAtlas = atlasLookup[fontid];
                        atlases[fragment.currentAtlas].refcount++;
                    }
                }
                assert(fragment.currentAtlas >= 0 && fragment.currentAtlas < atlases.length);
                auto atlas = atlases[fragment.currentAtlas];

                // Resets dirty flags + updates bstate to fstate
                fragment.swapState();

                if (dirtyCharset) {
                    tmp_charset.clear();
                    foreach (chr; fragment.bstate.text.byDchar)
                        tmp_charset.insert(chr);
                    atlas.insertCharset(font, tmp_charset);
                }
            }

            // write buffers
            addList.sort!"a.currentAtlas";
            int curAtlas = -1, curBuffer = -1;
            foreach (fragment; addList) {
                if (fragment.currentAtlas != curAtlas) {
                    curAtlas = fragment.currentAtlas;
                    if (freeBuffers.length > 0) {
                        curBuffer = freeBuffers[$-1]; freeBuffers.length--;
                    } else {
                        buffers ~= SharedTGB.create();
                        curBuffer = buffers.length-1;
                    }
                    fragment.currentTextBuffer = curBuffer;
                    buffers[curBuffer].atlas = atlases[curAtlas];
                }

                vec2 layout = fragment.bstate.position;
                auto lineHeight = font.lineHeight;
                auto buffer = buffers[curBuffer].buffer;
                foreach (line; fragment.bstate.text.splitter('\n')) {
                    layout.x = 0; layout.y += lineHeight;
                    foreach (quad; atlas.getQuads(font, line.byDchar, layout.x, layout.y, false)) {
                        buffer.pushQuad(quad);
                    }
                    log.write("wrote line; cursor = %0.2f, %0.2f", layout.x, layout.y);
                }
                buffer.shouldRender = true;
            }
        }
    }

    private SharedTGB[] tmp_renderBuffers;

    // call from graphics thread
    void renderFragments () {
        tmp_renderBuffers.length = 0;
        synchronized {
            foreach (buffer; buffers) {
                if (buffer.shouldRender)
                    tmp_renderBuffers ~= buffer;
            }
            if (tmp_renderBuffers.length > 0) {
                tmp_renderBuffers.sort!"cast(size_t)&a.atlas";
                textShader.bind();
                PackedFontAtlas curAtlas = null;
                foreach (rb; tmp_renderBuffers) {
                    if (rb.atlas != curAtlas) {
                        rb.atlas.update();
                        rb.atlas.bind();
                    }
                    rb.buffer.update();
                    rb.buffer.draw();
                }
            }
        }
    }


    //
    //  Old API / rendering subsystem:
    //

    static void writeText (
        string text,
        Font font,
        TextGeometryBuffer buffer,
        PackedFontAtlas atlas,
        TextLayout layout,
        float screenScale = 1.0
    ) {
        auto charset = new RedBlackTree!dchar();
        foreach (chr; byDchar(text))
            if (chr >= 0x20)
                charset.insert(chr);

        auto scale = font.getScale(screenScale);
        log.write("font scale = %f", scale);

        atlas.insertCharset(font, charset);

        synchronized (atlas.read) {
            synchronized (buffer.write) {
                foreach (line; text.splitter('\n')) {
                    layout.x = 0; layout.y += font.getLineHeight(scale);
                    foreach (quad; atlas.getQuads(font, line.byDchar, layout.x, layout.y, false)) {
                        buffer.pushQuad(quad);
                    }
                    log.write("wrote line; cursor = %0.2f, %0.2f", layout.x, layout.y);
                }
            }
        }
    }

    static class TextLayout {
        float x = 0, y = 0;
        void reset () {
            x = y = 0;
        }
    }

    class TextElement {
        Font font;
        TextGeometryBuffer textBuffer, testQuad;
        PackedFontAtlas packedAtlas;// = new FrontendPackedFontAtlas();
        TextLayout layouter;//   = new BasicLayouter();
        GraphicsBackend graphicsBackend;
        vec2 screenScaleFactor;

        string cachedText;

        WindowEvents.instance.onScreenScaleChanged.Connection scaleChangedSlot;

        this (string fontName, float size) {
            log.write("Creating new TextElement");
            this.font = new Font(fontName, size);

            screenScaleFactor = 1.0;// g_mainWindow.screenScale;
            //scaleChangedSlot = 
            //WindowEvents.instance.onScreenScaleChanged.connect((float x, float y) {
            //    log.write("recalculating buffers for new screen scale %0.2f", y);
            //    log.write("num chars = %d (expected tris = %d)", cachedText.length, cachedText.length * 2);
            //    screenScaleFactor.x = x; screenScaleFactor.y = y;
            //    layouter.reset();
            //    textBuffer.clear();
            //    writeText(cachedText, font, textBuffer, packedAtlas, layouter, screenScaleFactor.y);
            //        //screenScaleFactor.y == 1.0 ? screenScaleFactor.y : screenScaleFactor.y * 0.75);
            //});

            textBuffer  = new TextGeometryBuffer();
            packedAtlas = new PackedFontAtlas();
            layouter    = new TextLayout();
            testQuad    = new TextGeometryBuffer();

            stbtt_aligned_quad q;
            q.x0 = 0.1; q.y0 = 0.1; q.x1 = 0.9; q.y1 = 0.9;
            q.s0 = 0; q.t0 = 0; q.s1 = 1; q.t1 = 1;
            testQuad.pushQuad(q);

            graphicsBackend = new GraphicsBackend();
        }
        ~this () {
            log.write("Deleting TextElement");
            graphicsBackend.deactivate();
            packedAtlas.releaseResources();
        }

        void append (string text) {
            //log.write("Writing text '%s'", text);
            cachedText ~= text;
            writeText(text, font, textBuffer, packedAtlas, layouter, screenScaleFactor.y);
        }

        class GraphicsBackend : IGraphicsComponent {
            TextGeometryBuffer.GraphicsBackend textBufferBackend, testQuadBackend;
            PackedFontAtlas.GraphicsBackend packedAtlasBackend;// = new BackendPackedFontAtlas();
            bool isActive = true;

            this () {
                log.write("Creating new TextElement.GraphicsBackend");

                textBufferBackend = textBuffer.new GraphicsBackend();
                testQuadBackend   = textBuffer.new GraphicsBackend();
                testQuadBackend.update();

                packedAtlasBackend = packedAtlas.new GraphicsBackend();
                registerComponent(this);
            }
            void deactivate () {
                isActive = false;
                textBufferBackend.releaseResources();
                testQuadBackend.releaseResources();
                packedAtlasBackend.releaseResources();
            }
            bool active () { return isActive; }

            void render () {
                textBufferBackend.update();
                packedAtlasBackend.update();

                textShader.bind();
                packedAtlasBackend.bindTexture();

                auto inv_scale_x = 1.0 / g_mainWindow.screenDimensions.x;
                auto inv_scale_y = 1.0 / g_mainWindow.screenDimensions.y;
                auto transform = mat4.identity()
                    .scale(inv_scale_x, inv_scale_y, 1.0)
                    .translate(-1.0, 1.0, 0.0);
                transform.transpose();
                textShader.transform = transform;

                textShader.backgroundColor = vec3(0, 0, 0);
                textBufferBackend.draw();

                textShader.backgroundColor = vec3(0.2, 0.7, 0.45);
                testQuadBackend.draw();
            }
        }
    }

    auto createTextElement (string fontName, float fontSize) {
        return new TextElement(fontName, fontSize);
    }



/+
    // Utility that defines how font sizes get translated into real screen pixels.
    // This can be defined:
    //  - per font-id (ie. "arial", "helvetica", defined in FontAtlas)
    //  - with arbitrary mechanics (eg. real-screen-size = 20 * lg(px, 10) + 13 * sin(px / 40 * pi))
    //  - for specific screen resolutions (1x pixel density, 2x, etc).
    //
    // To enable all of these options, we implement this by calling setFontScale for each supported
    // resolution:
    //     setFontScale("arial", 1.0, px => px * 1.0 * some_scaling_factor);
    //     setFontScale("arial", 2.0, px => px * 2.0 * some_scaling_factor);
    // If an unsupported screen scale is used, we'll default to interpolating between the two
    // nearest points (linear interpolation); this handles the "2.5" case decently (though it's
    // dubious if this will ever be useful), and for "3.0", "0.5", etc., it just defaults to
    // the nearest defined case ("2.0" / "1.0" respectively).
    //
    // This implementation is overkill (scaling options that won't / shouldn't ever get used?), but it _does_ 
    // implement resolution scaling and arbitrary font scaling quite nicely
    //
    // For cases that are not explicitely defined, we default to screen_scale * px.
    //
    static class FontScaler {
        struct ControlPoint { double pt; delegate double(double) calcSz; }
        enum ScalingType { Linear };
        struct ScaleHint {
            ControlPoint[] points;
            ScalingType type = ScalingType.Linear;
        }
        ScaleHint[string] fontScalingHints;

        void setFontScale (string name, double scale, delegate double(double) calcSz) {
            if (name in fontScalingHints) {
                fontScalingHints[name].points ~= ControlPoint(scale, calcSz);
                sort!"a.pt < b.pt"(fontScalingHints[name].points);
            } else {
                fontScalingHints[name] = ScaleHint();
                fontScalingHints[name].points = [ ControlPoint(scale, calcSz) ];
            }
        }

        double getFontScale (string name, double scale, double sz) {
            if (name in fontScalingHints) {
                auto ref hint = fontScalingHints[name];
                assert(hint.points.length != 0);

                // If scale is at or beyond end bounds, return scaled by end bounds
                if (scale <= hint.points[0].pt || hints.points.length == 1)
                    return hint.points[0].calc(sz);
                if (scale >= hint.points[$-1].pt)
                    return hint.points[$-1].calc(sz);

                // Otherwise, find nearest two + interpolate
                int n = 0, m = 1;
                while (hint.points[m].pt < scale && m < hint.points.length)
                    ++n, ++m;
                assert(n < scale && m > scale);
                switch (hint.type) {
                    case ScalingType.Linear:
                        return hint.points[m].calc(sz) * (scale - n) / (n - m) +
                               hint.points[n].calc(sz) * (m - scale) / (n - m);
                }
            } else {
                return sz * scale;
            }
        }

        unittest {
            import std.math: approxEqual;

            auto s = new FontScaler();
            s.setFontScale("foo", 1.0, s => s * 0.9);
            s.setFontScale("foo", 2.0, s => s * 2.5);
            s.setFontScale("foo", 2.5, s => s * 3.0);

            // Check that font scaling works w/ 3 control points
            // (uses linear interpolation for inbetweens; clamps to last points at ends)
            assert(approxEqual(s.getFontScale("foo", 0.5, 1.0), 0.9, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 1.0, 1.0), 0.9, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 1.2, 1.0), 1.22, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 1.5, 1.0), 1.7, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 1.9, 1.0), 2.34, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 2.0, 1.0), 2.5, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 2.2, 1.0), 2.7, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 2.5, 1.0), 3.0, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 3.0, 1.0), 3.0, 1e-5));

            // Check that we're applying font-size scaling as well
            assert(approxEqual(s.getFontScale("foo", 1.0, 40.0), 36.0, 1e-5));
            assert(approxEqual(s.getFontScale("foo", 1.25, 53.4), 62.745, 1e-5));

            // Check that:
            // - one-point scaling works properly (rule is applied to all scales)
            // - 
            s.setFontScale("bar", 31.5, s => 20.0 + s * 0.35);
            assert(approxEqual(s.getFontScale("bar", 1.0, 40.0), 34.0, 1e-5));
            assert(approxEqual(s.getFontScale("bar", 3.14159, 50.0), 37.5, 1e-5));

            assert(approxEqual(s.getFontScale("baz", 1.0, 40.0), 40.0, 1e-5));
            assert(approxEqual(s.getFontScale("baz", 2.0, 40.0), 80.0, 1e-5));
            assert(approxEqual(s.getFontScale("baz", 1.95, 40.0), 78.0, 1e-5));
        }
    }

+/
}
