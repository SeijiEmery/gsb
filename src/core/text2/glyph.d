module gsb.core.text2.glyph;
import gsb.core.text2.font;
import gl3n.linalg;
import stb.truetype;
import core.sync.mutex;
import gl3n.linalg;

struct LGlyph {
    GlyphPtr glyph;
    vec3 pos;
    alias this glyph;
}

alias GlyphId = uint;
struct GlyphInfo {
    GlyphId id;
    int     index;
    dchar   chr;
    float   scale;
    vec2i   dim;
    stbtt_fontinfo* fontptr;
}
alias GlyphPtr = const(GlyphInfo)*;

private GlyphInfo makeGlyph ( stbtt_fontinfo* font, dchar chr, GlyphId id, float scale ) {
    int advance, lsb, x0,y0,x1,y1;

    int index = stbtt_FindGlyphIndex( font, chr );
    stbtt_GetGlyphBitmapBox(font, index, scale,scale, &x0,&y0,&x1,&y1);
    stbtt_GetGlyphHMetrics(font, index, &advance, &lsb);

    return GlyphInfo(
        id, index, chr, scale, vec2i(x1-x0, y1-y0), font
    );
}   
void renderBitmap ( GlyphPtr glyph, ubyte[] bitmapPixels, size_t bitmapWidth, vec2i pos ) {
    auto offset = pos.x + pos.y * bitmapWidth;
    stbtt_MakeGlyphBitmap( 
        glyph.fontptr, 
        bitmapPixels.ptr + offset, 
        glyph.dim.x, glyph.dim.y, cast(int)bitmapWidth,
        glyph.scale, glyph.scale, 
        glyph.index
    );
}


class GlyphIdMgr {
    Mutex m_mutex;
    GlyphId m_nextId = 1;

    this () { m_mutex = new Mutex(); }

    auto allocNewId () {
        synchronized (mutex) {
            return m_nextId++;
        }
    }
}
class GlyphChunkChain {
    GlyphChunk[] m_chunks;

    class GlyphChunk {
        private immutable size_t CHUNK_SIZE = 128;
        GlyphInfo[ CHUNK_SIZE ] m_glyphs;
        uint m_next = 0;

        GlyphInfo* insert (GlyphInfo info) {
            if (m_next < CHUNK_SIZE)
                return &(m_glyphs[m_next++] = info);
            return null;
        }
    }

    this () { m_chunks ~= new GlyphChunk(); }
    GlyphInfo* insert (GlyphInfo info) {
        auto ptr = m_chunks[$-1].insert(info);
        while (!ptr) {
            m_chunks ~= new GlyphChunk();
            ptr = m_chunks[$-1].insert(info);
        }
        return ptr;
    }
    void clear () {
        foreach (ref chunk; m_chunks)
            chunk.m_next = 0;
        m_chunks.length = 1;
    }
}

class GlyphSet {
    GlyphIdMgr m_gidMgr;
    SbFont m_font;
    float  m_scale;

    private immutable size_t MIN_GLYPH = 32, MAX_GLYPH = 120;
    GlyphInfo[MAX_GLYPH - MIN_GLYPH] m_lowGlyphs;
    GlyphChunkChain                  m_highGlyphs;
    GlyphInfo*[dchar]                m_highGlyphLookup;

    this (GlyphIdMgr gidMgr, GlyphChunkChain sharedGlyphs, SbFont font, float scale) {
        m_gidMgr = gidMgr;
        m_highGlyphs = sharedGlyphs;
        m_font = font;
        m_scale = scale;
    }
    const(GlyphInfo)* opIndex (dchar chr) {
        if (chr < MIN_GLYPH)
            return g_nullGlyph;
        if (chr < MAX_GLYPH) {
            return m_lowGlyphs[chr - MIN_GLYPH].id ?
                &(m_lowGlyphs[chr - MIN_GLYPH]) :
                &(m_lowGlyphs[chr - MIN_GLYPH] = makeGlyph(chr));
        }
        return chr in m_highGlyphLookup ?
            m_highGlyphLookup[chr] :
            m_highGlyphLookup[chr] = m_highGlyphs.insert(makeGlyph(chr));
    }
    private GlyphInfo makeGlyph (dchar chr) {
        return GlyphInfo(
            id  = m_gidMgr.allocNewId(),
            chr = chr,
            fontptr = m_font.fontInfoPtr,
        );
    }
}





