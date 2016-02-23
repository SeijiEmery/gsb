
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


// Shared singleton class accessed by lazy .instance
class TextRenderer {
    mixin LowLockSingleton;

    auto textShader = new TextShader();
    auto componentList = new GraphicsComponentList();

    //private struct PerFrameGraphicsState {}
    //PerFrameGraphicsState[2] graphicsState;

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


    static void writeText (
        string text,
        Font font,
        TextGeometryBuffer buffer,
        PackedFontAtlas atlas,
        TextLayouter layouter,
        float screenScale = 1.0
    ) {
        auto rbcharset = new RedBlackTree!dchar();
        foreach (chr; byDchar(text))
            if (chr >= 0x20)
                rbcharset.insert(chr);

        auto scale = font.getScale(screenScale);
        log.write("font scale = %f", scale);

        atlas.insertCharset(font, rbcharset);

        layouter.lineAscent = font.getLineHeight(scale);

        synchronized (atlas.read) {
            synchronized (buffer.write) {
                foreach (line; text.splitter('\n')) {
                    layouter.x = 0; layouter.y += font.getLineHeight(scale);
                    foreach (quad; atlas.getQuads(font, line.byDchar, layouter.x, layouter.y, false)) {
                        buffer.pushQuad(quad);
                    }
                    log.write("wrote line; cursor = %0.2f, %0.2f", layouter.x, layouter.y);
                }
                //stbtt_aligned_quad q;
                //foreach (chr; byDchar(text)) {
                //    if (chr >= 0x20) {
                //        layouter.writeChar(chrLookup[chr], buffer, atlas);
                //    } else if (chr == '\n') {
                //        layouter.writeEndl();
                //    } else {
                //        log.write("character %d not supported (%s)", fullyQualifiedName!(writeText));
                //    }
                //}
            }
        }
    }

    static uint BITMAP_WIDTH = 1024, BITMAP_HEIGHT = 1024, BITMAP_CHANNELS = 1;

    // Lives on main / worker thread
    static class FrontendPackedFontAtlas {
        ubyte[] bitmapData;
        stbtt_pack_context pack;
        stbtt_packedchar[] packedChars;
        size_t[string] packedCharLookup;

        bool needsUpdate = false;

        ReadWriteMutex rwMutex;
        public auto @property read () { return rwMutex.reader(); }
        public auto @property write () { return rwMutex.writer(); }

        private void lazyInit () {
            if (!bitmapData) {
                log.write("Initializing PackedFontAtlas frontend data");
                bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * BITMAP_CHANNELS];
                if (!stbtt_PackBegin(&pack, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, null)) {
                    throw new ResourceError("stbtt_PackBegin failed");
                }
                stbtt_PackSetOversampling(&pack, 1, 1);
            }
        }
        public void deleteResources () {
            if (bitmapData) {
                log.write("Cleaning up PackedFontAtlas frontend data");
                stbtt_PackEnd(&pack);
                bitmapData = null;
            }
        }
        ~this () {
            deleteResources();
        }

