

class TRFont {
    stbtt_fontinfo* ptr;
    TRFont          next;


    static struct GlyphInfo { TRFont font; int index; }
    auto getGlyphInfo (dchar chr) {
        auto index = stbtt_GetGlyphIndex(ptr, chr);
        return index >= 0 ?
            GlyphInfo(this, index) :
            next ?
                next.getGlyphInfo(chr) :
                GlyphInfo(null, index);
    }
}



class TRGlyph {
    stbtt_fontinfo* font;
    float           adv;
    vec2            pixelDim;
    vec2            normalized_uv0;

    this (TRFont font, int glyphIndex, float scale) {
        // ...
    }
}
private class TRGlyphSet {
    TRFont m_font; float m_scale;

    immutable auto MIN_GLYPH = 20, MAX_GLYPH = 120;
    TRGlyph[MAX_GLYPH - MIN_GLYPH] m_low;
    TRGlyph[dchar]                 m_high;
    TRGlyph[]                      newGlyphs;

    this (TRFont font, float scale) {
        m_font  = font;
        m_scale = scale;
    }

    alias GlyphInfo = typeof(m_font.getGlyphInfo(' '));

    private auto makeGlyph (GlyphInfo g) {
        if (!g.font)
            return null;

        auto glyph = new TRGlyph(g.font, g.index, m_scale);
        newGlyphs ~= glyph;
        return glyph;
    }

    TRGlyph getGlyph (dchar chr) {
        if (chr < MIN_GLYPH)
            return null;
        if (chr < MAX_GLYPH) {
            return m_low[chr] ?
                m_low[chr] :
                m_low[chr] = makeGlyph(m_font.getGlyphInfo(chr));
        }
        return chr in m_high ?
            m_high[chr] :
            m_high[chr] = makeGlyph(m_font.getGlyphInfo(chr));
    }
}

class TRFontCache {
    TRFont[string]           m_fonts;
    TRGlyphSet[string][uint] m_glyphsets;

    auto getFont (string name) {
        enforce!FontLookupException(name in m_fonts, 
            format("font %s does not exist!", name));
        return m_fonts[name];
    }
    auto getGlyphSet (string name, uint size) {
        auto id = format("%s:%s", name, size);
        return id in m_glyphsets ?
            m_glyphsets[id] :
            m_glyphsets[id] = makeGlyphSet(name,size);
    }
    private auto makeGlyphSet (string name, uint size) {
        auto font = getFont(name);
        auto scale = stbtt_ScaleForPixelHeight(size);
        return new TRGlyphSet(font, scale);
    }
}

struct LGlyph {
    TRGlyph glyph;
    vec3    pos;
}

class TRLayouter {
    TRGlyphSet glyphset;
    vec4       color;
    vec3       cursor;
    LGlyph[]   outputGlyphs;

    struct TextLine {
        vec2 start, end; // AABB: topLeft, btmRight
        LGlyph[] glyphs;
    }
    TextLine[] lines;
    uint       startGlyph = 0;
    bool       isLineVisible = true;

    TRGlyphSet[] usedSets; // set of glyphsets we've used this frame

final:
    void setGlyphset (TRGlyphSet glyphset) {
        if (glyphset != this.glyphset) {
            if (this.glyphset) cursor.y -= this.glyphset.baselineOffset;
            if (glyphset)      cursor.y += glyphset.baselineOffset;
            this.glyphset = glyphset;

            // insert into usedSets (O(n) b/c has less overhead than other approaches)
            foreach (gs; usedSets)
                if (gs == glyphset)
                    return;
            usedSets ~= glyphset;
        }
    }
    void setColor (vec4 color) {
        this.color = color;
    }
    void setOrigin (vec3 origin) {
        this.origin = origin;
        this.cursor = origin;
        if (glyphset)
            this.cursor.y += glyphset.baselineOffset;


    }
    private void updateLineVisibility () {
        isLineVisible = origin.x <= screenBounds.end.x &&
            origin.y >= screenBounds.start.y &&
            cursor.y <= screenBounds.end.y; 
    }
    private void endTextLine () {
        if (startGlyph != outputGlyphs.length) {
            lines ~= TextLine(origin, cursor, outputGlyphs[startGlyph..$]);
            startGlyph = outputGlyphs.length;
        }   
    }
    void wrapLine (bool cr = true) {
        endTextLine();
        if (glyphset) {
            this.origin.y += glyphset.heightToNextLine;
            this.cursor.y += glyphset.heightToNextLine;
        }
        if (cr) this.cursor.x = this.origin.x;
    }
    void setViewRect (vec2 start, vec2 end) { // AABB
        screenBounds.start = start;
        screenBounds.end   = end;
    }
    bool visible (vec2 tl, vec2 br) { // AABB
        return isLineVisible && 
            intersects(screenBounds.start, screenBounds.end, tl, br);
    }
    void renderText (string text) {
        foreach (chr; text.byDchar) {
            auto glyph = glyphset.getGlyph(chr);
            if (glyph && visible(cursor.xy, cursor.xy + glyph.pixelSize)) {
                outputGlyphs ~= LGlyph(glyph, cursor);
                cursor.x += glyph.adv; 
            }
        }
    }
    //void submitFrame () {
    //    endTextLine();
    //    foreach (glyphset; usedGlyphs) {
    //        // pack + rasterize glyphs to texture(s)
    //    }
    //    foreach (glyph; outputGlyphs) {

    //    }
    //}
}

class TRImpl {
    TRLayouter[] instances;
    TRGlyphSet[] glyphsets;

    void prepareFrame () {
        // Accumulate + iter over union of all instance glyphsets
        glyphsets.length = 0;
        foreach (instance; instances) {
            instance.wrapLine();

            glyphsets ~= instance.usedSets;
            instance.usedSets.length = 0;
        }
        TRGlyphSet prev = null;
        foreach (gs; glyphsets) {
            if (prev != gs && gs.newGlyphs.length) {
                // pack + render new glyphs


            }
            prev = gs;
        }

        // Generate geometry + push to buffers
        foreach (instance; instances) {

        }

        // Execute draw call(s)
    }
}






































