
module gsb.text.fontatlas;
import gsb.text.font;
import gsb.core.log;
import gsb.core.errors;
import gsb.core.window;
import stb.truetype;
import gsb.coregl.gl;

import std.format;
import std.container.rbtree;
import std.range.primitives;
import std.array;
import std.algorithm: map, min, max;
import core.sync.rwmutex;
import gl3n.linalg;
import std.conv;

private void DEBUG_LOG (lazy void expr) {
    static if (TEXTRENDERER_DEBUG_LOGGING_ENABLED) expr();
}

immutable int BITMAP_WIDTH = 1024;
immutable int BITMAP_HEIGHT = 1024;
immutable int BITMAP_CHANNELS = 1;  // hardcoded by stb_truetype, so this won't change

class PackedFontAtlas {
    private stbtt_pack_context    packContext;
    private stbtt_packedchar[]    packedChars;    // sequential array of all stb packed char data
    private size_t[dchar][string] charLookup;     // lookup of indices for this array (ordered by hashed font, codepoint)

    private ubyte[] bitmapData = null;
    private bool dirtyTexture = false;
    private bool shouldRelease = false;
    private ReadWriteMutex mutex;

    this () {
        mutex = new ReadWriteMutex();
    }
    @property auto read () { return mutex.reader(); }
    @property auto write () { return mutex.writer(); }

    private GraphicsBackend _backend = null;
    @property auto backend () {
        if (!_backend)
            _backend = new GraphicsBackend();
        return _backend;
    }

    void insertCharset (Range)(Font font, Range charset) if (is(ElementType!Range == dchar)) {
        auto index = font.stringId;

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
            stbtt_PackSetOversampling(&packContext, font.oversampling.x, font.oversampling.y);
            synchronized (write) {
                lazyInit();

                stbtt_pack_range r;
                r.font_size = font.getSize(1.0);
                r.array_of_unicode_codepoints = cast(int*)toInsert.ptr;
                r.num_chars = cast(int)toInsert.length;
                auto packData = new stbtt_packedchar[toInsert.length];
                r.chardata_for_range = packData.ptr;
                stbtt_PackFontRanges(&packContext, font.data.contents.ptr, font.data.fontIndex, &r, 1);

                auto i = packedChars.length;
                packedChars ~= packData;
                foreach (chr; toInsert) {
                    charLookup[index][chr] = i++;
                    //DEBUG_LOG(log.write("Set '%s', %c = %d", index, chr, i-1));
                }
                dirtyTexture = true;
            }

            DEBUG_LOG(log.write("Packed %d characters into font atlas; font = '%s', charset = '%s'", toInsert.length, index, toInsert));
        }
    }
    void repack () {
        synchronized (write) {
            DEBUG_LOG(log.write("Repacking FontAtlas"));
            foreach (kv; charLookup.byKeyValue()) {
                auto parts = kv.key.split(":");
                auto font = new Font(parts[0], to!int(parts[1]));
                DEBUG_LOG(log.write("Recreating font: '%s' = '%s', %d", kv.key, font.name, to!int(font.size)));
                // Note: creating a 'new' font is cheap since FontCache caches everything in the backend;
                // new Font("foo", 16), new Font("foo", 16), and new Font("foo", 32) all point to the same
                // shared FontData, and the backing truetype files are loaded lazily + cached

                // hmm... we can now rebuild the font atlas easily enough (we have the font data + size,
                // and the charset + indices are in kv.value.keys() / kv.value.values(), respectively),
                // but we'll _also_ need to rebuild all the dependent geometry buffers so the uvs are 
                // correct... I'll have to get back to this later.

                throw new Exception("PackedFontAtlas dynamic repacking is not yet implemented!");
            }
        }
    }
    //void setOversampling (vec2i value) {
    //    if (!bitmapData)
    //        bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * BITMAP_CHANNELS];
    //    else
    //        stbtt_PackEnd(&packContext);
    //    if (!stbtt_PackBegin(&packContext, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, null)) {
    //        throw new ResourceException("stbtt_PackBegin failed");
    //    }
    //    stbtt_PackSetOversampling(&packContext, value.x, value.y);
    //    repack();
    //}

    auto getQuads (Range)(Font font, Range text, ref float layoutX, ref float layoutY, bool alignToInteger = false) if (is(ElementType!Range == dchar)) 
    {
        auto index = font.stringId;
        if (index !in charLookup)
            throw new ResourceException("PackedFontAtlas font '%s' has not been packed! (does contain %s)",
                index, charLookup.byKey.map!((a) => format("'%s'", a)).join(", "));

        stbtt_aligned_quad quad;

        ref auto getQuad (dchar chr) {
            if (chr !in charLookup[index])
                throw new ResourceException("PackedFontAtlas codepoint %c (%s) has not been packed!", chr, index);
            //DEBUG_LOG(log.write("Got '%s', %c = %d", index, chr, charLookup[index][chr]));
            stbtt_GetPackedQuad(packedChars.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, cast(int)charLookup[index][chr], 
                &layoutX, &layoutY, &quad, alignToInteger);
            return quad;
        }
        return text.map!getQuad;
    }

    private void lazyInit () {
        if (!bitmapData) {
            DEBUG_LOG(log.write("PackedFontAtlas: creating resources"));
            bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * BITMAP_CHANNELS];
            if (!stbtt_PackBegin(&packContext, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, null)) {
                throw new ResourceException("sbttt_PackBegin failed");
            }
            stbtt_PackSetOversampling(&packContext, 4, 4);
        }
    }
    void releaseResources () {
        shouldRelease = true;
        if (bitmapData) {
            DEBUG_LOG(log.write("PackedFontAtlas: releasing resources!"));
            stbtt_PackEnd(&packContext);
            bitmapData = null;
        }
    }
    ~this () {
        releaseResources();
    }

    class GraphicsBackend {
        import gsb.coregl.resource.texture;
        ITexture texture;

        this () {
            texture = new GlTexture()
                .setFilter( GL_LINEAR, GL_LINEAR );
        }
        void update () {
            synchronized (read) {
                texture.pixelData(
                    TextureDataFormat( GL_RED, GL_RED, GL_UNSIGNED_BYTE ),
                    vec2i( BITMAP_WIDTH, BITMAP_HEIGHT ),
                    bitmapData 
                );
            }
        }
        void bindTexture () {
            // Bind to texture 0
            (cast(GlTexture)texture).bind( 0 );
        }
        void releaseResources () {
            texture.release();
        }
        ~this () {
            releaseResources();
        }
    }
}








































