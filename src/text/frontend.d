
module gsb.text.frontend;
import gsb.text.backend;
import gsb.text.font;

import gsb.core.log;
//import gsb.core.window;
import gsb.core.events;
import gsb.core.color;

import std.typecons;
import std.container.rbtree;
import std.algorithm.iteration: map;
import std.conv;
import std.array;
import std.utf;

import gl3n.linalg;

class MockWindow {
    uint pixelWidth, pixelHeight;
    vec2 maxWindowExtents;
}
private MockWindow g_mainWindow;



class TextLayouter {
    void packIntoBuffer(TextElement elem, PackedCharset packedCharset, TextCuller culler, TextBuffer.Handle buffer, TextView view) {}
}
class TextView {
    mat4 transform;
    vec2 bounds;
    TextElement text;

    this (TextElement elem, mat4 transform, vec2 bounds) {
        this.text = elem;
        this.transform = transform;
        this.bounds = bounds;
    }
}
class PackedCharsetCache {
    static auto getOrCreateBestBitmapPacker (Charset charset, TextView view) { return new PackedCharset(charset); }
}
struct TextCuller {
    mat4 transform;
    vec2 localBounds;
    vec2 maxBounds;
}
class DefaultLayouter : TextLayouter {}




class TextStyle {
    Font[]   fontFamily;
    float    fontSize;
    Color    color;

    this (string[] fontFamily, float fontSize, string color) {
        this.fontFamily = fontFamily.map!(name => new Font(name)).array();
        this.fontSize   = fontSize;
        this.color      = to!Color(color);
    }
}

struct TextFragment {
    string text;
    TextStyle style;

    this (string text, TextStyle style) {
        this.text = text;
        this.style = style;
    }
}

class Charset {
    TextElement text;

    //alias FontPair = Tuple!(Font, int);

    RedBlackTree!dchar[Font] charsetsByFont;
    Font[dchar][]            fontLookupsByFragment;

    private this (TextElement text) {
        this.text = text;
        auto insertChr (dchar chr, Font font) {
            if (font !in charsetsByFont)
                charsetsByFont[font] = new RedBlackTree!dchar();
            charsetsByFont[font].insert(chr);
        }
        foreach (fragment; text.fragments) {
            RedBlackTree!dchar charset = new RedBlackTree!dchar();

            foreach (chr; fragment.text.byDchar)
                charset.insert(chr);

            //auto fontkvs = zip!(
            //    fragment.style.fontFamily,
            //    fragment.style.fontFamily.map!(font => format("%s:%dpx", font.name, font.pixelSize))
            //);

            Font[dchar] fontlookup;
            dchar[]     invalidChars;
            foreach (chr; charset) {
                //foreach (font; fontkvs) {
                foreach (font; fragment.style.fontFamily) {
                    if (font.contains(chr)) {
                        insertChr(chr, font);
                        fontlookup[chr] = font;
                        goto next;
                    }
                }
                // else, no matching fonts
                invalidChars ~= chr;
            next:
            }
            if (invalidChars.length) {
                log.write("Unsupported characters '%s' for font family [%s]", invalidChars.to!string(),
                    fragment.style.fontFamily.map!(font => font.name).array().join(", "));
            }
            fontLookupsByFragment ~= fontlookup;
        }
    }
    static auto create (TextElement elem) {
        return new Charset(elem);
    }
    Charset update (TextElement text) {
        return this;
    }
    unittest {
        // tbd...
    }
}

class PackedCharset {

    private this (Charset charset) {

    }
    static auto create (Charset charset) {
        return new PackedCharset(charset);
    }
}

class TextElement {
    TextLayouter   layouter;
    TextFragment[] fragments;
    //mat4           transform;
    
    Charset        charset;
    PackedCharset  packedCharset;

    private void rasterizeText (TextView view, TextBuffer.Handle buffer) {
        if (charset) charset.update(this);
        else         charset = Charset.create(this);

        packedCharset = PackedCharsetCache.getOrCreateBestBitmapPacker(charset, view);

        auto maxWindowBounds = g_mainWindow.maxWindowExtents;
        auto culler = TextCuller(view.transform, view.bounds, maxWindowBounds);

        if (!layouter) layouter = new DefaultLayouter();
        layouter.packIntoBuffer(this, packedCharset, culler, buffer, view);
    }
}

void test () {
    auto elem = new TextElement();
    elem.fragments ~= TextFragment("Hello, ", new TextStyle(["helvetica", "arial-unicode"], 40, "#ffaa9f"));
    elem.fragments ~= TextFragment("World",   new TextStyle(["helvetica-italic", "helvetica", "arial-unicode"], 40, "#ffcc7f"));
    elem.fragments ~= TextFragment("!",       new TextStyle(["helvetica-italic", "helvetica", "arial-unicode"], 40, "#aaffaa"));
    auto view = new TextView(elem, mat4().translate(g_mainWindow.pixelWidth * 0.5, g_mainWindow.pixelHeight * 0.5, 0.0).scale(1.5, 1.5, 1.0), vec2(800, 400));
    //WindowEvents.onScaleFactorChanged.connect(&view.rerenderWithScreenScale);
    //view.rerenderWithScreenScale(g_mainWindow.screenScale);
}




/+
void rasterizeTextElement (TextElement elem) {
    // Determine charsets
    RedBlackTree!dchar[string] charsets;
    auto insertChr (dchar chr, string font) {
        if (font !in charsets)
            charsets[font] = new RedBlackTree!dchar();
        charsets[font] = chr;
    }
    string[dchar][] fontlookups;

    foreach (fragment; elem.fragments) {
        RedBlackTree!dchar charset = new RedBlackTree!dchar();

        foreach (chr; fragment.text.byDChar)
            charset.insert(chr);

        auto fontkvs = zip!(
            fragment.style.fontFamily,
            fragment.style.fontFamily.map!(font => format("%s:%dpx", font.name, font.pixelSize))
        );

        string[dchar] fontlookup;
        foreach (chr; charset) {
            foreach (font; fontkvs) {
                if (font[0].contains(chr)) {
                    insertChr(chr, font[1]);
                    fontlookup[chr] = font[1];
                    goto next;
                }
            }
            // else, no matching fonts
            insertChr(chr, "invalid");
        next:
        }
        fontlookups ~= fontlookup;
    }
    if ("invalid" in charsets) {
        log.write("Warning -- unsupported characters: %s", charsets["invalid"].array().join(""));
    }



    // Now that we have our charsets (ordered by font), we can look for existing font packs that closely match
    // our charsets.

    // Okay, now we can pack stuff
    // Note: ideally we'd like to reuse font atlases, 
} +/








































