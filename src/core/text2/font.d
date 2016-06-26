module gsb.core.text2.font;
import gsb.core.text2.font_registry;

interface IFontManager {
    FontFamily getFont (string);
}

struct GlyphInfo {
    stbtt_fontinfo* font;
    int             index;
    float scale;
    float ascent, descent, linegap, advance, lsb; // scaled values
    private vec2i size0; // unscaled glyph size
    public  vec2  dim;   // scaled glyph size

    void renderBitmap (vec2i pos, ref uint[] bitmap, vec2i bitmapSize) {
        auto offset = pos.x + pos.y * bitmapSize.y;
        assert(offset + glyphSize.x + glyphSize.y * bitmapSize.y < bitmap.length,
            format("glyph dimensions exceed bitmap size! (bitmap %s, glyph pos %s, size %s",
                bitmapSize, glyphSize, pos));

        stbtt_MakeGlyphBitmap(
            bitmap.ptr + offset,  // bitmap ptr
            size0.x, size0.y,     // unscaled glyph dimensions
            bitmapSize.x,         // stride
            scale, scale,         // scale factor
            index                 // glyph index
        );
    }
}

class FontData {
    FontPath        m_path;
    stbtt_fontinfo  m_fontData;
    FontData        m_fallback = null;
    bool            m_loaded = false;
    float m_ascent, m_descent, m_linegap;

    this (FontPath path) {
        m_path = path;
    }
    private @property auto fallback (FontData v) {
        return m_fallback = v;
    }
    void doLoad (string[] fileContents) {
        if (m_loaded)
            return; // disable hotloading for now

        stbtt_InitFont(&m_fontData, fileContents.ptr, 
            stbtt_GetFontOffsetForIndex(fileContents.ptr, m_path.index));

        int ascent, descent, linegap;
        stbtt_GetFontVMetrics(&m_fontData, &ascent, &descent, &lineGap);
        m_ascent  = cast!typeof(m_ascent)(ascent);
        m_descent = cast!typeof(m_descent)(descent);
        m_linegap = cast!typeof(m_linegap)(lineGap);

        m_loaded = true;
    }
    private void assertLoaded () {
        assert(m_loaded, format("Non-loaded font %s!", m_path));
    }
    GlyphInfo getGlyph (dchar chr, float scale) {
        assertLoaded();
        auto index = stbtt_FindGlyphIndex(&m_fontData, chr);
        if (index < 0)
            return m_fallback ?
                m_fallback.getGlyph(chr) :
                GlyphInfo(null, index);

        int advanceWidth, lsb, kern1, kern2, x0, y0, x1, y1;
        stbtt_GetGlyphHMetrics(&m_fontData, index, &advanceWidth, &lsb);
        stbtt_GetGlyphKernAdvance(&m_fontData, &kern1, &kern2);
        stbtt_GetGlyphBox(&m_fontData, &x0, &y0, &x1, &y1);

        return GlyphInfo( 
            &m_fontData, index, 
            scale,
            m_ascent * scale, m_descent * scale, m_linegap * scale,
            advanceWidth * scale, lsb * scale,
            vec2i(x1-x0, y1-y0),
            vec2((x1-x0) * scale, (y1-y0) * scale)
        );
    }
}

class FontInstance {
    FontData m_fontData;
    float    m_fontScale, m_pixelSize;

    this (FontData font, float pixelSize) {
        m_pixelSize = pixelsize;
        m_fontScale = stbtt_ScaleForPixelHeight(m_fontData.ptr, pixelSize);
    }
    auto getGlyph (dchar chr) { return m_fontData.getGlyph(chr); }
}

struct FontPath {
    string path;
    int    index = 0;
    
    @property auto strid () { return format("%s:%d", path, index); }
}

class FontRegistry : IFontRegistry {
    FontPath[FT_COUNT][string] m_fontPaths;
    string[string]        m_fontFallbacks;
    Tuple!(string,string) m_fontAliases;

    void registerFont (string name, FontTypeface typeface, string path, int index = 0) {
        m_fontPaths[typeface][name] = FontPath(path, index);
    }
    void fontAlias (string name, string existing) {
        m_fontAliases ~= tuple(name, existing);
    }
    void fontFallback (string name, string fallback) {
        m_fontFallbacks[name] = fallback;
    }

    //void registerFonts (FontMgr fm) {
    //    import gsb.core.log;

    //    auto i = f.beginFontLoad();
    //    uint[string] fonts;
    //    foreach (k, v; m_fontPaths[FT_DEFAULT]) {
    //        fonts[k] = fm.addUniqueFont(v);
    //    }
    //    foreach (p; m_fontFallbacks) {
    //        if (p[0] in fonts && p[1] in fonts)
    //            fm.setFallback(fonts[p[0]], fonts[p[1]]);
    //        else
    //            log.write("Invalid font fallback: '%s' => '%s'", p[0], p[1]);
    //    }

    //    f.endLoad(i);
    //}
}

private class FontMgr : IFontManager {
    //
    // Internals
    //
    GlyphSetMgr        m_glyphs;
    FontData[]         m_fontData;
    FontFamily[string] m_fonts;
    ubyte[][string]    m_fontFileContents;
    uint[string]       m_fontDataLookup;
    Mutex m_mutex;
    uint m_nextUniqueFontId = 0;

    this () { m_mutex = new Mutex(); }
    void lock   () { m_mutex.lock(); }
    void unlock () { m_mutex.unlock(); }

    private uint addUniqueFont (FontInfo info) {
        auto id = cast(uint)m_fontData.length;
        m_fontData ~= FontData(info, id);
        return m_fontDataLookup[info.strid] = id;
    }
    private void loadFonts (uint from) {
        auto toLoad = m_fontData[ from .. $ ];
        auto files  = toLoad.map!"a.path".filter!((path) =>
            path in m_fontFileContents ? 
                false : (m_fontFileContents[path] = null, true));

        files.parallel_foreach!((string path) {
            m_fontFileContents[path] = read(path);
        });
        foreach (ref font; toLoad) {
            assert(font.path in m_fontFileContents && m_fontFileContents[font.path] !is null);
            font.load(m_fontFileContents[font.path]);
        }
    }
    private FontFamily addUniqueFontFamily (string id, string[] fonts) {
        return id in m_fonts ?
            m_fonts[id] :
            m_fonts[id] = new FontFamily( id, m_nextUniqueFontId++, fonts.map!(
                (font) => m_fontData[m_fontDataLookup[font]].id
            ).array);
    }

    //
    // Public-ish API
    //

    // Load all fonts from a given font registry
    void loadFonts (FontRegistry registry) {
        m_mutex.lock();
        auto start = cast(uint)m_fontData.length;
        foreach (k,v; registry.fonts) {
            if (k !in m_fonts) {
                foreach (font; v) {
                    if (font !in m_fontDataLookup)
                        addUniqueFont(registry.fontInfo[font]);
                }
                addUniqueFontFamily(k, v);
            }
        }
        loadFonts(start);
        m_mutex.unlock();
    }

    // Font resolution
    FontFamily getFont (string name) {
        enforce( name in m_fonts, format("Unknown font '%s'", name));
        return m_fonts[name];
    }
}