        auto insertAndGetIndex (dchar chr, string fontname, float screenScale, Font font) {
            lazyInit();
            needsUpdate = true;

            auto hashedName = format("%s.%d:%c", fontname, to!int(font.getSize(screenScale)), chr);
            if (hashedName !in packedCharLookup) {
                //log.write("PackedFontAtlas frontend: Adding %s", hashedName);

                //if (!stbtt_PackBegin(&pack, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, null)) {
                //    throw new ResourceError("stbtt_PackBegin failed");
                //}
                //stbtt_PackSetOversampling(&pack, 1, 1);

                packedChars.length += 1;

                stbtt_pack_range r;
                r.font_size = font.getSize(screenScale);
                r.first_unicode_codepoint_in_range = 0;
                r.array_of_unicode_codepoints = cast(int*)&chr;
                r.num_chars = 1;
                r.chardata_for_range = &packedChars[$-1];
                stbtt_PackFontRanges(&pack, font.data.contents.ptr, 0, &r, 1);

                //stbtt_PackFontRange(&pack, font.fontData.contents.ptr, font.fontData.index, fontScale, 
                    //chr, 1, &packedChars[$-1]);

                //stbtt_PackEnd(&pack);
                return packedCharLookup[hashedName] = packedChars.length -1;
            }
            return packedCharLookup[hashedName];
        }
        void getQuad (size_t index, stbtt_aligned_quad* q, float* x, float* y, bool align_to_integer) {
            stbtt_GetPackedQuad(packedChars.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, cast(int)index, x, y, q, align_to_integer);
        }
    }

    // Lives on graphics thread
    static class BackendPackedFontAtlas {
        FrontendPackedFontAtlas target = null;
        GLuint texture = 0;

        void bindTexture () {
            if (target && target.needsUpdate) {
                lazyInitResources();
                //synchronized (target.read()) {
                    checked_glActiveTexture(GL_TEXTURE0);
                    checked_glBindTexture(GL_TEXTURE_2D, texture);
                    checked_glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, BITMAP_WIDTH, BITMAP_HEIGHT, 0, GL_RED, GL_UNSIGNED_BYTE, target.bitmapData.ptr);
                    checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                    checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                //}
                //synchronized (target.write()) {
                    target.needsUpdate = false;
                //}
            }
            if (texture != 0) {
                //log.write("binding texture");
                checked_glActiveTexture(GL_TEXTURE0);
                checked_glBindTexture(GL_TEXTURE_2D, texture);
            } else {
                log.write("null texture!");
            }
        }
        this () {
            log.write("Creating PackedFontAtlas graphics backend");
        }
        private void lazyInitResources () {
            if (!texture) {
                log.write("Initializing PackedFontAtlas graphics resources");
                checked_glGenTextures(1, &texture);
            }
        }
        void deleteResources () {
            if (texture) {
                log.write("Cleaning up PackedFontAtlas graphics resources");
                checked_glDeleteTextures(1, &texture);
                texture = 0;
            }
        }
    }

    static class TextLayouter {
        float x = 0, y = 0;
        float _lineAscent = 0.0;
        mat4  _transform  = mat4.identity;

        public @property float lineAscent () { return _lineAscent; }
        public @property void  lineAscent (float v) { 
            y = y - _lineAscent + v; // hack...
            _lineAscent = v; log.write("Set lineAscent %f", v);
        }
        public @property mat4  transform  () { return _transform; }

        this () {
            log.write("creating Textlayouter");
        }

        //void writeChar (size_t charIndex, TextGeometryBuffer buffer, FrontendPackedFontAtlas atlas) {
        //    stbtt_aligned_quad q;
        //    atlas.getQuad(charIndex, &q, &x, &y, true);
        //    buffer.pushQuad(q);
        //}
        //void writeEndl () {
        //    x = 0;
        //    y += _lineAscent;
        //}
        void reset () {
            x = y = 0;
            _lineAscent = 0;
        }
    }

    class TextElement {
        Font font;
        TextGeometryBuffer textBuffer, testQuad;
        PackedFontAtlas packedAtlas;// = new FrontendPackedFontAtlas();
        TextLayouter layouter;//   = new BasicLayouter();
        GraphicsBackend graphicsBackend;
        vec2 screenScaleFactor;

        string cachedText;

        WindowEvents.instance.onScreenScaleChanged.Connection scaleChangedSlot;

        this (string fontName, float size) {
            log.write("Creating new TextElement");
            this.font = new Font(fontName, size);

            screenScaleFactor = g_mainWindow.screenScale;
            scaleChangedSlot = 
            WindowEvents.instance.onScreenScaleChanged.connect((float x, float y) {
                log.write("recalculating buffers for new screen scale %0.2f", y);
                log.write("num chars = %d (expected tris = %d)", cachedText.length, cachedText.length * 2);
                screenScaleFactor.x = x; screenScaleFactor.y = y;
                layouter.reset();
                textBuffer.clear();
                writeText(cachedText, font, textBuffer, packedAtlas, layouter, screenScaleFactor.y);
                    //screenScaleFactor.y == 1.0 ? screenScaleFactor.y : screenScaleFactor.y * 0.75);
            });

            textBuffer  = new TextGeometryBuffer();
            packedAtlas = new PackedFontAtlas();
            layouter    = new TextLayouter();
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

                auto inv_scale_x = 1.0 / g_mainWindow.pixelDimensions.x;
                auto inv_scale_y = 1.0 / g_mainWindow.pixelDimensions.y;
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


    //enum RelPos {
    //    TOP_LEFT
    //}

    //auto createTextElement () {
    //    log.write("Created text element");
    //    return new TextElementHandle();
    //}

    //static class TextElementHandle {
    //    auto style (string name) {
    //        log.write("Set style '%s'", name);
    //        return this;
    //    }
    //    auto fontSize (double size) {
    //        log.write("Set font size '%0.2f'", size);
    //        return this;
    //    }
    //    auto position (RelPos rel, float x, float y) {
    //        log.write("Set position to %0.2f, %0.2f", x, y);
    //        return this;
    //    }
    //    auto bounds (float x, float y) {
    //        log.write("Set bounds %0.2f, %0.2f", x, y);
    //        return this;
    //    }
    //    auto color (string colorHash) {
    //        log.write("Set color %s", colorHash);
    //        return this;
    //    }
    //    auto scroll (bool scrollEnabled) {
    //        log.write("Set scrolling = %s", scrollEnabled ? "true" : "false");
    //        return this;
    //    }
    //    auto append (string text) {
    //        log.write("Appending text ");
    //        return this;
    //    }
    //}







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
