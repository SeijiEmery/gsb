
module gsb.text.font;

import gsb.core.log;
import gsb.core.singleton;
import gsb.core.errors;
import gsb.core.pseudosignals;
import stb.truetype;
import core.sync.mutex;
import gl3n.linalg;

import std.file;
import std.format;
import std.algorithm.iteration: map;
import std.array;
import std.math;
import std.utf;
import std.regex;

public void registerDefaultFonts () {
    version(OSX) {
        FontRegistry.registerFont("menlo", "/System/Library/Fonts/Menlo.ttc", 0);
        FontRegistry.registerFont("arial", "/Library/Fonts/Arial Unicode.ttf", 0);

        FontRegistry.registerFont("menlo-italic", "/System/Library/Fonts/Menlo.ttc", 1);
        FontRegistry.registerFont("menlo-bold", "/System/Library/Fonts/Menlo.ttc", 2);
        FontRegistry.registerFont("menlo-bold-italic", "/System/Library/Fonts/Menlo.ttc", 3);

        FontRegistry.registerFont("georgia", "/Library/Fonts/Georgia.ttf");
        FontRegistry.registerFont("georgia-bold", "/Library/Fonts/Georgia Bold.ttf");
        FontRegistry.registerFont("georgia-italic", "/Library/Fonts/Georgia Italic.ttf");
        FontRegistry.registerFont("georgia-bold-italic", "/Library/Fonts/Georgia Bold Italic.ttf");

        FontLoader.instance.onFontFileLoaded.connect((string filename) {
            log.write("Loaded font file '%s'", filename);
        });
        FontLoader.instance.onFontLoaded.connect((string filename, FontData fontData) {
            log.write("Loaded font '%s', %d (filesize = %d)", 
                filename, fontData.fontIndex, fontData.contents.length);
        });
    }
}

class Font {
    string   _name;
    float    _size;
    FontData _data;
    vec2i    oversampling;

    this (string name, float fontSize = 0, vec2i oversampling = vec2i(2, 2)) {
        this._name = name;
        this._size = fontSize;
        this._data = FontCache.getFontData(name);
        this.oversampling = oversampling;
    }

    @property auto stringId () {
        return format("%s:%d|%d,%d", _name, to!int(_size), oversampling.x, oversampling.y);
    }
    static auto fromStringId (string fontid) {
        static auto ctr = ctRegex!"(\\w+):(-?\\d+)(?:|(-?\\d+),(-?\\d+))?";
        auto c = matchFirst(fontid, ctr);
        if (!c.empty && c.length == 4)
            return new Font(c[1], to!float(c[2]), vec2i(to!int(c[3]), to!int(c[4])));
        if (!c.empty && c.length == 2)
            return new Font(c[1], to!float(c[2]));
        throw new Exception(format("Invalid font string: '%s'", fontid));
    }

    unittest {
        assert(new Font("arial", 30, vec2i(4, 4)).stringId == "arial:30|4,4");
        assert(Font.fromStringId("arial:30|4,4").stringId == "arial:30|4,4");
        assert(Font.fromStringId("arial:30").stringId == new Font("arial", 30).stringId);
    }


    @property float size () { return _size; }
    @property void size (float size) {
        _size = size;
        _stbFontScale = _stbFontSize = float.nan;
        _stbAscent = 0;
    }
    @property auto data () { return _data; }
    @property auto name () { return _name; }
    @property auto lineHeight () {
        return _data.lineHeight * getScale(1.0);
    }
    @property auto lineOffsetY () {
        return _data.lineOffsetY * getScale(1.0);
    }


    @property int pixelSize () { return cast(int)_size; }
    bool contains (dchar chr) {
        return true;
    }

    vec2 calcPixelBounds (string text) {
        float lineWidth = 0, maxWidth = 0;
        uint  nlines = 1;

        foreach (chr; text.byDchar) {
            if (chr == '\n') { maxWidth = max(maxWidth, lineWidth); lineWidth = 0; nlines++; }
            else { lineWidth += _data.getAdvanceWidth(chr); }
        }
        return vec2(max(lineWidth, maxWidth), _data.lineHeight * nlines) * getScale(1.0);
    }
    float calcUnscaledPixelWidth (string text) {
        float lineWidth = 0, maxWidth = 0;
        foreach (chr; text.byDchar) {
            if (chr == '\n') { maxWidth = max(maxWidth, lineWidth); lineWidth = 0; }
            else { lineWidth += _data.getAdvanceWidth(chr); }
        }
        return max(maxWidth, lineWidth);
    }


    // temp stuff for integrating w/ old textrenderer
    private float _stbFontScale;
    private float _stbFontSize;
    private int _stbAscent, _stbDescent, _stbLineGap;

    float getScale (float screenScale) {
        if (isNaN(_stbFontScale))
            _stbFontScale = stbtt_ScaleForPixelHeight(&data.fontInfo, _size);
        return _stbFontScale * screenScale;
    }
    float getSize (float screenScale) {
        return size * screenScale;
    }
    float getLineHeight (float screenScale) {
        if (!_stbAscent)
            stbtt_GetFontVMetrics(&data.fontInfo, &_stbAscent, &_stbDescent, &_stbLineGap);
        return (_stbAscent - _stbDescent + _stbLineGap) * screenScale;
    }
}

struct FontCache {
    private static FontData[string] cache; // threadlocal

