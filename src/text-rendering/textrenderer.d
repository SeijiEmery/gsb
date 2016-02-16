
module gsb.text.textrenderer;

import gsb.core.log;

import std.stdio;
import std.file;
import std.format;
import std.utf;
import std.conv;
import std.container.rbtree;
import std.algorithm.setops;
import std.algorithm.mutation : move;
import std.algorithm.iteration : map;
import std.array : join;
import std.parallelism;
import std.traits;
import std.typecons;
import std.math: approxEqual;
import core.sync.rwmutex;

import core.sync.rwmutex;

import stb.truetype;
import gsb.glutils;
import derelict.opengl3.gl3;
import dglsl;

// http://wiki.dlang.org/Low-Lock_Singleton_Pattern
mixin template LowLockSingleton () {
    private this () { log.write("Creating %s instance", fullyQualifiedName!(typeof(this))); }
    private static bool instantiated_ = false;
    private static __gshared typeof(this) instance_ = null;

    static final auto @property instance () {
        if (!instantiated_) {
            synchronized (typeof(this).classinfo) {
                if (!instance_)
                    instance_ = new typeof(this)();
                instantiated_ = true;
            }
        }
        return instance_;
    }
}




// Shared data; owned by main thread / app startup
// There should only be one instance of this in the entire program
class TextRenderer {
    mixin LowLockSingleton;

    FontAtlas atlas = new FontAtlas();
    GraphicsComponentList componentList = new GraphicsComponentList();

    //private struct PerFrameGraphicsState {}
    //PerFrameGraphicsState[2] graphicsState;

    interface IGraphicsComponent {
        void render ();
        bool active ();
    }
    class GraphicsComponentList {
        IGraphicsComponent[] components;
        ReadWriteMutex       rwMutex;
        public auto @property read () { return rwMutex.reader(); }
        public auto @property write () { return rwMutex.writer(); }

        void processFrame () {
            synchronized (write) {
                for (auto i = components.length - 1; i >= 0; --i) {
                    if (!components[i].active()) {
                        if (i != components.length - 1)
                            swap(components[i], components[$-1]);
                        components.length -= 1;
                    } else {
                        components[i].render();
                    }
                }
            }
        }
    }

    void registerComponent (IGraphicsComponent component) {
        synchronized (componentList.write) {
            componentList.components ~= component;
        }
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
        return new GThreadHandle();
    }

    public void registerFont (string name, string path, int index, bool loadImmediate=false) {
        atlas.registerFont(name, path, index, loadImmediate);
    }
    public void loadDefaultFonts () {
        version(OSX) {
            //atlas.registerFonts("helvetica", "/System/Library/Fonts/Helvetica")
            atlas.registerFont("menlo", "/System/Library/Fonts/Menlo.ttc", 0);
            atlas.registerFont("arial", "/Library/Fonts/Arial Unicode.ttf", 0);

            atlas.registerFont("menlo-italic", "/System/Library/Fonts/Menlo.ttc", 1);
            atlas.registerFont("menlo-bold", "/System/Library/Fonts/Menlo.ttc", 2);
            atlas.registerFont("menlo-bold-italic", "/System/Library/Fonts/Menlo.ttc", 3);

            atlas.registerFont("georgia", "/Library/Fonts/Georgia.ttf");
            atlas.registerFont("georgia-bold", "/Library/Fonts/Georgia Bold.ttf");
            atlas.registerFont("georgia-italic", "/Library/Fonts/Georgia Italic.ttf");
            atlas.registerFont("georgia-bold-italic", "/Library/Fonts/Georgia Bold Italic.ttf");

            atlas.defineFontClass("logging")
                .defaultSize(50)
                .typeface("default", [ "menlo", "arial" ])
                .typeface("italic",  [ "menlo-italic", "arial-italic", "arial" ])
                .typeface("bold",    [ "menlo-bold", "arial-bold", "arial" ])
                .typeface("bold-italic", [ "menlo-bold-italic", "arial-bold-italic", "arial" ]);

            atlas.defineScreenScaling("arial", 1.0, sz => sz * 1.0);
            atlas.defineScreenScaling("arial", 2.0, sz => sz * 1.5);

            atlas.defineFontScaling("arial", FontScaling.RELATIVE_TO_BASELINE, (sz, default_scale) => sz * default_scale);

            atlas.loadFonts();

            //atlas.setFontScale("menlo", 1.0, sz => sz * 1.0);
            //atlas.setFontScale("menlo", 2.0, sz => sz * 1.5);

            //atlas.setFontScale("arial", 1.0, sz => sz * 1.0);
            //atlas.setFontScale("arial", 2.0, sz => sz * 1.5);

            //atlas.addFontClass("default", {
            //    .size = 50,
            //    .color = "#114015",
            //    .fonts = [ "menlo", "arial" ]
            //});
            //atlas.extendClass("default", "console", {
            //    .size = 30,
            //    .color = "#12092F",
            //    .fonts = [ "menlo", "arial" ]
            //});
        }
    }

    enum FontScaling {
        RELATIVE_TO_BASELINE
    }


