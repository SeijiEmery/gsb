module gsb.text.textrenderer;
import gsb.coregl;

import gsb.core.log;
import gsb.core.window;
import gsb.core.errors;
import gsb.core.singleton;
import gsb.text.textshader;
import gsb.text.font;
import gsb.text.geometrybuffer;
import gsb.text.fontatlas;
import gsb.utils.color;

import std.format;
import std.utf;
import std.conv;
import std.container.rbtree;
import std.algorithm.setops;
import std.algorithm.mutation : move, swap;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.typecons;
import std.math: approxEqual;
import core.sync.rwmutex;

import stb.truetype;

private void DEBUG_LOG (lazy void expr) {
    static if (TEXTRENDERER_DEBUG_LOGGING_ENABLED) expr();
}

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
    protected bool  dirtyFontAttrib = true;
    protected bool  dirtyContent    = true;
    private bool dirtyBounds = true;
    vec2   cachedBounds;

    ulong id;
    static private __gshared ulong _nextId = 0;

    this (string text, Font font, Color color, vec2 position) {
        fstate.text = text;
        fstate.font = font;
        fstate.color = color;
        fstate.position = position + offset;
        id = _nextId++;
        attach();
    }
    void attach  () { TextRenderer.instance.attachFragment(this); }
    void detatch () { TextRenderer.instance.removeFragment(this); }
    ~this () { detatch(); }

    void toString (scope void delegate (const(char)[]) sink) const {
        sink(format("TextFragment %d", id));
    }

    //int opCmp (TextFragment f) {
    //    return uid == f.uid ? 0 :
    //           uid < f.uid  ? -1 : 1;
    //}

    protected void swapState () {
        if (dirtyState) {
            synchronized { bstate = fstate; dirtyState = dirtyContent = dirtyFontAttrib = false; }
        }
    }
    public void forceUpdate () {
        synchronized { dirtyState = true; }
    }

    @property auto text () { return fstate.text; }
    @property void text (string v) { 
        synchronized { fstate.text = v; dirtyState = true; dirtyBounds = true; dirtyContent = true; }
    }
    @property auto font () { return fstate.font; }
    @property void font (Font v) {
        synchronized { fstate.font = v; dirtyState = true; dirtyBounds = true; dirtyFontAttrib = true; }
    }
    @property auto color () { return fstate.color; }
    @property void color (Color v) {
        synchronized { fstate.color = v; dirtyState = true; }
    }
    @property auto position () { return fstate.position - offset; }
    @property void position (vec2 v) {
        synchronized { fstate.position = v + offset; dirtyState = true; }
    }
    @property auto bounds () {
        synchronized { return dirtyBounds ? calcBounds() : cachedBounds; }
    }
    private auto calcBounds () {
        dirtyBounds = false;
        return cachedBounds = fstate.font.calcPixelBounds(fstate.text);
    }
    // represents v-offset that text should be rendered at
    private @property auto offset () {
        return vec2(0, fstate.font.lineOffsetY);
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
            //DEBUG_LOG(log.write("TextRenderer -- preparing to draw frame"));
            synchronized {
                for (auto i = cast(int)components.length - 1; i >= 0; --i) {
                    //DEBUG_LOG(log.write("-- checking component %d", i));
                    if (!components[i].active()) {
                        //DEBUG_LOG(log.write("-- removing component %d", i));
                        if (i != components.length - 1)
                            swap(components[i], components[$-1]);
                        components.length -= 1;
                    } else {
                        //DEBUG_LOG(log.write("-- rendering component %d", i));
                        components[i].render();
                    }
                }
            }
            //DEBUG_LOG(log.write("TextRenderer: Finished drawing frame"));
        }
        void registerComponent (IGraphicsComponent component) {
            synchronized {
                components ~= component;
            }
            //DEBUG_LOG(log.write("registered component"));
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
        DEBUG_LOG(log.write("Creating new TextRenderer graphics thread handle"));
        return new GThreadHandle();
    }


    //
    // New API / rendering subsystem:
    //

    alias TextFragmentSet = RedBlackTree!(TextFragment, "a.id < b.id");

    private TextFragmentSet fragments;
    private TextFragment[]  deletedFragments;
    this () {
        fragments = new TextFragmentSet();
    }

    void attachFragment (TextFragment fragment) {
        DEBUG_LOG(log.write("Attaching %s", fragment));
        fragments.insert(fragment);
    }
    void removeFragment (TextFragment fragment) {
        if (fragment in fragments) {
            DEBUG_LOG(log.write("Removing %s", fragment));
            fragments.remove(fragments.equalRange(fragment));
            deletedFragments ~= fragment;
        } else {
            DEBUG_LOG(log.write("Already removed: %s!", fragment));
        }
    }
    struct SharedAtlas {
        PackedFontAtlas atlas;// = new PackedFontAtlas();
        PackedFontAtlas.GraphicsBackend gbackend;

        int refcount = 0;

        static SharedAtlas create () {
            SharedAtlas s;
            s.atlas = new PackedFontAtlas();
            return s;
        }
        void release () { atlas.release(); }
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
            if (fragment.currentAtlas >= 0)
                atlases[fragment.currentAtlas].refcount--;
            if (fragment.currentTextBuffer >= 0)
                buffers[fragment.currentTextBuffer].dflag = true;
            anyBufferChanges = true;
            DEBUG_LOG(log.write("Removed fragment %d (buffer %d, atlas %d))",
                fragment.id, fragment.currentTextBuffer, fragment.currentAtlas));
        }
        foreach (fragment; fragments) {
            if (fragment.dirtyFontAttrib) {
                DEBUG_LOG(log.write("Fragment %d needs new atlas (was %d)", fragment.id, fragment.currentAtlas));
                if (fragment.currentAtlas > 0)
                    atlases[fragment.currentAtlas].refcount--;
                fragment.currentAtlas = -1;
                assert(fragment.dirtyState);
            }
            if (fragment.dirtyState) {
                DEBUG_LOG(log.write("Fragment %d needs new buffer (was %d)", fragment.id, fragment.currentTextBuffer));
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
                    DEBUG_LOG(log.write("Fragment %d changing buffer because buffer contents changed (%d))",
                        fragment.id, fragment.currentTextBuffer));
                    fragment.currentTextBuffer = -1;
                    if (isVisible(fragment)) {
                        addList ~= fragment;
                    }
                }
            }

            DEBUG_LOG(log.write("-- Rebuilding %d fragments --", addList.length));
            synchronized {
                foreach (i; 0..buffers.length) {
                    if (buffers[i].dflag) {
                        DEBUG_LOG(log.write("Releasing buffer %d", i));
                        buffers[i].dflag = false;
                        buffers[i].shouldRender = false;
                        freeBuffers ~= i;
                        buffers[i].buffer.clear();
                    }
                }
            }

            // update atlas + swap state
            foreach (fragment; addList) {
                // charset might have changed if text content changed, and it _definitely_ needs to be
                // re-added if the font atlas changed
                auto dirtyCharset = fragment.dirtyContent || fragment.currentAtlas == -1;

                if (fragment.currentAtlas == -1) {
                    auto fontid = fragment.font.stringId;
                    if (fontid !in atlasLookup) {
                        DEBUG_LOG(log.write("Creating new atlas %d", atlases.length));
                        atlasLookup[fontid] = atlases.length;
                        fragment.currentAtlas = cast(int)atlases.length;
                        atlases ~= SharedAtlas.create();
                        atlases[$-1].refcount++;
                    } else {
                        fragment.currentAtlas = cast(int)atlasLookup[fontid];
                        atlases[fragment.currentAtlas].refcount++;
                    }
                    DEBUG_LOG(log.write("Fragment %d set atlas %d", fragment.id, fragment.currentAtlas));
                }
                assert(fragment.currentAtlas >= 0 && fragment.currentAtlas < atlases.length);
                auto sharedAtlas = atlases[fragment.currentAtlas];

                // Resets dirty flags + updates bstate to fstate
                fragment.swapState();

                if (dirtyCharset) {
                    DEBUG_LOG(log.write("Fragment %d re-inserting charset into atlas %d", fragment.id, fragment.currentAtlas));
                    tmp_charset.clear();
                    foreach (chr; fragment.bstate.text.byDchar)
                        if (chr >= 0x20)
                            tmp_charset.insert(chr);
                    sharedAtlas.atlas.insertCharset(fragment.font, tmp_charset);
                }
            }

            //// clear non-referenced atlas textures
            //for (auto i = atlases.length; i --> 0; ) {
            //    if (atlases[i].refcount < 0) {
            //        log.write("Removing atlas %s: %s", i, atlases[i]);
            //        atlases[i].release();

            //        auto k = atlases.length - 1;
            //        if (k != i) {
            //            log.write("Replace index occurances: %s => %s (length %s)", k, i, atlases.length);
            //            atlases[i] = atlases[k];
            //            foreach (kv; atlasLookup.byKeyValue) {
            //                if (kv.value == k) {
            //                    log.write("Updating index: %s => %s", k, i);
            //                    atlasLookup[kv.key] = i;
            //                }
            //            }
            //        }
            //        atlases.length--;
            //    }
            //}

            // write buffers
            addList.sort!((a,b) => a.currentAtlas < b.currentAtlas);
            int curAtlas = -1, curBuffer = -1;
            foreach (fragment; addList) {
                DEBUG_LOG(log.write("Fragment %d writing to buffer (atlas %d)", fragment.id, fragment.currentAtlas));
                if (fragment.currentAtlas != curAtlas) {
                    DEBUG_LOG(log.write("atlas changed to %d; fetching new buffer", fragment.currentAtlas));
                    curAtlas = fragment.currentAtlas;
                    if (freeBuffers.length > 0) {
                        DEBUG_LOG(log.write("Recycling buffer %d", freeBuffers[$-1]));
                        curBuffer = cast(int)freeBuffers[$-1]; freeBuffers.length--;
                    } else {
                        DEBUG_LOG(log.write("Creating new buffer %d", buffers.length));
                        buffers ~= SharedTGB.create();
                        curBuffer = cast(int)buffers.length-1;
                    }
                    fragment.currentTextBuffer = curBuffer;
                    buffers[curBuffer].atlas = atlases[curAtlas].atlas;
                }

                vec2 layout = fragment.bstate.position;
                auto lineHeight = fragment.font.lineHeight, x0 = fragment.bstate.position.x;
                auto buffer = buffers[curBuffer].buffer;
                auto atlas  = atlases[curAtlas].atlas;
                //DEBUG_LOG(log.write("Font scale = %f, pixelsize = %f, height = %f, height2 = %f", fragment.font.getScale(1.0)),
                //    fragment.font.getSize(1.0), fragment.font.getLineHeight(1.0),
                //    fragment.font.lineHeight);
                //DEBUG_LOG(log.write("cursor = %0.2f, %0.2f", layout.x, layout.y));
                foreach (line; fragment.bstate.text.splitter('\n')) {
                    layout.x = x0; layout.y += lineHeight;
                    foreach (quad; atlas.getQuads(fragment.font, line.byDchar, layout.x, layout.y, false)) {
                        buffer.pushQuad(quad, fragment.color);
                    }
                    DEBUG_LOG(log.write("wrote line; cursor = %0.2f, %0.2f (atlas %d, buffer %d))", 
                        layout.x, layout.y, curAtlas, curBuffer));
                }
                buffers[curBuffer].shouldRender = true;
            }
            DEBUG_LOG(log.write("-- Finished rebuilding fragments --"));
        }
    }

    private SharedTGB[] tmp_renderBuffers;
    private uint frameCount = 0;
    private immutable uint logMessageAtFrameCount = 10; // log every N frames

    // call from graphics thread
    void renderFragments () {
        tmp_renderBuffers.length = 0;
        synchronized {
            foreach (buffer; buffers) {
                if (buffer.shouldRender)
                    tmp_renderBuffers ~= buffer;
            }
            void everyNFrame (lazy void expr) {
                if (frameCount++ % logMessageAtFrameCount == 0)
                    expr();
            }

            if (tmp_renderBuffers.length > 0) {
                //everyNFrame(DEBUG_LOG(log.write("Rendering %d text buffers", tmp_renderBuffers.length)));
                tmp_renderBuffers.sort!((SharedTGB a, SharedTGB b) => 
                    cast(size_t)cast(void*)a.atlas < cast(size_t)cast(void*)b.atlas);

                textShader.bind();

                auto inv_scale_x = 1.0 / g_mainWindow.screenDimensions.x * 2.0;
                auto inv_scale_y = 1.0 / g_mainWindow.screenDimensions.y * 2.0;
                auto transform = mat4.identity()
                    .scale(inv_scale_x, inv_scale_y, 1.0)
                    .translate(-1.0, 1.0, 0.0);
                transform.transpose();
                textShader.transform = transform;

                PackedFontAtlas curAtlas = null; int i = 0;
                foreach (rb; tmp_renderBuffers) {
                    //everyNFrame(DEBUG_LOG(log.write("Rendering buffer %d", i++)));
                    if (rb.atlas != curAtlas) {
                        //everyNFrame(DEBUG_LOG(log.write("Switching atlas")));
                        rb.atlas.backend.update();
                        rb.atlas.backend.bindTexture();
                    }
                    rb.buffer.backend.update();
                    rb.buffer.backend.draw();
                }
            }
        }
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
