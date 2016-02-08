
module gsb.text.textrendertest;
import gsb.text.textrenderer;
import std.stdio;
import std.file;
import std.format;
import std.utf;
import std.container.rbtree;

import stb.truetype;
import derelict.opengl3.gl3;
import dglsl;

class StbTextRenderTest {
    public string fontPath = "/Library/Fonts/Arial.ttf";
    public int BITMAP_WIDTH = 1024, BITMAP_HEIGHT = 1024;
    public float fontSize = 24;

    public void setText (string text) {
        if (__ctfe) 
            return;

        writeln("Starting StbTextRenderTest");

        // Load font
        if (!exists(fontPath) || (!attrIsFile(getAttributes(fontPath))))
            throw new ResourceError("Cannot load font file '%s'", fontPath);

        auto fontData = cast(ubyte[])read(fontPath);
        if (fontData.length == 0)
            throw new ResourceError("Failed to load font file '%s'", fontPath);

        stbtt_fontinfo fontInfo;
        if (!stbtt_InitFont(&fontInfo, fontData.ptr, 0))
            throw new ResourceError("stb: Failed to load font '%s'");

        // Determine charset
        auto rbcharset = new RedBlackTree!dchar();
        foreach (chr; byDchar(text))
            rbcharset.insert(chr);
        writef("charset: ");
        foreach (chr; rbcharset)
            writef("%c, ", chr);
        writef("\n");

        // Convert charset to an array and create lookup table
        dchar[] charset;
        int[dchar] chrLookup;
        {
            int i = 0;
            foreach (chr; rbcharset) {
                charset ~= chr;
                chrLookup[chr] = i++;
            }
        }

        // Create bitmap + pack chars
        ubyte[] bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * 1];

        stbtt_pack_context pck;
        stbtt_PackBegin(&pck, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, cast(void*)null);

        auto packedChrData = new stbtt_packedchar[ charset.length ];


        // Pack charset
        stbtt_pack_range r;
        r.font_size = fontSize;
        r.first_unicode_codepoint_in_range = 0;
        r.array_of_unicode_codepoints = cast(int*)charset.ptr;
        r.num_chars = cast(int)charset.length;
        r.chardata_for_range = packedChrData.ptr;

        stbtt_PackSetOversampling(&pck, 1, 1);
        stbtt_PackFontRanges(&pck, fontData.ptr, 0, &r, 1);

        stbtt_PackEnd(&pck);
        




    }
    public void render () {

    }

    static auto defaultTest () {
        auto test = new StbTextRenderTest();
        test.setText("hello world\nMa Chérie\nさいごの果実 / ミツバチと科学者");
        return test;
    }
}



