    static class FontAtlas {
    final:
        struct FontPath {
            string path;
            int index;
        }
        FontPath[string]            registeredFonts;
        stbtt_fontinfo[string]      loadedFonts;

        struct FontClass {
            string[][string] typefaces;
            double defaultSize = 32.0;
        }
        FontClass[string] fontClasses;

        struct FontScalingFactors {
            double defaultScalingFactor = -1.0;
            double function(double, double) userDefinedFontScaling;
            auto fontScalingType = FontScaling.RELATIVE_TO_BASELINE;
            Tuple!(double, double function(double))[] userDefinedScreenScaling;

            this (const(stbtt_fontinfo)* info) {
                setScalingFactor(info);
            }

            void setScalingFactor (const(stbtt_fontinfo) * fontInfo) {
                final switch (fontScalingType) {
                    case FontScaling.RELATIVE_TO_BASELINE: {
                        int ascent;
                        stbtt_GetFontVMetrics(fontInfo, &ascent, null, null);
                        defaultScalingFactor = 1.0 / cast(double)ascent;
                    } break;
                }
            }
            double getFontScale (double size, double screenScale = 1.0) {
                size = userDefinedFontScaling ? 
                    userDefinedFontScaling(size, defaultScalingFactor) :
                    size * defaultScalingFactor;

                foreach (v; userDefinedScreenScaling)
                    if (approxEqual(v[0], screenScale))
                        return v[1](size);
                return size * screenScale;
            }
        }
        FontScalingFactors[string] fontScales;

        double getFontScale (string name, double size, double screenScale = 1.0)
        in { assert(name in loadedFonts); }
        body {
            if (!(name in fontScales)) {
                fontScales[name] = FontScalingFactors(getFontData(name));
            }
            return fontScales[name].getFontScale(size, screenScale);
        }

        // Declarative interface
        struct FontClassSetter {
            private FontClass* fc;

            auto ref defaultSize (double size) {
                return fc.defaultSize = size, this;
            }
            auto ref FontClassSetter typeface (string name, string[] fonts) {
                return fc.typefaces[name] = fonts, this;
            }
        }
        FontClassSetter defineFontClass (string name) {
            auto fc = &(fontClasses[name] = FontClass());
            return FontClassSetter(fc);
        }
        void defineScreenScaling (string name, double scale, double function(double) cb) {
            if (!(name in fontScales))
                fontScales[name] = FontScalingFactors(getFontData(name));
            fontScales[name].userDefinedScreenScaling ~= tuple(scale, cb);
        }
        void defineFontScaling (string name, FontScaling scalingType, double function(double,double) cb) {
            if (!(name in fontScales))
                fontScales[name] = FontScalingFactors();
            fontScales[name].fontScalingType = scalingType;
            fontScales[name].userDefinedFontScaling = cb;
            fontScales[name].setScalingFactor(getFontData(name));
        }



        ReadWriteMutex mutex;
    
        void registerFont (string name, string path, int index = 0, bool loadImmediate=false) {
            if (!exists(path) || (!attrIsFile(getAttributes(path))))
                throw new ResourceError("Font '%s' does not exist", path);

            //synchronized (mutex.writer) {
                if (name in registeredFonts) {
                    auto prevPath = registeredFonts[name].path;
                    auto prevIndex = registeredFonts[name].index;

                    if (path != prevPath || index != prevIndex)
                        throw new ResourceError(format("Conflicting entries for font '%s': '%s'(%d), '%s'(%d)",
                            path, prevPath, prevIndex, path, index));
                } else {
                    registeredFonts[name] = FontPath(path, index);
                }
                if (name in loadedFonts)
                    loadImmediate = false;
            //}

            if (loadImmediate) {
                loadFonts();
            }
        }

        void loadFonts () {
            auto toLoad = setDifference(registeredFonts.keys, loadedFonts.keys);

            // Order fonts by filepath
            struct FontPair { string name; int index; }
            FontPair[][string] fontsByFilepath;

            //synchronized (mutex.writer) {
                foreach (name; toLoad) {
                    auto path = registeredFonts[name].path;
                    auto index = registeredFonts[name].index;

                    if (path in fontsByFilepath)
                        fontsByFilepath[path] ~= FontPair(name, index);
                    else
                        fontsByFilepath[path] = [ FontPair(name, index) ];
                }

                log.write("Loading paths: %s", join(fontsByFilepath.keys, ", "));

                //foreach (i, elem; taskPool.parallel(fontsByFilepath.byKeyValue(), 1)) {
                foreach (elem; fontsByFilepath.byKeyValue()) {
                    auto path = elem.key;
                    assert(exists(path) && attrIsFile(getAttributes(path)));

                    auto contents = cast(ubyte[])read(path);
                    if (contents.length == 0)
                        throw new ResourceError(format("Failed to load font data '%s'", path));

                    foreach (pair; elem.value) {
                        if (pair.name in loadedFonts) {
                            log.write("WARNING: huh, guess '%s' was already loaded? Oh well, reloading it anyway...", pair.name);
                        }

                        int offs = stbtt_GetFontOffsetForIndex(contents.ptr, pair.index);
                        if (offs == -1)
                            throw new ResourceError(format("Invalid font index: '%d' in '%s' (%s)", pair.index, path, pair.name));

                        stbtt_fontinfo info;
                        if (!stbtt_InitFont(&info, contents.ptr, offs))
                            throw new ResourceError(format("stb_truetype: Failed to load font '%s'[%d] (%s)", path, pair.index, pair.name));
                        loadedFonts[pair.name] = move(info);
                    }
                    log.write("Loaded %d font(s) from '%s': %s", elem.value.length, path, join(map!(x => x.name)(elem.value), ", "));
                }

            log.write("Loaded fonts: %s", join(loadedFonts.keys, ", "));

            //}
        }

