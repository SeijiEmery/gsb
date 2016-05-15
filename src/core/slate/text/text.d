
module gsb.slate.text.text;

import gsb.core.log;
import gsb.core.singleton;
import gsb.core.color;
import gsb.text.font;
import gsb.coregl;
import gl3n.linalg;

import std.conv;
import std.utf;
import std.range.primitives;
import std.algorithm.iteration;
import std.array;


// Dirtyable property
private mixin template  RWDirtyProperty (string name, uint flag) {
    mixin(
        "final @property auto "~name~"() { return m_"~name~"; }"~
        "final @property auto "~name~"(typeof(m_"~name~") v) { "~
            "setDirty("~to!string(flag)~"); return m_"~name~" = v; }"
    );
}

private struct TextElement {
public:
    mixin RWDirtyProperty!("text", TextFlags.DIRTY_CONTENT);
    mixin RWDirtyProperty!("position", TextFlags.DIRTY_POSITION);
    mixin RWDirtyProperty!("font", TextFlags.DIRTY_FONT);
    mixin RWDirtyProperty!("color", TextFlags.DIRTY_COLOR);
    mixin RWDirtyProperty!("fontSize", TextFlags.DIRTY_FONTSIZE);

    @property auto layout () {
        return m_layout ?
            (maybeUpdateLayout(), m_layout) :
            m_layout = new Layout(this);
    }

    @property bool visible () { return (m_flags & TextFlags.NON_VISIBLE) == 0; }
    @property bool visible (bool v) {
        return ((v ? 
            m_flags &= ~TextFlags.NON_VISIBLE :
            m_flags |= TextFlags.NON_VISIBLE) & TextFlags.NON_VISIBLE) == 0;
    }

private:
    void setDirty (ushort flags) {
        m_dirtyFlags |= flags;
    }
    void clearFlags (ushort mask) {
        m_dirtyFlags &= mask;
    }
    void maybeUpdateLayout () {
        assert(m_layout);
        if (m_dirtyFlags & TextFlags.DIRTY_LAYOUT_CONTENT) {
            clearFlags(TextFlags.CLEAR_LAYOUT);
            m_layout.relayout();
        } else if (m_dirtyFlags & TextFlags.DIRTY_POSITION) {
            clearFlags(TextFlags.CLEAR_LAYOUT);
            m_layout.updatePosition();
        }
    }

    string m_text;
    Layout m_layout;
    Font   m_font;
    Color  m_color;
    vec2   m_position;
    float  m_fontSize;
    ushort m_flags;
    ushort   m_dirtyFlags;
}

interface IBatcher2d {

}



struct IndexedCharset (T) {
    T[256]   low_buckets;
    T[dchar] high_buckets;

    void insertUnique (R)(R charset, T delegate (dchar) make_value) if (isInputRange!R && is(ElementType!R == dchar)) {
        foreach (chr; charset) {
            if (chr < 256 && !low_buckets[chr])
                low_buckets[chr] = make_value(chr);
            else if (chr >= 256 && chr !in high_buckets)
                high_buckets[chr] = make_value(chr);
        }
    }
}
private struct FontElem {
    Font font = null;
    int  index = -1;
    bool opCast (T: bool)() { return font !is null; }
}
private struct FontIndex {
    IndexedCharset!FontElem fc;
}

void warnCharUnsupported (Font font, dchar chr) {}
int  getCharIndex (Font font, dchar chr) { return -1; }
Font fallbackFont (Font font) { return null; }


void doLayout (ref TextElement elem, ref FontIndex index) {
    import std.utf;
    index.fc.insertUnique(elem.text.byDchar, (dchar chr) {
        auto font = elem.font;
        while (font && !font.contains(chr))
            font = font.fallbackFont;
        if (!font)
            warnCharUnsupported(elem.font, chr);
        return FontElem(font, font.getCharIndex(chr));
    });

    elem.layout.fragments.length = 0;
    foreach (line; elem.text.split("\n")) {
        elem.layout.fragments ~= TextFragment();
    }


}


private enum TextFlags : ushort {
    NON_VISIBLE = 0x1,

    CLEAR_MASK     = 0x0f,  // clear non-persistent flags

    DIRTY_CONTENT  = 0x10,
    DIRTY_FONT     = 0x20,
    DIRTY_FONTSIZE = 0x40,
    DIRTY_POSITION = 0x80,
    DIRTY_COLOR    = 0x100,
    DIRTY_INTERNAL_LAYOUT = 0x200,

    DIRTY_LAYOUT_CONTENT = DIRTY_CONTENT | DIRTY_FONT | DIRTY_FONTSIZE,
    CLEAR_LAYOUT   = cast(ushort)~(DIRTY_LAYOUT_CONTENT | DIRTY_POSITION), // clear layout flags: content, font, fontsize, position
}

struct TextFragment {}

private class Layout {
    TextElement element;
    TextFragment[] fragments;
    vec2 lastPos;


    this (TextElement element) {
        this.element = element;
        this.lastPos = element.position;
        relayout();
    }

    void relayout () {

    }
    void updatePosition () {

    }
}

private class TextRenderer {
    mixin LowLockSingleton;

    private TextElement[] activeElements;

    void update (IBatcher2d batch) {
        foreach (elem; activeElements) {
            if (elem.visible) {

            }
        }


    }



}











































