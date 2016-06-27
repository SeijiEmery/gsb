module gsb.core.text2.tr2;
import gsb.core.text2.rtp: RichTextParser;
import gsb.core.text2.font;
import gsb.core.text2.glyphset;
import gsb.utils.color; 
import gsb.core.log;
import std.conv;
import std.math;
import std.format;
import gl3n.linalg;


class TRContext {}

class TextRenderer {
    RichTextParser m_rtp;
    FontManager    m_fontMgr;
    mixin TRState;
    TRContext      m_lastContext;

    GlyphSetMgr    m_glyphCollection;
    GlyphSet       m_glyphs = null;
    float          m_fontScale;
    TextLayout     m_layout;

    // called at end of frame
    void renderSubmit (GlBatch batch) {
        foreach (i, bitmap; m_bitmaps) {
            if (bitmap.active) {
                m_textures[i].setPixels( bitmap, bitmap.size );
            }
        }
        m_tempGbuf.clear();
        m_renderedGlyphs.sort!"a.texId";

        uint prevTex = uint.max;

        batch.activeShader( m_textShader );
        batch.activeTexture( 1, m_colorPalette.texture );

        foreach ( glyph; m_renderedGlyphs ) {
            if (glyph.texId != prevTex) {

                batch.loadGeometry ( 0, m_tempGbuf );
                batch.drawArrays( GL_TRIANGLES, m_tempGbuf.length );
                m_tempGbuf.clear();

                prevTex = glyph.texId;
                batch.activeTexture( 0, m_textures[glyph.texId] );
            }

            pushQuad( m_tempGbuf, 
                glyph.pos, glyph.bounds, 
                glyph.uv0, glyph.uvBounds,
                glyph.colorIndex 
            );
        }
        if (m_tempGbuf.length) {
            batch.loadGeometry ( 0, m_tempGbuf );
            batch.drawArrays( GL_TRIANGLES, m_tempGbuf.length );
        }
    }

    void renderRichString (string text, TRContext ctx) {
        auto s = saveState();
        m_lastContext = ctx;
        foreach (result; m_rtp.parse(text)) {
            final switch (result.cmd) {
                case RTCmd.TEXT: renderPlainString(result.content, ctx); break;
                case RTCmd.NEWLINE: {
                    // wrap line back on next line
                } break;
                
                // Will implement bold/italic later
                case RTCmd.SET_ITALIC: break;
                case RTCmd.END_ITALIC: break;

                case RTCmd.SET_BOLD: break;
                case RTCmd.END_BOLD: break;
                
                case RTCmd.SET_FONT:  pushFont (result.content); break;
                case RTCmd.SET_COLOR: pushColor(result.content); break;
                case RTCmd.SET_SIZE:  pushSize (result.content); break;

                case RTCmd.POP_FONT:  popFont(); break;
                case RTCmd.POP_COLOR: popColor(); break;
                case RTCmd.POP_SIZE:  popSize(); break;
                case RTCmd.END: assert(0);
            }
        }
        m_lastContext = null;
        restoreState(s);
    }