        const(stbtt_fontinfo)* getFontData (string name) {
            if (name in loadedFonts)
                return &loadedFonts[name];
            if (name in registeredFonts) {
                loadFonts();
                if (name in loadedFonts)
                    return &loadedFonts[name];
            }
            throw new ResourceError(format("No registered font named '%s'", name));
        }

        ref stbtt_fontinfo getExactFont(string name) {
            //synchronized (mutex.reader) {

            if (!(name in loadedFonts)) {
                if (!(name in registeredFonts))
                    throw new ResourceError(format("No registered font named '%s'", name));
                loadFonts();
            }
            assert(name in loadedFonts);
            return loadedFonts[name];

            //}
        }
    }
    struct FontSpec {
        FontAtlas atlas;
        string name;     // font name
        float  size;     // font size
    }

    static void writeText (
        string text,
        FontSpec font,
        FrontendTextBuffer buffer,
        FrontendPackedFontAtlas atlas,
        TextLayouter layouter,
        float screenScale = 1.0
    ) {
        auto scale = font.atlas.getFontScale(font.name, font.size, screenScale);
        auto fontinfo = font.atlas.getFontData(font.name);

        auto rbcharset = new RedBlackTree!dchar();
        foreach (chr; byDchar(text))
            if (chr >= 0x20)
                rbcharset.insert(chr);

        int[dchar] chrLookup;
        synchronized (atlas.write) {
            foreach (chr; rbcharset) {
                chrLookup[chr] = atlas.insertAndGetIndex(chr, font.name, scale, fontinfo);
            }
        }

        layouter.lineHeight = font.lineHeight;

        synchronized (atlas.read) {
            synchronized (buffer.write) {
                stbtt_aligned_quad q;
                foreach (chr; byDchar(text)) {
                    if (chr >= 0x20) {
                        layouter.writeChar(chrLookup[chr], buffer, atlas);
                    } else if (chr == '\n') {
                        layouter.writeEndl();
                    } else {
                        log.write("character %d not supported (%s)", fullyQualifiedName!(writeText));
                    }
                }
            }
        }
    }

    static uint BITMAP_WIDTH = 1024, BITMAP_HEIGHT = 1024, BITMAP_CHANNELS = 1;

