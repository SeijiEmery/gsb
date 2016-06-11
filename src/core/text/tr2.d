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




enum RTCmd { END = 0, TEXT, NEWLINE, 
    SET_ITALIC, SET_BOLD, SET_FONT, SET_SIZE, SET_COLOR, 
    END_ITALIC, END_BOLD, POP_FONT, POP_SIZE, POP_COLOR 
}
struct RTResult { RTCmd cmd; string content; }


private struct RichTextParser {
    import std.regex;

    immutable string MATCH_NEWLINE = `\n+`;
    immutable string MATCH_ESCAPE  = `\\[<>tn]`;
    immutable string MATCH_TEXT    = `[^<\n\\]+`;
    immutable string MATCH_TAG     = `</?(\w+)(?:=([^>]+))?>`;
    private auto r = ctRegex!(`^` ~ MATCH_TAG ~ `|` ~ MATCH_NEWLINE ~ `|`~ MATCH_ESCAPE ~ `|` ~ MATCH_TEXT);
    private auto r_justText = ctRegex!(`^` ~ MATCH_ESCAPE ~ `|` ~ MATCH_TEXT );

    void setInput ( string text ) { m_input = text; }
    RTResult getNext () { 
        if (!m_input.length)
            return RTResult(RTCmd.END, "");

        auto c = matchFirst( m_input, r );
        m_input = c.post;

        if (c.hit[0] == '<') {
            if (c.hit[1] != '/') {
                switch (c[1]) {
                    case "b": return RTResult(RTCmd.SET_BOLD, "");
                    case "i": return RTResult(RTCmd.SET_ITALIC, "");
                    case "font": return RTResult(RTCmd.SET_FONT, c[2]);
                    case "color": return RTResult(RTCmd.SET_COLOR, c[2]);
                    case "size":  return RTResult(RTCmd.SET_SIZE, c[2]);
                    default:
                }
            } else {
                switch (c[1]) {
                    case "b": return RTResult(RTCmd.END_BOLD, "");
                    case "i": return RTResult(RTCmd.END_ITALIC, "");
                    case "font": return RTResult(RTCmd.POP_FONT, "");
                    case "color": return RTResult(RTCmd.POP_COLOR, "");
                    case "size": return RTResult(RTCmd.POP_SIZE, "");
                    default:
                }
            }
        } else if (c.hit[0] == '\n') {
            return RTResult(RTCmd.NEWLINE, c.hit);
        }
        // Otherwise...

        import gsb.core.log;

        auto unescape (string s) {
            if (s[0] == '\\' && (s[1] == '>' || s[1] == '<'))
                return s[1..$];
            return s;
        }

        // Accumulate remaining text + escapes
        auto text = unescape(c.hit);
        log.write("Text! %s", text);

        while (m_input.length) {
            auto c2 = matchFirst( m_input, r );
            if (c2.hit[0] != '<' && c2.hit[0] != '\n') {
                m_input = c2.post;
                text ~= unescape(c2.hit);
                log.write("Text! %s (%s)", text, c2.hit);
            } else break;
        }
        return RTResult(RTCmd.TEXT, text);
    }

    string m_input;
}

unittest {
    void assertEq (T)(T a, T b, string file = __FILE__, uint line = __LINE__) {
        if (a != b) {
            import std.format;
            import core.exception: AssertError;
            throw new AssertError(format("%s != %s", a, b), file, line);
        }
    }
    RichTextParser p;

    p.setInput("foo\\<bar\\>baz\n\n\n\\nborg\\>");
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "foo<bar>baz"));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n\n\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "\\nborg>"));
    assertEq( p.getNext, RTResult(RTCmd.END, ""));

    
    p.setInput("Foob\nBlarg<i>Foo</i>Bar<i><b>\nBaz\n</i>Borg</b>foo");
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Foob"));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Blarg"));
    assertEq( p.getNext, RTResult(RTCmd.SET_ITALIC, ""));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Foo"));
    assertEq( p.getNext, RTResult(RTCmd.END_ITALIC, ""));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Bar"));
    assertEq( p.getNext, RTResult(RTCmd.SET_ITALIC, ""));
    assertEq( p.getNext, RTResult(RTCmd.SET_BOLD, ""));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Baz"));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n"));
    assertEq( p.getNext, RTResult(RTCmd.END_ITALIC, ""));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Borg"));
    assertEq( p.getNext, RTResult(RTCmd.END_BOLD, ""));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "foo"));
    assertEq( p.getNext, RTResult(RTCmd.END, ""));
    assertEq( p.getNext, RTResult(RTCmd.END, ""));
    assertEq( p.getNext, RTResult(RTCmd.END, ""));


    p.setInput("Foo \nbar<font=foo>baz<size=10px>bar</size></font>Borg\\<foo\\><b>Blarg<i>\n\nfoob</b></i>");
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Foo "));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "bar"));
    assertEq( p.getNext, RTResult(RTCmd.SET_FONT, "foo"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "baz"));
    assertEq( p.getNext, RTResult(RTCmd.SET_SIZE, "10px"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "bar"));
    assertEq( p.getNext, RTResult(RTCmd.POP_SIZE, ""));
    assertEq( p.getNext, RTResult(RTCmd.POP_FONT, ""));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Borg<foo>"));
    assertEq( p.getNext, RTResult(RTCmd.SET_BOLD, ""));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Blarg"));
    assertEq( p.getNext, RTResult(RTCmd.SET_ITALIC, ""));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "foob"));
    assertEq( p.getNext, RTResult(RTCmd.END_BOLD, ""));
    assertEq( p.getNext, RTResult(RTCmd.END_ITALIC, ""));
    assertEq( p.getNext, RTResult(RTCmd.END, ""));
}






//class TextRenderer {

//    immutable richTextRegex = ctRegex!(`([^<>]|(?:\\[<>]))+|(<[^\>]+>|</\d*>)|(\n+)`);

//    void renderRichString( string text, TRContext context ) {
//        auto s = saveState();

//        restoreState(s);
//    }
//}




















