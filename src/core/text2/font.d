module gsb.core.text2.font;
import gsb.core.text2.font_registry;

struct FontData {
    stbtt_fontinfo fontInfo;
    // attribs...
    uint id;
}
class FontFamily {
    string m_name;
    uint[] m_fonts;
}

class SbFont {
    FontFamily m_font;
    GlyphSet   m_glyphs;
}


struct FontInfo {
    string path;
    int    index = 0;
    
    @property auto strid () { return format("%s:%d", path, index); }
}

class FontRegistry {
    FontInfo[string] fontPaths;
    string[][string] fonts;
}

interface IFontManager {
    FontFamily getFont (string);
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