    // Lives on main / worker thread
    class FrontendPackedFontAtlas {
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
                bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * BITMAP_CHANNELS];
                if (!stbtt_PackBegin(&pack, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, null)) {
                    throw new ResourceError("stbtt_PackBegin failed");
                }
            }
        }
        public void deleteResources () {
            if (bitmapData) {
                stbtt_PackEnd(&pack);
                bitmapData = null;
            }
        }
        ~this () {
            deleteResources();
        }

        auto insertAndGetIndex (dchar chr, string fontname, float scale, ref FontSpec font) {
            lazyInit();
            needsUpdate = true;

            auto hashedName = format("%s.%d:%c", fontname, to!int(scale), chr);
            if (hashedName !in packedCharLookup) {
                log.write("Adding %s", hashedName);

                packedChars.length += 1;
                stbtt_PackFontRange(&pack, fontData, font.fontData, font.fontIndex, font.scale, 
                    chr, 1, &packedChars[$-1]);
                return packedCharLookup[hashedName] = packedChars.length -1;
            }
            return packedCharLookup[hashedName];
        }
        void getQuad (int index, stbtt_aligned_quad* q, float* x, float* y, bool align_to_integer) {
            stbtt_GetPackedQuad(packedChars.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, index, x, y, q, align_to_integer);
        }
    }

    // Lives on graphics thread
    class BackendPackedFontAtlas {
        FrontendPackedFontAtlas target = null;
        GLuint texture = 0;

        void bindTexture () {
            if (target && target.needsUpdate) {
                lazyInitResources();
                synchronized (target.read()) {
                    checked_glActiveTexture(GL_TEXTURE0);
                    checked_glBindTexture(GL_TEXTURE_2D, texture);
                    checked_glTexImage2D(GL_TEXTURE, 0, GL_RED, BITMAP_WIDTH, BITMAP_HEIGHT, 0, GL_RED, GL_UNSIGNED_BYTE, target.bitmapData.ptr);
                    checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                    checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                    checked_glBindTexture(GL_TEXTURE_2D, 0);
                }
                synchronized (target.write()) {
                    target.needsUpdate = false;
                }
            }
            if (texture != 0) {
                checked_glActiveTexture(GL_TEXTURE0);
                checked_glBindTexture(GL_TEXTURE_2D, texture);
            }
        }
        private void lazyInitResources () {
            if (!texture) {
                checked_glGenTextures(1, &texture);
            }
        }
        void deleteResources () {
            checked_glDeleteTextures(1, &texture);
        }
    }

    interface TextLayouter {
        void writeChar (dchar chr, size_t index);
    }

    class BasicLayouter : TextLayouter {
        vec2 position;
        public float lineAscent = 10.0;

        void writeChar (FrontendTextBuffer buffer, FrontendPackedFontAtlas atlas, size_t charIndex) {
            stbtt_aligned_quad q;
            atlas.getQuad(charIndex, &q, &position.x, &position.y, true);
            buffer.appendQuad(q);
        }
        void writeEndl (FrontendTextBuffer buffer, FrontendPackedFontAtlas atlas) {
            position.x = 0;
            position.y += lineAscent;
        }
    }

    // Lives on main / worker thread
    class FrontendTextBuffer {
        float[] positionData;
        float[] uvData;
        float[] colorData;
        protected bool needsUpdate = false;

        ReadWriteMutex rwMutex;

        protected auto @property read () {
            return rwMutex.reader();
        }
        protected auto @property write () {
            return rwMutex.writer();
        }
        protected auto @property positionBuffer () { return positionData; }
        protected auto @property uvBuffer       () { return uvData; }

        void appendQuad (stbtt_aligned_quad q) {
            quads ~= [
                q.x0, -q.y1, 0.0,   // flip y-axis
                q.x1, -q.y0, 0.0,
                q.x1, -q.y1, 0.0,

                q.x0, -q.y1, 0.0,
                q.x0, -q.y0, 0.0,
                q.x1, -q.y0, 0.0,
            ];
            uvs ~= [
                q.s0, q.t1,
                q.s1, q.t0,
                q.s1, q.t1,

                q.s0, q.t1,
                q.s0, q.t0,
                q.s1, q.t0
            ];
            needsUpdate = true;
        }
    }

    // Lives on gpu thread
    class BackendTextBuffer {
        FrontendTextBuffer target = null;
        GLuint vao = 0;
        GLuint[3] buffers;
        int    num_triangles = -1;

        void update () {
            if (target && target.needsUpdate) {
                lazyInitResources();
                synchronized (target.write()) {
                    target.needsUpdate = false;
                    if (const auto quads = target.positionBuffer) {
                        checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                        checked_glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_DYNAMIC_DRAW);
                        num_triangles = cast(int)(quads.length / 3);
                    }
                    if (const auto uvs = target.uvBuffer) {
                        checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
                        checked_glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_DYNAMIC_DRAW);
                    }
                }
            }
        }
        void draw () {
            if (vao) {
                checked_glBindVertexArray(vao);
                checked_glDrawArrays(GL_TRIANGLES, 0, num_triangles);
            }
        }

        private void lazyInitResources () {
            if (!vao) {
                checked_glGenVertexArrays(1, &vao);
                checked_glGenBuffers(3, buffers.ptr);

                checked_glBindVertexArray(vao);

                checked_glEnableVertexAttribArray(0);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);

                checked_glEnableVertexAttribArray(1);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
                checked_glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

                checked_glEnableVertexAttribArray(2);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[2]);
                checked_glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 0, null);
            }
        }

        public void deleteResources () {
            if (vao) {
                checked_glDeleteVertexArrays(1, &vao);
                checked_glDeleteBuffers(3, buffers.ptr);
                vao = 0;
            }
        }
        ~this () {
            deleteResources();
        }
    }

    class TextElement {
        FrontendTextBuffer textBuffer = new FrontendTextBuffer();
        FrontendPackedFontAtlas packedAtlas = new FrontendPackedFontAtlas();
        BasicLayouter layouter   = new BasicLayouter();
        GraphicsBackend graphicsBackend = new GraphicsBackend();
        vec2 screenScaleFactor;

        this (string fontName, float textSize) {
            screenScaleFactor = g_mainWindow.screenScalingFactor;
        }
        ~this () {
            graphicsBackend.deactivate();
        }

        void append (string text) {
            writeText(text, font, textBuffer, packedAtlas, layouter, screenScaleFactor.y);
        }

        class GraphicsBackend : IGraphicsComponent {
            BackendTextBuffer textBufferBackend = new BackendTextBuffer();
            BackendPackedFontAtlas packedAtlasBackend = new BackendPackedFontAtlas();
            bool isActive = true;

            this () {
                textBufferBackend.target = textBuffer;
                packedAtlasBackend.target = packedAtlas;

                registerComponent(this);
            }
            void deactivate () {
                isActive = false;
                textBufferBackend.deleteResources();
                packedAtlasBackend.deleteResources();
            }
            bool active () { return isActive; }

            void render () {
                textBuffer.update();
                packedAtlas.update();

                textShader.bind();
                packedAtlas.bindTexture();
                textBuffer.draw();
            }
        }
    }


    enum RelPos {
        TOP_LEFT
    }

    auto createTextElement () {
        log.write("Created text element");
        return new TextElementHandle();
    }

    static class TextElementHandle {
        auto style (string name) {
            log.write("Set style '%s'", name);
            return this;
        }
        auto fontSize (double size) {
            log.write("Set font size '%0.2f'", size);
            return this;
        }
        auto position (RelPos rel, float x, float y) {
            log.write("Set position to %0.2f, %0.2f", x, y);
            return this;
        }
        auto bounds (float x, float y) {
            log.write("Set bounds %0.2f, %0.2f", x, y);
            return this;
        }
        auto color (string colorHash) {
            log.write("Set color %s", colorHash);
            return this;
        }
        auto scroll (bool scrollEnabled) {
            log.write("Set scrolling = %s", scrollEnabled ? "true" : "false");
            return this;
        }
        auto append (string text) {
            log.write("Appending text ");
            return this;
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





















class ResourceError : Error {
    this (T...) (string fmt, T args) {
        super(format(fmt, args));
    }
}

class TextGeometryBuffer2 {
    GLuint vao = 0;
    GLuint[3] buffers;
    private bool dirty = true;
    private int ntriangles = 0;

    protected float[] quads;
    protected float[] uvs;
    protected float[] colors;

    void deleteBuffers () {
        if (vao) {
            checked_glDeleteVertexArrays(1, &vao);
            checked_glDeleteBuffers(3, buffers.ptr);
            vao = 0;
        }
    }
    ~this () {
        deleteBuffers();   
    }

    void pushQuad (ref stbtt_aligned_quad q, vec4 color) {

    }

    void bufferData () {
        dirty = false;
        if (!vao) {
            checked_glGenVertexArrays(1, &vao);
            checked_glBindVertexArray(vao);

            checked_glGenBuffers(3, buffers.ptr);

            checked_glEnableVertexAttribArray(0);
            checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
            checked_glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);

            checked_glEnableVertexAttribArray(1);
            checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
            checked_glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

            checked_glEnableVertexAttribArray(2);
            checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[2]);
            checked_glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 0, null);

            checked_glBindVertexArray(0);
        }
        checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
        checked_glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_DYNAMIC_DRAW);
        checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
        checked_glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_DYNAMIC_DRAW);
        checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[2]);
        checked_glBufferData(GL_ARRAY_BUFFER, colors.length * 4, colors.ptr, GL_DYNAMIC_DRAW);
        checked_glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    void draw () {
        if (dirty)
            bufferData();
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, ntriangles);
    }
}
