    void setFont (SbFont font) {
        m_glyphs = m_glyphCollection.getCollection(font, m_fontScale);
    }
    void renderPlainString (string text, TRContext ctx) {
        //Glyph*[] glyphsToRender;

        LGlyph[] glyphGeometry;
        RedBlackTree!(GlyphPtr, "a.id < b.id") usedGlyphs;

        foreach (chr; text.byDchar) {
            auto glyph = m_glyphs[chr];
            if (glyph && layouter.advGlyphVisible(glyph)) {
                glyphGeometry ~= LGlyph(glyph, layouter.screenPos);
                m_usedGlyphs.insert(glyph);
            }
        }
        renderGlyphs( m_usedGlyphs.array );
        m_usedGlyphs.clear();

        foreach (glyph; glyphGeometry) {
            auto dim = layouter.toScreenspace(vec3(glyph.dim, 0));
            m_batchGeometry.pushQuad(
                glyph.pos,       glyph.uv0, m_colorIndex,
                glyph.pos + dim, glyph.uv1, m_colorIndex
            );
        }
    }
    private final void writeGlyph (Glyph* glyph) {
        auto pos    = m_layout.pos + toScreenCoords( glyph.layoutOffset );
        auto bounds = toScreenCoords( glyph.bounds * m_scaleTweak );

        if (inScreenBounds( pos, pos + bounds ))
            m_gbuf.push( pos, bounds, glyph.texId, m_colorIndex );
    }
    private final void packAndRenderGlyphs (Glyph* glyphs) {
        //foreach (glyph; glyphs) {
        //    m_fontPacker.packGlyph( glyph.bounds, glyph.texId, glyph.uv0 );
        //}
        //foreach (glyph; glyphs) {
        //    auto bitmap = m_bitmaps[ glyph.texId ];
        //    stbtt_MakeGlyphBitmap( bitmap.pixels, glyph.fontInfo, glyph.index, ... )
        //    bitmap.needsUpdate = true;
        //}
    }
    private float parseSize (string size) {
        try {
            return to!float(size);
        } catch (ConvException _) {
            return float.nan;
        }
    }

    // called by TRState push/pop impl
    private void onInvalidColor (string color) {
        log.write("Invalid color string: '%s'", color);
        renderPlainString(format("<color=%s>", color), m_lastContext);
    }
    private void onInvalidFont (string font) {
        log.write("Invalid font string: '%s'", font);
        renderPlainString(format("<font=%s>", font), m_lastContext);
    }
    private void onInvalidSize (string size) {
        log.write("Invalid font string: '%s'", size);
        renderPlainString(format("<size=%s>", size), m_lastContext);
    }    
}

private auto popLast (T)(ref T[] array) {
    auto v = array[$-1];
    --array.length;
    return v;
}

// Push/pop + state impl for TextRenderer.
// Code is a bit disgusting so it's been moved into a mixin template.
private mixin template TRState() {
    SbFont m_font;
    Color  m_color;
    float  m_size;

    private static struct StateFrame {
        SbFont[] fonts;
        Color [] colors;
        float[]  sizes;
    }
    StateFrame[] m_frames;

    private auto saveState () {
        m_frames[$-1].fonts  ~= m_font;
        m_frames[$-1].colors ~= m_color;
        m_frames[$-1].sizes  ~= m_size;
        m_frames ~= StateFrame([ m_font ], [ m_color ], [ m_size ]);
        return m_frames.length-1;
    }
    private void restoreState (ulong n) {
        while (m_frames.length > n)
            m_frames.length--;
        m_font  = m_frames[$-1].fonts.popLast;
        m_color = m_frames[$-1].colors.popLast;
        m_size  = m_frames[$-1].sizes.popLast;
    }

    private void pushFont (string name) {
        m_frames[$-1].fonts ~= m_font;
        auto font = m_fontMgr.getFont( name );
        if (font) {        
            m_font = font;
        } else {
            onInvalidFont(name);
        }
    }
    private void pushColor (string color) {
        try {
            m_frames[$-1].colors ~= m_color;
            m_color = to!Color(color);
        } catch (Exception e) {
            onInvalidColor(color);
        }
    }    
    private void pushSize (string size) {
        m_frames[$-1].sizes ~= m_size;
        auto sz = parseSize( size );
        if (!sz.isNaN) {
            m_size = sz;
        } else {
            onInvalidSize(size);
        }
    }

    private void popFont () {
        if (m_frames[$-1].fonts.length)
            m_font = m_frames[$-1].fonts.popLast;
    }
    private void popColor () {
        if (m_frames[$-1].colors.length)
            m_color = m_frames[$-1].colors.popLast;
    }
    private void popSize () { 
        if (m_frames[$-1].colors.length) 
            m_color = m_frames[$-1].colors.popLast; 
    }
}



















