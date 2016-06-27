module gsb.core.text2.glyphset;
import gsb.core.text2.font;
import gsb.core.text2.glyphtexture;
import gl3n.linalg;
import stb.truetype;
import core.sync.mutex;
import gl3n.linalg;


class GlyphSet {
    private immutable size_t MIN_GLYPH = 20, MAX_GLYPH = 120;
    GlyphCache   m_glyphCache;
    FontInstance m_font;

    GlyphTextureInstance              m_glyphTexture;
    GlyphInfo*[]                      m_newGlyphs;
    float                             m_minArea = 0;

    GlyphInfo*[dchar]                 m_highGlyphLookup;
    GlyphInfo*[MAX_GLYPH - MIN_GLYPH] m_lowGlyphLookup;

    
    this (GlyphCache cache, GlyphTextureInstance texture, FontInstance font) {
        m_glyphCache = cache;
        m_glyphTexture = texture;
        m_font = font;
    }
    const(GlyphInfo)* getGlyph (dchar chr) {
        if (chr < MIN_GLYPH)
            return g_nullGlyph;

        if (chr < MAX_GLYPH) {
            if (m_lowGlyphLookup[chr] is null) {
                auto glyph = m_glyphCache.insert(m_font.getGlyph(chr));
                m_minArea += glyph.dim.x * glyph.dim.y;
                m_newGlyphs ~= glyph;
                m_lowGlyphLookup[chr] = glyph;
                return glyph;
            }
            return m_lowGlyphLookup[chr];
        } else {
            if (chr !in m_highGlyphLookup) {
                auto glyph = m_glyphCache.insert(m_font.getGlyph(chr));
                m_minArea += glyph.dim.x * glyph.dim.y;
                m_newGlyphs ~= glyph;
                m_highGlyphLookup[chr] = glyph;
                return glyph;
            }
            return m_highGlyphLookup[chr];
        }
    }
    private void reset () {
        m_minArea = 0;
        m_newGlyphs.length = 0;
        m_lowGlyphLookup[0..$] = null;
        foreach (k; m_highGlyphLookup)
            m_highGlyphLookup.remove(k);
    }
    private void update () {
        m_glyphTexture.insert(m_newGlyphs, m_minArea);
        m_newGlyphs.length = 0;
    }
    private void repack () {
        m_glyphTexture.clear();
        m_glyphTexture.insert( 
            m_lowGlyphLookup[0..$].filter!"a".chain(m_highGlyphLookup.values).array,
            m_minArea
        );
    }
}

class GlyphCache {
    BlockChain!(GlyphInfo,512) m_glyphs;
    GlyphSet[]                 m_glyphSets;
    GlyphTextureInstance       m_sharedTextureInstance = new GlyphTextureInstance();
    Mutex m_mutex;

    this () {
        m_mutex = new Mutex();
        m_glyphs = new typeof(m_glyphs)();
    }
    private auto mutex () { return m_mutex; }

    GlyphSet makeGlyphSet (FontInstance font) {
        auto gs = new GlyphSet(this, m_sharedTextureInstance, font);
        m_glyphSets ~= gs;
        return gs; 
    }
    void resetCache () {
        synchronized (m_mutex) {
            foreach (gs; m_glyphSets)
                gs.reset();
            m_glyphs.reset();
        }
    }
    private GlyphInfo* insert (GlyphInfo info) {
        if (!m_glyphs.canInsert)
            m_glyphs = m_glyphs.pushBlock;
        return m_glyphs.insert(info);
    }
}

private class BlockChain (T, size_t CHUNK_SIZE) {
    T[CHUNK_SIZE] m_block;
    size_t        m_nextSlot = 0;
    BlockChain!(T,CHUNK_SIZE) m_prev = null;

    this () {}
    this (BlockChain prev) { m_prev = prev; }

    bool canInsert () { return m_nextSlot < CHUNK_SIZE; }
    auto pushBlock () { return new BlockChain!(T,CHUNK_SIZE)(this); }
    T* insert (T v) {
        assert(m_nextPos < SIZE);
        return &(m_block[m_nextPos++] = v);
    }
}