//static const string[string] fontdb = [
//    "helvetica": "/System/Library/Fonts/Helvetica.dfont",
//    "helvetica-neue": "/System/Library/Fonts/HelveticaNeue.dfont",
//    "lucida-grande": "/System/Library/Fonts/LucidaGrande.ttc",
//    "menlo": "/System/Library/Fonts/Menlo.ttc",
//    "avenir": "/System/Library/Fonts/Avenir.ttc",
//    "futura": "/Library/Fonts/Futura.ttc",
//    "anonymous-pro": "/Library/Fonts/Anonymous Pro.ttf"
//];

//alias stringlist = string[];

//static const stringlist[string] consoleFonts = [
//    "default": [ fontdb["menlo"], fontdb["anonymous-pro"], fontdb["helvetica"] ]
//];

//class PackedFontAtlas {
//    StbFont font;
//    stbtt_pack_context packCtx;
//    ubyte[] bitmapData; // single channel bitmap
//    int width, height;
//    int fontSize = 24;

//    stbtt_packedchar*[dchar] chrLookup;
//    stbtt_packedchar[] chrData = new stbtt_packedchar[1];

//    this (StbFont _font, int textureWidth, int textureHeight) {
//        if (_font is null)
//            throw new ResourceError("null font");

//        font = _font;
//        width = textureWidth;
//        height = textureHeight;
//        bitmapData = new ubyte[width * height];

//        if (!stbtt_PackBegin(&packCtx, bitmapData.ptr, width, height, 0, 1, null))
//            throw new ResourceError("stbtt_PackBegin(...) failed");
//    }

//    void packCharset (string chars) {
//        foreach (chr; chars) {
//            // pseudocode
//            if (!chrLookup[chr]) {
//                chrData.length += 1;
//                chrLookup[chr] = &chrData[chrData.length-1];
//                //stbtt_PackFontRange(packCtx, font.fontData, 0, fontSize, chr, 1, &chrData[chrData.length-1]);
//            }
//        }
//    }
//    void getPackedQuad (dchar chr, int pw, int ph, float * xpos, float * ypos, stbtt_aligned_quad * q, int align_to_integer) {
//        //if (!chrLookup[chr])
//        //    packCharset("" ~ chr);
//        stbtt_GetPackedQuad(chrLookup[chr], pw, ph, 0, xpos, ypos, q, align_to_integer);
//    }

//    ~this () {
//        stbtt_PackEnd(&packCtx);
//    }
//}

