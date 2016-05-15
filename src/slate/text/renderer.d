
//module gsb.slate.text.renderer;
//import gsb.slate.text.packing;
//import stb.truetype;

//struct FontBitmapRenderer {
//    void renderGlyphs () {}
//}

//struct BitmapRenderItem {
//    stbtt_fontinfo* fontinfo;
//    float fontScale = 0;
//    dchar[] charset;
//}


//stbtt call hierarchy:
//stbtt_PackFontRanges
//    stbtt_PackFontRangesGatherRects
//        stbtt_ScaleForPixelHeight
//        stbtt_FindGlyphIndex
//        stbtt_GetGlyphBitmapBoxSubpixel
//        (just gets rect properties; mostly for user so this is totally replaceable)

//    stbtt_PackFontRangesPackRects
//        stbrp_pack_rects
//            (custom packing algorithm; we'll be replacing this)

//    stbtt_PackFontRangesRenderIntoRects
//            stbtt_FindGlyphIndex(fontinfo, codepoint)
//            stbtt_GetGlyphHMetrics
//            stbtt_GetGlyphBitmapBox
//            stbtt_MakeGlyphBitmapSubpixel
//                stbtt_GetGlyphShape
//                stbtt_GetGlyphBitmapBoxSubpixel
//                stbtt_Rasterize

//            stbtt__h_prefilter iff h_oversample > 1
//            stbtt__v_prefilter iff v_oversample > 1

 



//private GlyphRect[] glyphs;
//void render (BitmapRenderItem[] items) {
//    struct GlyphRect {
//        stbtt_fontinfo* font;
//        int glyphIndex;
//        vec2 bounds;
//    }

//    glyphs.length = 0;
//    foreach (item; items) {
//        foreach (chr; item.charset) {
//            auto glyph = stbtt_FindGlyphIndex(item.fontinfo, chr);



//            glyphs ~= GlyphRect(item.fontinfo,
//                glyph,
//                // ...?
//            );
//        }
//    }
//    glyphs.sort!"a.bounds.y < b.bounds.y";
//    foreach (glyph; glyphs) {

//    }

//    // layout glyphs...
//    foreach (tex; fakeTexture) {
//        auto texture = makeTexture(tex);
//        foreach (glpyh; tex.glyphs) {

//        }
//    }
//}
//struct TextRenderer {
//}
//+/
