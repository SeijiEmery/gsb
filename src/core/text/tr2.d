module gsb.text.tr2;



//class SbFont { // font family
//    SbFontInstance[] m_fonts;
//    float            m_size;
//    //ChrInfo[] m_cachedCharInfo;

//    private ChrInfo getCharInfo (dchar chr) {
//        ChrInfo info;
//        foreach (font; m_fonts) {
//            if (font.getChrInfo(chr, info))
//                return info;
//        }
//        return getChrInfo(' ');
//    }

//    @property auto size (float size) {
//        size *= g_currentScreenScaleFactor;
//        foreach (font; m_fonts) {
//            font.setSize(size);
//        }
//    }
//}


//private struct SbFontInstance {
//    FontData m_data;
//    float    m_size;  // size in total pixels

//    // computed data
//    float m_computedScale;
//    float m_ascent, m_descent, m_lineGap;

//    bool getChrInfo (dchar chr, ref ChrInfo info) {
//        int glyph = m_data.getGlyphIndex(chr);
//        if (glyph != 0) {


//            return true;
//        }
//        return false;
//    }
//}




enum RTCmd { END = 0, TEXT, NEWLINE, SET_FONT, SET_SIZE, SET_COLOR, POP_FONT, POP_SIZE, POP_COLOR }
struct RTResult { RTCmd cmd; string content; }


private struct RichTextParser {
    import std.regex;

    private auto r = ctRegex!(`([^<>]|(?:\\[<>]))+|(<[^\>]+>|</\d*>)|(\n+)`);

    void setInput ( string text ) { m_input = text; }
    RTResult getNext () { 
        auto c = matchFirst( m_input, r );

        return RTResult( RTCmd.END, "" );
    }

    string m_input;
}

unittest {
    RichTextParser p;
    p.setInput("Foo \nbar<font=\"foo\">baz<size=\"10px\">bar</size></>Borg\\<foo\\>Blarg\n\nfoob");

    void assertEq (T)(T a, T b) {
        if (a != b) {
            import std.format;
            import core.exception: AssertError;
            throw new AssertError(format("%s != %s", a, b));
        }
    }

    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Foo"));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "bar"));
    assertEq( p.getNext, RTResult(RTCmd.SET_FONT, "foo"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "baz"));
    assertEq( p.getNext, RTResult(RTCmd.SET_SIZE, "10px"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "bar"));
    assertEq( p.getNext, RTResult(RTCmd.POP_SIZE, ""));
    assertEq( p.getNext, RTResult(RTCmd.POP_FONT, ""));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Borg<foo>Blarg"));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "foob"));
    assertEq( p.getNext, RTResult(RTCmd.END, ""));
}






//class TextRenderer {

//    immutable richTextRegex = ctRegex!(`([^<>]|(?:\\[<>]))+|(<[^\>]+>|</\d*>)|(\n+)`);

//    void renderRichString( string text, TRContext context ) {
//        auto s = saveState();

//        restoreState(s);
//    }
//}




