//class RasterizedTextElement {
//    PackedFontAtlas atlas;
//    vec2 nextPos;
//    vec2 bounds;
//    public float depth = 0;
//    public mat4 transform;

//    private GlTexture bitmapTexture;

//    this (PackedFontAtlas _atlas)
//    in { assert(!(atlas is null)); }
//    body {
//        atlas = _atlas;
//    }
//}



//immutable string DEFAULT_FONT = "/Library/Fonts/Verdana.ttf";
//immutable string[string] DEFAULT_TYPEFACE = [
//  "default": "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro.ttf",
//  "bold":    "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro B.ttf",
//  "italic":  "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro I.ttf",
//  "bolditalic": "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro BI.ttf"
//];


/+
class LogView {
    Log log;
    uint lastLineCount = 0;

    public vec2 bounds;
    public mat4 transform;

    BasicTextRenderer textRenderer = new BasicTextRenderer();

    vec2 currentTextBounds; // total bounds of layouted text
    vec2 nextLayoutPosition;

    vec2 viewPosition;      // current position (scroll, etc) in view

    this (Log _log)
    in { assert(!(_log is null)); }
    body {
        log = _log;
    }

    void render () {
        maybeUpdate();
        textRenderer.render();  
    }

    void maybeUpdate () {
        // TODO: Move this to async task; breakup logview / basictextrenderer into two parts:
        //  - async cpu-bound relayouting   (main thread => worker thread)
        //  - immediate gpu-bound rendering (gl thread)
        auto lines = log.lines;
        if (lastLineCount != lines.length) {
            for (auto i = lastLineCount; i < lines.length; ++i) {
                textRenderer.appendLine(log.lines[i]);
            }
            lastLineCount = cast(uint)lines.length;
        }
    }
    void render () {
        textRenderer.render();
    }
}

LogView setBounds (LogView view, float x, float y) {
    view.bounds.x = x;
    view.bounds.y = y;
    return view;
}
LogView setTransform (LogView view, mat4 transform) {
    view.transform = transform;
    return view;
}+/

/+
class BasicTextRenderer {
    StbFont font = new StbFont("/Library/Fonts/Anonymous Pro.ttf");
    float   fontSize = 24;

    vec2 nextLayoutPosition;
    vec2 currentBounds;

    PackedFontAtlas atlas;
    GlTexture       bitmapTexture;
    bool            setTexture = false;

    stbtt_packedchar*[dchar] chrLookup;
    stbtt_packedchar[] chrData;

    auto shader = new TextShader();
    auto gbuffer = new TextGeometryBuffer();

    void render () {
        shader.bind();
        if (!setTexture) {
            setTexture = true;
            //shader.bindTexture(bitmapTexture);
        }
        gbuffer.draw();
    }

    void appendLine (string line) {
        atlas.packCharset(line);

        stbtt_aligned_quad q;
        int pw = 24, ph = 24;
        foreach (chr; line) {
            if (chr == '\n') {
                nextLayoutPosition.x = 0;
                //nextLayoutPosition.y += something... // ph?
            } else {
                //atlas.getPackedQuad(chr, pw, ph, &nextLayoutPosition.x, &nextLayoutPosition.y, &q, false);
                //gbuffer.pushQuad([ q.x0, q.y0, q.x1, q.y1 ], [ q.s0, q.t0, q.s1, q.t1 ]);
            }
        }
    }
}+/

class TextVertexShader: Shader!Vertex {
    @layout(location=0)
    @input vec3 textPosition;

    @layout(location=1)
    @input vec2 bitmapCoords;

    @output vec2 texCoord;

    void main () {
        gl_Position = vec4(textPosition, 1.0);
        //gl_Position = vec4(
        //  textPosition.x * (1.0 / 800.0),
        //  textPosition.y * (1.0 / 600.0),
        //  0.0, 1.0);
        texCoord = bitmapCoords;
    }
}
class TextFragmentShader: Shader!Fragment {
    @input vec2 texCoord;
    @output vec4 fragColor;

    @uniform sampler2D textureSampler;

    void main () {
        //fragColor = vec3(1.0, 0.2, 0.2) + 
        //          vec3(0.0, outCoords);

        vec4 color = texture(textureSampler, texCoord);
        fragColor = vec4(color.r, color.r, color.r, color.r);
    }
}

class TextShader {
    TextFragmentShader fs = null;
    TextVertexShader vs = null;
    Program!(TextVertexShader, TextFragmentShader) prog = null;

    void lazyInit ()
    in { assert(prog is null); }
    body {
        fs = new TextFragmentShader(); fs.compile(); CHECK_CALL("compiling text fragment shader");
        vs = new TextVertexShader();   vs.compile(); CHECK_CALL("compiling text vertex shader");
        prog = makeProgram(vs, fs); CHECK_CALL("compiling/linking text shader program");

        checked_glUseProgram(prog.id);
        prog.textureSampler = 0; CHECK_CALL("set texture sampler");
        checked_glUseProgram(0);
    }

    void bind () {
        if (prog is null)
            lazyInit();
        checked_glUseProgram(prog.id);
    }
}

