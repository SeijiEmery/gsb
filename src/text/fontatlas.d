
module gsb.text.fontatlas;
import gsb.text.font;
import gsb.core.log;
import gsb.core.errors;
import gsb.core.window;
import stb.truetype;

import std.format;
import std.container.rbtree;
import std.range.primitives;
import core.sync.rwmutex;
import Derelict.opengl3.gl3;
import gsb.glutils;
import gl3n.linalg;


immutable int BITMAP_WIDTH = 1024;
immutable int BITMAP_HEIGHT = 1024;
immutable int BITMAP_CHANNELS = 1;  // hardcoded by stb_truetype, so this won't change

class PackedFontAtlas {
    private stbtt_pack_context    packContext;
    private stbtt_packedchar[]    packedChars;    // sequential array of all stb packed char data
    private size_t[dchar][string] charLookup;     // lookup of indices for this array (ordered by hashed font, codepoint)

    private ubyte[] bitmapData = null;
    private bool dirtyTexture = false;
    private ReadWriteMutex mutex;

    this () {
        mutex = new ReadWriteMutex();
    }
    @property auto read () { return mutex.reader(); }
    @property auto write () { return mutex.writer(); }

    void insertCharset (Range)(Font font, Range charset) if (is(ElementType!Range == dchar)) {
        auto index = format("%s:%d", font.name, to!int(font.size));

        dchar[] toInsert;
        if (index !in charLookup) {
            size_t[dchar] thing;
            charLookup[index] = thing;
        }

        foreach (chr; charset) {
            if (chr !in charLookup[index]) {
                toInsert ~= chr;
                charLookup[index][chr] = size_t.max; // temp assign to prevent duplicates, and makes sure we blow up if we mess up below
            }
        }
        if (toInsert.length) {
            synchronized (write) {
                lazyInit();

                stbtt_pack_range r;
                r.font_size = font.getSize(g_mainWindow.screenScale.y);
                r.array_of_unicode_codepoints = cast(int*)toInsert.ptr;
                r.num_chars = cast(int)toInsert.length;
                auto packData = new stbtt_packedchar[toInsert.length];
                r.chardata_for_range = packData.ptr;
                stbtt_PackFontRanges(&packContext, font.data.contents.ptr, font.data.fontIndex, &r, 1);

                auto i = packedChars.length;
                packedChars ~= packData;
                foreach (chr; toInsert) {
                    charLookup[index][chr] = i++;
                    //log.write("Set '%s', %c = %d", index, chr, i-1);
                }
                dirtyTexture = true;
            }

            log.write("Packed %d characters into font atlas; font = '%s', charset = '%s'", toInsert.length, index, toInsert);
        }
    }

    auto getQuads (Range)(Font font, Range text, ref float layoutX, ref float layoutY, bool alignToInteger = false) if (is(ElementType!Range == dchar)) 
    {
        auto index = format("%s:%d", font.name, to!int(font.size));
        if (index !in charLookup)
            throw new ResourceError("PackedFontAtlas font '%s' has not been packed! (does contain %s)",
                index, charLookup.byKey.map!((a) => format("'%s'", a)).join(", "));

        stbtt_aligned_quad quad;

        ref auto getQuad (dchar chr) {
            if (chr !in charLookup[index])
                throw new ResourceError("PackedFontAtlas codepoint %c (%s) has not been packed!", chr, index);
            //log.write("Got '%s', %c = %d", index, chr, charLookup[index][chr]);
            stbtt_GetPackedQuad(packedChars.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, cast(int)charLookup[index][chr], 
                &layoutX, &layoutY, &quad, alignToInteger);
            return quad;
        }
        return text.map!getQuad;
    }

    private void lazyInit () {
        if (!bitmapData) {
            log.write("PackedFontAtlas: creating resources");
            bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * BITMAP_CHANNELS];
            if (!stbtt_PackBegin(&packContext, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, null)) {
                throw new ResourceError("sbttt_PackBegin failed");
            }
            stbtt_PackSetOversampling(&packContext, 4, 4);
        }
    }
    void releaseResources () {
        if (bitmapData) {
            log.write("PackedFontAtlas: releasing resources!");
            stbtt_PackEnd(&packContext);
            bitmapData = null;
        }
    }
    ~this () {
        releaseResources();
    }

    class GraphicsBackend {
        GLuint texture = 0;

        void update () {
            synchronized (read) {
                if (dirtyTexture) {
                    dirtyTexture = false;
                    if (!texture) {
                        log.write("Creating texture");
                        checked_glGenTextures(1, &texture);
                    }
                    log.write("Uploading PackedFontAtlas bitmap");
                    checked_glActiveTexture(GL_TEXTURE0);
                    checked_glBindTexture(GL_TEXTURE_2D, texture);
                    checked_glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, BITMAP_WIDTH, BITMAP_HEIGHT, 0, GL_RED, GL_UNSIGNED_BYTE, bitmapData.ptr);
                    checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                    checked_glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                    //checked_glBindTexture(GL_TEXTURE_2D, 0);
                }
            }
        }
        void bindTexture () {
            if (texture) {
                checked_glActiveTexture(GL_TEXTURE0);
                checked_glBindTexture(GL_TEXTURE_2D, texture);
            } else {
                log.write("PackedFontAtlas.GraphicsBackend.bindTexture(): No texture!");
            }
        }
        void releaseResources () {
            if (texture) {
                checked_glDeleteTextures(1, &texture);
                texture = 0;
            }
        }


        ~this () {
            releaseResources();
        }
    }



}








































