module gsb.text.tr2;
import gsb.utils.color;
import gsb.core.log;
import std.conv;
import std.math;
import std.format;


enum RTCmd { END = 0, TEXT, NEWLINE, 
    SET_ITALIC, SET_BOLD, SET_FONT, SET_SIZE, SET_COLOR, 
    END_ITALIC, END_BOLD, POP_FONT, POP_SIZE, POP_COLOR 
}
struct RTResult { RTCmd cmd; string content; }


// Parses unity-style richtext into sequences of "commands" for:
// - plaintext, containing no newlines or parseable tags (unregcognized tags will show up here)
// - a variable number of endlines (content.length => # of endlines)
// - begin/end commands for various kinds of tags.
//      "<color=#ff293a>" => SET_COLOR, "#ff293a"
//      "</color>"        => POP_COLOR, ""
// - invalid / ill-formed tags do NOT throw exceptions, but are instead rendered as plaintext
//   (as mentioned above). If you see tags showing up in the text displayed by TextRenderer,
//   then they either contain syntax errors or there is a bug in RichTextParser / TextRenderer.
//
// RichTextParser is a state machine; input is set with setInput() and results are obtained
// via either getNext() or the ForwardRange interface (empty(), front(), popFront).
//
private struct RichTextParser {
    import std.regex;

    immutable string MATCH_NEWLINE = `\n+`;
    immutable string MATCH_ESCAPE  = `\\[<>tn]`;
    immutable string MATCH_TEXT    = `[^<\n\\]+`;
    immutable string MATCH_TAG     = `</?(\w+)(?:=([^>]+))?>`;
    private auto r = regex(`^` ~ MATCH_TAG ~ `|` ~ MATCH_NEWLINE ~ `|`~ MATCH_ESCAPE ~ `|` ~ MATCH_TEXT);

    // Range interface
    auto ref parse (string text) {
        setInput(text);
        m_front = getNext();
        return this;
    }
    bool empty () { return m_front.cmd == RTCmd.END; }
    auto front () { return m_front; }
    void popFront () { m_front = getNext(); }


    // Non-range interface
    void setInput ( string text ) { m_input = text; m_front = RTResult(RTCmd.END, ""); }
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
        auto unescape (string s) {
            if (s[0] == '\\' && (s[1] == '>' || s[1] == '<'))
                return s[1..$];
            return s;
        }

        // Accumulate remaining text + escapes (each capture.hit returns either a string of text with no
        // escapes, or a 2-character string '\\', <some char>. We merge all of these together into one
        // string, either including or excluding '\\' depending on the char that follows (unescape '<' and '>',
        // for example; leave everything else as is).
        auto text = unescape(c.hit);
        while (m_input.length) {
            auto c2 = matchFirst( m_input, r );
            if (c2.hit[0] != '<' && c2.hit[0] != '\n') {
                m_input = c2.post;
                text ~= unescape(c2.hit);
            } else break;
        }
        return RTResult(RTCmd.TEXT, text);
    }

private:
    string m_input;
    RTResult m_front = RTResult(RTCmd.END);
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

    import std.array;
    assertEq( p.parse("foo\n<i>bar</i>").array, [ 
        RTResult(RTCmd.TEXT, "foo"),
        RTResult(RTCmd.NEWLINE, "\n"),
        RTResult(RTCmd.SET_ITALIC),
        RTResult(RTCmd.TEXT, "bar"),
        RTResult(RTCmd.END_ITALIC)
    ]);

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


    p.setInput("Foo \nbar<font=foo>baz<size=10px><color=#ffaa2cef>bar</size></font>Borg\\<foo\\><b>Blarg<i>\n\nfoob</b></i></color>");
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "Foo "));
    assertEq( p.getNext, RTResult(RTCmd.NEWLINE, "\n"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "bar"));
    assertEq( p.getNext, RTResult(RTCmd.SET_FONT, "foo"));
    assertEq( p.getNext, RTResult(RTCmd.TEXT, "baz"));
    assertEq( p.getNext, RTResult(RTCmd.SET_SIZE, "10px"));
    assertEq( p.getNext, RTResult(RTCmd.SET_COLOR, "#ffaa2cef"));
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
    assertEq( p.getNext, RTResult(RTCmd.POP_COLOR, ""));
    assertEq( p.getNext, RTResult(RTCmd.END, ""));
}


class TRContext {}
class SbFont {}
private class FontManager {
    SbFont getFont (string name) {
        return new SbFont();
    }
}

class TextRenderer {
    RichTextParser m_rtp;
    FontManager    m_fontMgr;
    mixin TRState;
    TRContext      m_lastContext;

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

    void renderPlainString (string text, TRContext ctx) {

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



