/+
class TextGeometryBuffer {
    //uint gl_positionBuffer = 0;
    //uint gl_texcoordBuffer = 0;
    uint gl_vao = 0;
    uint[3] gl_buffers;

    vec3[] cachedPositionData;
    vec2[] cachedTexcoordData;
    vec4[] cachedColorData;

    bool dirtyPositionData = false;
    bool dirtyTexcoordData = false;
    bool dirtyColorData = false;

    void lazyInit ()
    in { assert(gl_vao == 0); }
    body {
        checked_glGenVertexArrays(1, &gl_vao);
        checked_glBindVertexArray(gl_vao);

        checked_glGenBuffers(3, &gl_buffers[0]);

        checked_glEnableVertexAttribArray(0);
        checked_glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[0]);
        checked_glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);

        checked_glEnableVertexAttribArray(1);
        checked_glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[1]);
        checked_glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        checked_glEnableVertexAttribArray(2);
        checked_glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[2]);
        checked_glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 0, null);

        checked_glBindVertexArray(0); CHECK_CALL("glBindVertexArray(0)");
    }
    ~this () {
        if (gl_vao) {
            glDeleteVertexArrays(1, &gl_vao);
            glDeleteBuffers(3, &gl_buffers[0]);
        }
    }

    void pushQuad (vec2[4] points, vec2[4] uvs, float depth = 0) {
        cachedPositionData ~= vec3(points[0], depth);
        cachedPositionData ~= vec3(points[1], depth);
        cachedPositionData ~= vec3(points[2], depth);

        cachedPositionData ~= vec3(points[2], depth);
        cachedPositionData ~= vec3(points[1], depth);
        cachedPositionData ~= vec3(points[3], depth);

        cachedTexcoordData ~= uvs[0];
        cachedTexcoordData ~= uvs[1];
        cachedTexcoordData ~= uvs[2];

        cachedTexcoordData ~= uvs[2];
        cachedTexcoordData ~= uvs[1];
        cachedTexcoordData ~= uvs[3];

        dirtyPositionData = dirtyTexcoordData = true;
    }
    void clear () {
        dirtyPositionData = cachedPositionData.length != 0;
        dirtyTexcoordData = cachedPositionData.length != 0;
        cachedPositionData.length = 0;
        cachedTexcoordData.length = 0;
    }
    void flushChanges () {
        if (dirtyPositionData) {
            checked_glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[0]); CHECK_CALL("glBindBuffer");
            checked_glBufferData(GL_ARRAY_BUFFER, cachedPositionData.length * 4, cachedPositionData.ptr, GL_STATIC_DRAW); 
            CHECK_CALL("glBufferData (TextGeometryBuffer.flushChanges() (quads))");
            dirtyPositionData = false;
        }
        if (dirtyTexcoordData) {
            checked_glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[1]); CHECK_CALL("glBindBuffer");
            checked_glBufferData(GL_ARRAY_BUFFER, cachedTexcoordData.length * 4, cachedTexcoordData.ptr, GL_STATIC_DRAW); 
            CHECK_CALL("glBufferData (TextGeometryBuffer.flushChanges() (uvs))");
            dirtyTexcoordData = false;
        }
        if (dirtyColorData) {
            // Note: look into using vertex divisor for color data (ie. only upload 1 color per every quad (6 verts), not every vert...)
            glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[2]); CHECK_CALL("glBindBuffer");
            glBufferData(GL_ARRAY_BUFFER, cachedColorData.length * 4, cachedColorData.ptr, GL_STATIC_DRAW);
            CHECK_CALL("glBufferData (TextGeometryBuffer.flushChanges() (colors))");
            dirtyColorData = false;
        }

    }

    void bind () {
        if (!gl_vao) lazyInit();
        flushChanges();
        glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray (TextGeometryBuffer.bind())");
    }
    void draw () {
        if (cachedPositionData.length != 0) {
            bind();
            glDrawArrays(GL_TRIANGLES, 0, cast(int) cachedPositionData.length); CHECK_CALL("glDrawArrays (TextGeometryBuffer.draw())");
        }
    }
}+/

/+

class TextBuffer {
    Font font;
    float[] quads;
    float[] uvs;
    float x = 0, y = 0;
    float y_baseline = 0;
    float x_origin = 0, y_origin = 0;
    bool data_needs_rebuffering = false;

