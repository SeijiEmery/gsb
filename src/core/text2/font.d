module gsb.core.text2.font;
import gsb.core.text2.font_registry;
import stb.truetype;
import gl3n.linalg;
import core.sync.mutex;
import std.typecons: Tuple, tuple;
import gsb.core.log;

interface IFontManager {
    FontInstance getFont (string, float);
}

struct GlyphInfo {
    stbtt_fontinfo* font;
    int             index;
    float scale;
    float ascent, descent, linegap, advance, lsb; // scaled values
    private vec2i size0; // unscaled glyph size
    public  vec2  dim;   // scaled glyph size

    void renderBitmap (vec2i pos, ref uint[] bitmap, vec2i bitmapSize) {
        auto offset = pos.x + pos.y * bitmapSize.x;
        assert(offset + glyphSize.x + glyphSize.y * bitmapSize.x < bitmap.length,
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
            return; // no hotloading

        stbtt_InitFont(&m_fontData, fileContents.ptr, 
            stbtt_GetFontOffsetForIndex(fileContents.ptr, m_path.index));

        int ascent, descent, linegap;
        stbtt_GetFontVMetrics(&m_fontData, &ascent, &descent, &lineGap);
        m_ascent  = cast(typeof(m_ascent))ascent;
        m_descent = cast(typeof(m_descent))descent;
        m_linegap = cast(typeof(m_linegap))lineGap;

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
    auto @property path () { return m_path.path; }
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
    FontPath[FT_COUNT][string] fontPaths;
    string[string]        fontFallbacks;
    Tuple!(string,string) fontAliases;

    void registerFont (string name, FontTypeface typeface, string path, int index = 0) {
        fontPaths[typeface][name] = FontPath(path, index);
    }
    void fontAlias (string name, string existing) {
        fontAliases ~= tuple(name, existing);
    }
    void fontFallback (string name, string fallback) {
        fontFallbacks[name] = fallback;
    }
}

class FontManager : IFontManager {
    class FontEntry {
        FontData       font;
        FontInstance[] instances;

        this (FontData font) { this.font = font; }
    }
    ubyte[][string]   m_loadedFiles;
    FontEntry[string] m_fonts;
    Mutex m_mutex;
    uint m_nextUniqueFontId = 0;

    this () { m_mutex = new Mutex(); }

    FontInstance getFont (string name, float size) {
        if (name !in m_fonts) {
            log.write("Unknown font: '%s'! (returning 'default')", name);
            assert("default" in m_fonts);
            return getFont("default", size);
        }
        synchronized (m_mutex) {
            auto entry = m_fonts[name];
            size = round(size + 0.5);

            foreach (instance; entry.instances) {
                if (instance.size == size)
                    return instance;
            }
            auto instance = new FontInstance(entry.font, size);
            entry.instances ~= instance;
            entry.instances.sort!"a.size < b.size";
            return instance;
        }
    }

    void loadFonts (FontRegistry r) {
        synchronized (m_mutex) {
            FontEntry[] newFonts;
            string[]    newFiles;

            // create font entries for new fonts
            foreach (k,v; r.fontPaths[FT_DEFAULT]) {
                if (k !in m_fonts) {
                    auto font = new FontEntry(new FontData(v));
                    newFonts ~= font;
                    m_fonts[k] = font;

                    if (v.path !in m_loadedFiles) {
                        newFiles ~= v.path;
                        m_loadedFiles[v.path] = null;
                    }
                }
            }
            // Setup font fallbacks + aliases
            foreach (fa; r.fontAliases) {
                if (fa[0] !in m_fonts) {
                    if (fa[1] !in m_fonts)
                        log.write("Cannot alias font '%s' to '%s' (does not exist)", fa[0], fa[1]);
                    else
                        m_fonts[fa[0]] = m_fonts[fa[1]];
                }
            }
            foreach (k,v; r.fontFallbacks) {
                if (k !in m_fonts)
                    log.write("Invalid font fallback '%s' => '%s' (font does not exist)", k, v);
                else if (v !in m_fonts)
                    log.write("Invalid font fallback '%s' => '%s' (fallback does not exist)", k, v);
                else
                    m_fonts[k].font.fallback = m_fonts[v].font;
            }
            // Load font file(s) + font data
            foreach (file; newFiles) {
                m_loadedFiles[file] = read(file);
            }
            foreach (f; newFonts) {
                auto font = m_fonts[f].font;
                assert(font.path in m_loadedFiles, format("Font file not loaded! (%s,%s)", f, font.path));
                font.doLoad(m_loadedFiles[font.path]);
            }
        }
        enforce("default" in m_fonts, format("No default font specified! (has %s)", m_fonts.keys));
    }
}