    static FontData getFontData (string fontName) {
        if (fontName in cache) return cache[fontName];

        auto font = FontRegistry.getFontPath(fontName);
        return cache[fontName] = FontLoader.getFontData(font.path, font.index);
    }
    static FontData[] getFontFamily (string name) {
        return FontRegistry.getFontFamily(name).map!getFontData().array();
    }
}

class FontData {
    stbtt_fontinfo fontInfo;
    ubyte[]        contents;
    string         fontPath;
    int            fontIndex;

    protected this () {}

    private float cachedLineHeight, cachedLineOffsetY;

    private void recalcVMetrics () {
        int ascent, descent, linegap;
        stbtt_GetFontVMetrics(&fontInfo, &ascent, &descent, &linegap);
        cachedLineHeight = ascent - descent + linegap;
        cachedLineOffsetY = descent;
    }

    @property float lineHeight () {
        if (isNaN(cachedLineHeight))
            recalcVMetrics();
        return cachedLineHeight;
    }
    @property float lineOffsetY () {
        if (isNaN(cachedLineOffsetY))
            recalcVMetrics();
        return cachedLineOffsetY;
    }

    private float[dchar] cachedAdvMetrics;
    float getAdvanceWidth (dchar chr) {
        if (chr !in cachedAdvMetrics) {
            int adv, discard;
            stbtt_GetCodepointHMetrics(&fontInfo, chr, &adv, &discard);
            return cachedAdvMetrics[chr] = adv;
        }
        return cachedAdvMetrics[chr];
    }
}

struct FontLoader {
    static __gshared FontLoader.Instance instance;
    //private static __gshared auto mutex = new Mutex();

    static struct Instance {
        alias FileData = ubyte[];

        private FileData[string] loadedFiles;
        private FontData[string] loadedFonts;

        Signal!(string)          onFontFileLoaded;
        Signal!(string,FontData) onFontLoaded;

        FontData getFontData (string fontPath, int fontIndex) {
            auto index = format("%s,%d", fontPath, fontIndex);
            if (index in loadedFonts) {
                return loadedFonts[index];
            }
            if (fontPath !in loadedFiles) {
                if (!exists(fontPath) || !attrIsFile(getAttributes(fontPath)))
                    throw new ResourceError("Invalid font file: '%s' does not exist", fontPath);
                auto contents = cast(ubyte[])read(fontPath);
                if (contents.length == 0)
                    throw new ResourceError("Invalid font file: '%s' file length is zero", fontPath);
                loadedFiles[fontPath] = contents;
                onFontFileLoaded.emit(fontPath);
            }
            auto font = new FontData();
            font.contents = loadedFiles[fontPath];
            font.fontPath = fontPath;
            font.fontIndex = fontIndex;
            auto offset = stbtt_GetFontOffsetForIndex(font.contents.ptr, fontIndex);
            if (offset == -1)
                throw new ResourceError("Invalid font file (could not get offset for index %d in '%s')", fontIndex, fontPath);
            if (!stbtt_InitFont(&font.fontInfo, font.contents.ptr, offset))
                throw new ResourceError("Invalid font file (stbtt failed to init font data: '%s', index %d)", fontPath, fontIndex);
            loadedFonts[index] = font;
            onFontLoaded.emit(fontPath, font);
            return font;
        }
    }
    static auto getFontData (string fontPath, int fontIndex) {
        synchronized /*(mutex)*/ { return instance.getFontData(fontPath, fontIndex); }
    }
}

struct FontRegistry {
    private static __gshared FontRegistry.Instance instance;
    //private static __gshared auto mutex = new Mutex();

    static struct Instance {
        private struct FontId {
            string path;
            int index;
        }

        private FontId[string]   fontPaths;
        private string[][string] fontFamilies;

        public void registerFont (string fontName, string fontPath, int fontIndex = 0) {
            if (fontName in fontPaths && (fontPaths[fontName].path != fontPath || fontPaths[fontName].index != fontIndex))
                throw new ResourceError("FontRegistry: overriding font lookup for '%s': '%s,%d' with '%s,%d'", 
                    fontName, fontPaths[fontName].path, fontPaths[fontName].index, fontPath, fontIndex);
            fontPaths[fontName] = FontId(fontPath, fontIndex);
        }
        public void registerFontFamily (string fontFamilyName, string[] listOfFontNames) {
            fontFamilies[fontFamilyName] = listOfFontNames;
        }
        public auto getFontPath (string name) { 
            if (name !in fontPaths)
                throw new ResourceError("No registered font '%s'", name);
            return fontPaths[name];
        }
        public auto getFontFamily (string name) {
            if (name !in fontFamilies)
                throw new ResourceError("No registered font family '%s'", name);
            return fontFamilies[name];
        }
    }

    // Global versions
    static void registerFont (string fontName, string fontPath, int fontIndex = 0) {
        synchronized /*(mutex)*/ { instance.registerFont(fontName, fontPath, fontIndex); }
    }
    static void registerFontFamily (string fontFamilyName, string[] listOfFontNames) {
        synchronized /*(mutex)*/ { instance.registerFontFamily(fontFamilyName, listOfFontNames); }
    }
    static auto getFontPath (string fontName) {
        synchronized /*(mutex)*/ { return instance.getFontPath(fontName); }
    }
    static auto getFontFamily (string fontFamilyName) {
        synchronized /*(mutex)*/ { return instance.getFontFamily(fontFamilyName); }
    }
}