    this (Font _font) {
        font = _font;
    }
    void appendText (string text) {

        writefln("appending text: '%s'", text);

        quads.reserve(quads.length + text.length * 6);
        uvs.reserve(quads.length + text.length * 6);

        foreach (chr; text) {
            if (chr >= 32 && chr < 128) {
                stbtt_aligned_quad q;
                //writeln("Getting baked quad");
                stbtt_GetBakedQuad(font.chrdata.ptr, 512,512, chr-32, &x,&y,&q,1);
                //writeln("got baked quad");

                //quads ~= [
                //  q.x0, q.y0,
                //  q.x1, q.y0,
                //  q.x0, q.y0,

                //  q.x1, q.y1,
                //  q.x0, q.y1,
                //  q.x0, q.y0
                //];

                quads ~= [
                    q.x1 / 800.0, -q.y0 / 600.0, 0.0,
                    q.x0 / 800.0, -q.y1 / 600.0, 0.0,
                    q.x1 / 800.0, -q.y1 / 600.0, 0.0,

                    q.x0 / 800.0, -q.y1 / 600.0, 0.0,
                    q.x0 / 800.0, -q.y0 / 600.0, 0.0,
                    q.x1 / 800.0, -q.y0 / 600.0, 0.0

                    //q.x1 / 200.0, q.y1 / 150.0, 0.0,
                    //q.x1 / 200.0, q.y0 / 150.0, 0.0,
                    //q.x1 / 200.0, q.y0 / 150.0, 0.0

                    //q.x1 / 400.0, q.y0 / 300.0, 1.0,
                    //q.x0 / 400.0, q.y1 / 300.0, 1.0,
                    //q.x1 / 400.0, q.y1 / 300.0, 1.0,
                ];
                uvs ~= [
                    q.s1, q.t0,
                    q.s0, q.t1,
                    q.s1, q.t1,

                    q.s0, q.t1,
                    q.s0, q.t0,
                    q.s1, q.t0
                ];

                //writefln("quad coords %s: %0.2f, %0.2f, %0.2f, %0.2f", chr, q.x0, q.y0, q.x1, q.y1);
            } 
            else if (chr == '\n') {
                x = x_origin;
                y = (y_baseline += font.baseline);
            }
        }
        data_needs_rebuffering = true;
    }
    void clear () {
        quads.length = 0;
        uvs.length = 0;

        x = x_origin;
        y = y_origin;
        y_baseline = y_origin;
    }
    
    TextFragmentShader fs = null;
    TextVertexShader vs = null;
    Program!(TextVertexShader,TextFragmentShader) program = null;

    uint quadBuffer = 0;
    uint uvBuffer = 0;
    uint vao = 0;

    void render (Camera camera) {
        if (quadBuffer == 0) {
            writeln("Loading textrenderer gl stuff");

            fs = new TextFragmentShader(); fs.compile(); CHECK_CALL("new TextRenderer.FragmentShader()");
            vs = new TextVertexShader(); vs.compile(); CHECK_CALL("new TextRenderer.VertexShader()");
            program = makeProgram(vs, fs); CHECK_CALL("Compiled/linked TextRenderer shaders");

            glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
            glBindTexture(GL_TEXTURE_2D, font.bitmapTexture.id); CHECK_CALL("glBindTexture");
            auto loc = glGetUniformLocation(program.id, "textureSampler"); CHECK_CALL("glGetUniformLocation");
            writefln("texture uniform = %d", loc);
            glUniform1i(loc, 0); CHECK_CALL("glUniform1i");
            //program.tex = 0; CHECK_CALL("program.texture_sampler_uniform = 0");

            glGenVertexArrays(1, &vao); CHECK_CALL("glGenVertexArrays (tr vao)");
            glBindVertexArray(vao); CHECK_CALL("glBindVertexArray (tr vao)");
            glEnableVertexAttribArray(0); CHECK_CALL("glEnableVertexAttribArray (tr vao)");
            glEnableVertexAttribArray(1); CHECK_CALL("glEnableVertexAttribArray (tr vao)");

            glGenBuffers(1, &quadBuffer); CHECK_CALL("glGenBuffer (tr quad buffer)");
            glBindBuffer(GL_ARRAY_BUFFER, quadBuffer); CHECK_CALL("glBindBuffer (tr quad buffer)");
            glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (tr quad buffer)");
            glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer (tr quad buffer)");

            glGenBuffers(1, &uvBuffer); CHECK_CALL("glGenBuffer (tr uv buffer)");
            glBindBuffer(GL_ARRAY_BUFFER, uvBuffer); CHECK_CALL("glBindBuffer (tr uv buffer)");
            glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (tr uv buffer)");
            glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer (tr uv buffer)");

            glBindVertexArray(0); CHECK_CALL("glBindVertexArray (unbinding textrenderer vao)");

            data_needs_rebuffering = false;
        } else if (data_needs_rebuffering) {

            glBindBuffer(GL_ARRAY_BUFFER, quadBuffer); CHECK_CALL("glBindBuffer (rebinding tr quad buffer)");
            glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (rebuffering tr quad buffer)");

            glBindBuffer(GL_ARRAY_BUFFER, uvBuffer); CHECK_CALL("glBindBuffer (rebinding text uvs)");
            glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (rebuffering text uvs)");

            data_needs_rebuffering = false;
        }
        glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
        glBindTexture(GL_TEXTURE_2D, font.bitmapTexture.id); CHECK_CALL("glBindTexture");

        glUseProgram(program.id); CHECK_CALL("glUseProgram");
        glBindVertexArray(vao); CHECK_CALL("glBindVertexArray");
        glDrawArrays(GL_TRIANGLES, 0, cast(int)quads.length / 3); CHECK_CALL("glDrawArrays");
    }
}+/





























































