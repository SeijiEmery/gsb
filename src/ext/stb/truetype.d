//
// Bindings to stb_truetype.h
//

module stb.truetype;
import std.stdio;
import std.algorithm;
import std.format;
//import std.typecons : Unique;
//import std.experimental.allocator.common : Ternary;
//import std.experimental.allocator.building_blocks.free_tree : FreeTree;
//import std.experimental.allocator.building_blocks.region : Region;
//import std.experimental.allocator.building_blocks.allocator_list : AllocatorList;
//import std.experimental.allocator.building_blocks.stats_collector : StatsCollector, Options;
//import std.experimental.allocator.mallocator : Mallocator;
import core.stdc.stdlib : free, malloc;

extern (C) void * stbtt_alloc (size_t sz, void * ctx) {
    return malloc(sz);
}
extern (C) void stbtt_free (void * ptr, void * ctx) {
    free(ptr);
}

void * stbtt_createAllocator () {
    return null;
}



/+
import core.sync.mutex : Mutex;

void * our_allocator = null;

extern (C) void * stbtt_alloc (size_t sz, void * ctx) {
    if (__ctfe)
        return null;
    if (sz == 0) return null;

    writeln("allocating; ctx = ", ctx);
    if (!our_allocator)
        our_allocator = ctx;
    else if (our_allocator != ctx)
        ctx = our_allocator;
        //throw new Exception(format("%x != %x", our_allocator, ctx));

    return allocToPtr(ctx ? *cast(PoolAllocator*)ctx : g_stbttAllocator, sz);
}
extern (C) void stbtt_free (void * ptr, void * ctx) {
    if (__ctfe)
        return;
    if (!ptr) return;

    writeln("deallocating; ctx = ", ctx);
    if (!our_allocator)
        our_allocator = ctx;
    else if (our_allocator != ctx)
        ctx = our_allocator;


    deallocFromPtr(ctx ? *cast(PoolAllocator*)ctx : g_stbttAllocator, ptr);
}

void * allocToPtr (Allocator)(ref Allocator a, size_t sz) {
    void[] blk = a.allocate(sz = size_t.sizeof);
    if (blk.length == 0)
        return null;
    (cast(size_t*)blk)[0] = blk.length;
    return blk.ptr + size_t.sizeof;
}
void deallocFromPtr (Allocator)(ref Allocator a, void * ptr) {
    auto realptr = ptr - size_t.sizeof;
    auto sz = (cast(size_t*)ptr)[0];
    auto blk = realptr[0..sz];
    a.deallocate(blk);
}

//alias PoolAllocator = StatsCollector!(FreeTree!(Region!Mallocator), Options.all);

//alias PoolAllocator = Mallocator;
//auto createAllocator () {
//    return Mallocator();   
//}

//__gshared auto g_stbttMallocator = Mallocator();
//__gshared auto g_stbttFreeTree   = FreeTree(g_stbttMallocator);
//__gshared auto g_stbttAllocator = StatsCollector(g_stbttFreeTree);

auto stbtt_createAllocator () {
    return StatsCollector!(FreeTree!Mallocator)(FreeTree!Mallocator());
}
alias PoolAllocator = typeof(stbtt_createAllocator());
__gshared auto g_stbttAllocator = stbtt_createAllocator();

+/



//__gshared auto g_stbttAllocator = StatsCollector!(FreeTree!Mallocator)(FreeTree!Mallocator());


//__gshared auto g_stbttAllocator = StatsCollector!(FreeTree!(Mallocaftor()));
//private __gshared Unique!PoolAllocator g_stbttAllocator;
//shared static this () {
//    g_stbttAllocator = createAllocator();
//}



//shared static this () {
//    if (!__ctfe) {
//        g_stbttAllocator = StatsCollector!(FreeTree!(Region!Mallocator(1024 * 1024)), Options.all);
//    }
//}




//private __gshared SharedStbttAllocator _shared_stbtt_allocator = null;
////shared static this () {
////    _shared_stbtt_allocator = new SharedStbttAllocator();
////}

//void dumpStbttGlobalAllocatorStats () {
//    _shared_stbtt_allocator.dumpStats();
//}

////private auto createAllocator () {
////    assert(!__ctfe);
////    return StatsCollector!(FreeTree!(Region!Mallocator(1024 * 1024)), Options.all);
////}


//class StbttPoolAllocator {
//    auto allocator = StatsCollector!(FreeTree!(Region!Mallocator(1024 * 1024)), Options.all);

//    ~this () {
//        dumpStats();
//        allocator.deallocateAll();
//    }
//    unittest {
//        //auto allocator = new StbttPoolAllocator();
//        //assert(allocator.allocator.empty() != Ternary.no, "allocator should be empty at startup");
//        //auto alloc = allocator.allocator.allocate(50);
//        //assert(alloc.length != 0, "allocator should be capable of allocating memory");
//        //allocator.allocator.deallocate(alloc);
//        //assert(allocator.allocator.empty() != Ternary.no, "allocator should be empty after all memory has been released");
//    }


//    void dumpStats () {
//        //allocator.reportStatistics(stdout);
//    }
//    void * alloc (size_t sz) {
//        if (__ctfe) return null;
//        writefln("trying to allocate %d bytes", sz + size_t.sizeof);
//        void[] data = allocator.allocate(sz + size_t.sizeof);
//        writefln("allocated %d bytes", data.length);
//        if (data.length <= size_t.sizeof)
//            return null;
//        (cast(size_t[])data)[0] = data.length;
//        return data.ptr + size_t.sizeof;
//    }
//    void free (void * ptr) {
//        if (__ctfe) return;
//        void * real_ptr = ptr - size_t.sizeof;
//        size_t sz = (cast(size_t*)real_ptr)[0];
//        allocator.deallocate(real_ptr[0..sz]);
//    }
//}

//class SharedStbttAllocator : StbttPoolAllocator {
//    Mutex mutex;

//    override void dumpStats () {
//        //mutex.lock();
//        //scope(exit) mutex.unlock();

//        super.dumpStats();
//    }
//    override void * alloc (size_t sz) {
//        writeln("In shared allocator (alloc)");
//        //mutex.lock();
//        //scope(exit) mutex.unlock();

//        return super.alloc(sz);
//    }
//    override void free (void * ptr) {
//        writeln("In shared allocator (free)");
//        //mutex.lock();
//        //scope(exit) mutex.unlock();

//        super.free(ptr);
//    }
//}






extern (C) {

//////////////////////////////////////////////////////////////////////////////
//
// TEXTURE BAKING API
//
// If you use this API, you only have to call two functions ever.
//

struct stbtt_bakedchar {
   ushort x0,y0,x1,y1; // coordinates of bbox in bitmap
   float xoff,yoff,xadvance;
}

int stbtt_BakeFontBitmap(const ubyte *data, int offset,  // font location (use offset=0 for plain .ttf)
                                float pixel_height,                // height of font in pixels
                                ubyte *pixels, int pw, int ph,     // bitmap to be filled in
                                int first_char, int num_chars,     // characters to bake
                                stbtt_bakedchar *chardata);        // you allocate this, it's num_chars long
// if return is positive, the first unused row of the bitmap
// if return is negative, returns the negative of the number of characters that fit
// if return is 0, no characters fit and no rows were used
// This uses a very crappy packing.

struct stbtt_aligned_quad {
   float x0,y0,s0,t0; // top-left
   float x1,y1,s1,t1; // bottom-right
}

void stbtt_GetBakedQuad(stbtt_bakedchar *chardata, int pw, int ph,  // same data as above
                               int char_index,             // character to display
                               float *xpos, float *ypos,   // pointers to current position in screen pixel space
                               stbtt_aligned_quad *q,      // output: quad to draw
                               int opengl_fillrule);       // true if opengl fill rule; false if DX9 or earlier
// Call GetBakedQuad with char_index = 'character - first_char', and it
// creates the quad you need to draw and advances the current position.
//
// The coordinate system used assumes y increases downwards.
//
// Characters will extend both above and below the current position;
// see discussion of "BASELINE" above.
//
// It's inefficient; you might want to c&p it and optimize it.



//////////////////////////////////////////////////////////////////////////////
//
// NEW TEXTURE BAKING API
//
// This provides options for packing multiple fonts into one atlas, not
// perfectly but better than nothing.

struct stbtt_packedchar {
   ushort x0,y0,x1,y1; // coordinates of bbox in bitmap
   float xoff,yoff,xadvance;
   float xoff2,yoff2;
}

int  stbtt_PackBegin(stbtt_pack_context *spc, ubyte *pixels, int width, int height, int stride_in_bytes, int padding, void *alloc_context);
// Initializes a packing context stored in the passed-in stbtt_pack_context.
// Future calls using this context will pack characters into the bitmap passed
// in here: a 1-channel bitmap that is weight x height. stride_in_bytes is
// the distance from one row to the next (or 0 to mean they are packed tightly
// together). "padding" is the amount of padding to leave between each
// character (normally you want '1' for bitmaps you'll use as textures with
// bilinear filtering).
//
// Returns 0 on failure, 1 on success.

void stbtt_PackEnd  (stbtt_pack_context *spc);
// Cleans up the packing context and frees all memory.

//#define STBTT_POINT_SIZE(x)   (-(x))
int STBTT_POINT_SIZE(int x) { return -x; }

int  stbtt_PackFontRange(stbtt_pack_context *spc, ubyte *fontdata, int font_index, float font_size,
                                int first_unicode_char_in_range, int num_chars_in_range, stbtt_packedchar *chardata_for_range);
// Creates character bitmaps from the font_index'th font found in fontdata (use
// font_index=0 if you don't know what that is). It creates num_chars_in_range
// bitmaps for characters with unicode values starting at first_unicode_char_in_range
// and increasing. Data for how to render them is stored in chardata_for_range;
// pass these to stbtt_GetPackedQuad to get back renderable quads.
//
// font_size is the full height of the character from ascender to descender,
// as computed by stbtt_ScaleForPixelHeight. To use a point size as computed
// by stbtt_ScaleForMappingEmToPixels, wrap the point size in STBTT_POINT_SIZE()
// and pass that result as 'font_size':
//       ...,                  20 , ... // font max minus min y is 20 pixels tall
//       ..., STBTT_POINT_SIZE(20), ... // 'M' is 20 pixels tall

struct stbtt_pack_range {
   float font_size;
   int first_unicode_codepoint_in_range;  // if non-zero, then the chars are continuous, and this is the first codepoint
   int *array_of_unicode_codepoints;       // if non-zero, then this is an array of unicode codepoints
   int num_chars;
   stbtt_packedchar *chardata_for_range; // output
   ubyte h_oversample, v_oversample; // don't set these, they're used internally
}

int  stbtt_PackFontRanges(stbtt_pack_context *spc, ubyte *fontdata, int font_index, stbtt_pack_range *ranges, int num_ranges);
// Creates character bitmaps from multiple ranges of characters stored in
// ranges. This will usually create a better-packed bitmap than multiple
// calls to stbtt_PackFontRange. Note that you can call this multiple
// times within a single PackBegin/PackEnd.

void stbtt_PackSetOversampling(stbtt_pack_context *spc, uint h_oversample, uint v_oversample);
// Oversampling a font increases the quality by allowing higher-quality subpixel
// positioning, and is especially valuable at smaller text sizes.
//
// This function sets the amount of oversampling for all following calls to
// stbtt_PackFontRange(s) or stbtt_PackFontRangesGatherRects for a given
// pack context. The default (no oversampling) is achieved by h_oversample=1
// and v_oversample=1. The total number of pixels required is
// h_oversample*v_oversample larger than the default; for example, 2x2
// oversampling requires 4x the storage of 1x1. For best results, render
// oversampled textures with bilinear filtering. Look at the readme in
// stb/tests/oversample for information about oversampled fonts
//
// To use with PackFontRangesGather etc., you must set it before calls
// call to PackFontRangesGatherRects.

void stbtt_GetPackedQuad(stbtt_packedchar *chardata, int pw, int ph,  // same data as above
                               int char_index,             // character to display
                               float *xpos, float *ypos,   // pointers to current position in screen pixel space
                               stbtt_aligned_quad *q,      // output: quad to draw
                               int align_to_integer);

alias stbrp_coord = int;

struct stbrp_context {
   int width,height;
   int x,y,bottom_y;
}

struct stbrp_node {
   ubyte x;
}

struct stbrp_rect {
   stbrp_coord x,y;
   int id,w,h,was_packed;
}

int  stbtt_PackFontRangesGatherRects(stbtt_pack_context *spc, stbtt_fontinfo *info, stbtt_pack_range *ranges, int num_ranges, stbrp_rect *rects);
void stbtt_PackFontRangesPackRects(stbtt_pack_context *spc, stbrp_rect *rects, int num_rects);
int  stbtt_PackFontRangesRenderIntoRects(stbtt_pack_context *spc, stbtt_fontinfo *info, stbtt_pack_range *ranges, int num_ranges, stbrp_rect *rects);
// Calling these functions in sequence is roughly equivalent to calling
// stbtt_PackFontRanges(). If you more control over the packing of multiple
// fonts, or if you want to pack custom data into a font texture, take a look
// at the source to of stbtt_PackFontRanges() and create a custom version 
// using these functions, e.g. call GatherRects multiple times,
// building up a single array of rects, then call PackRects once,
// then call RenderIntoRects repeatedly. This may result in a
// better packing than calling PackFontRanges multiple times
// (or it may not).

// this is an opaque structure that you shouldn't mess with which holds
// all the context needed from PackBegin to PackEnd.
struct stbtt_pack_context {
   void *user_allocator_context;
   void *pack_info;
   int   width;
   int   height;
   int   stride_in_bytes;
   int   padding;
   uint   h_oversample, v_oversample;
   ubyte *pixels;
   void  *nodes;
};

//////////////////////////////////////////////////////////////////////////////
//
// FONT LOADING
//
//

enum {
    STBTT_vmove=1,
    STBTT_vline,
    STBTT_vcurve
};

alias stbtt_vertex_type = short;
struct stbtt_vertex {
    stbtt_vertex_type x,y,cx,cy;
    ubyte type,padding;
}


int stbtt_GetFontOffsetForIndex(const ubyte *data, int index);
// Each .ttf/.ttc file may have more than one font. Each font has a sequential
// index number starting from 0. Call this function to get the font offset for
// a given index; it returns -1 if the index is out of range. A regular .ttf
// file will only define one font and it always be at offset 0, so it will
// return '0' for index 0, and -1 for all other indices. You can just skip
// this step if you know it's that kind of font.


// The following structure is defined publically so you can declare one on
// the stack or as a global or etc, but you should treat it as opaque.
struct stbtt_fontinfo
{
   void           * userdata;
   ubyte  * data;              // pointer to .ttf file
   int              fontstart;         // offset of start of font

   int numGlyphs;                     // number of glyphs, needed for range checking

   int loca,head,glyf,hhea,hmtx,kern; // table locations as offset from start of .ttf
   int index_map;                     // a cmap mapping for our chosen character encoding
   int indexToLocFormat;              // format needed to map from glyph index to glyph
}

int stbtt_InitFont(stbtt_fontinfo *info, const ubyte *data, int offset);
// Given an offset into the file that defines a font, this function builds
// the necessary cached info for the rest of the system. You must allocate
// the stbtt_fontinfo yourself, and stbtt_InitFont will fill it out. You don't
// need to do anything special to free it, because the contents are pure
// value data with no additional data structures. Returns 0 on failure.


//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER TO GLYPH-INDEX CONVERSIOn

int stbtt_FindGlyphIndex(const stbtt_fontinfo *info, int unicode_codepoint);
// If you're going to perform multiple operations on the same character
// and you want a speed-up, call this function with the character you're
// going to process, then use glyph-based functions instead of the
// codepoint-based functions.


//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER PROPERTIES
//

float stbtt_ScaleForPixelHeight(const stbtt_fontinfo *info, float pixels);
// computes a scale factor to produce a font whose "height" is 'pixels' tall.
// Height is measured as the distance from the highest ascender to the lowest
// descender; in other words, it's equivalent to calling stbtt_GetFontVMetrics
// and computing:
//       scale = pixels / (ascent - descent)
// so if you prefer to measure height by the ascent only, use a similar calculation.

float stbtt_ScaleForMappingEmToPixels(const stbtt_fontinfo *info, float pixels);
// computes a scale factor to produce a font whose EM size is mapped to
// 'pixels' tall. This is probably what traditional APIs compute, but
// I'm not positive.

void stbtt_GetFontVMetrics(const stbtt_fontinfo *info, int *ascent, int *descent, int *lineGap);
// ascent is the coordinate above the baseline the font extends; descent
// is the coordinate below the baseline the font extends (i.e. it is typically negative)
// lineGap is the spacing between one row's descent and the next row's ascent...
// so you should advance the vertical position by "*ascent - *descent + *lineGap"
//   these are expressed in unscaled coordinates, so you must multiply by
//   the scale factor for a given size

void stbtt_GetFontBoundingBox(const stbtt_fontinfo *info, int *x0, int *y0, int *x1, int *y1);
// the bounding box around all possible characters

void stbtt_GetCodepointHMetrics(const stbtt_fontinfo *info, int codepoint, int *advanceWidth, int *leftSideBearing);
// leftSideBearing is the offset from the current horizontal position to the left edge of the character
// advanceWidth is the offset from the current horizontal position to the next horizontal position
//   these are expressed in unscaled coordinates

int  stbtt_GetCodepointKernAdvance(const stbtt_fontinfo *info, int ch1, int ch2);
// an additional amount to add to the 'advance' value between ch1 and ch2

int stbtt_GetCodepointBox(const stbtt_fontinfo *info, int codepoint, int *x0, int *y0, int *x1, int *y1);
// Gets the bounding box of the visible part of the glyph, in unscaled coordinates

void stbtt_GetGlyphHMetrics(const stbtt_fontinfo *info, int glyph_index, int *advanceWidth, int *leftSideBearing);
int  stbtt_GetGlyphKernAdvance(const stbtt_fontinfo *info, int glyph1, int glyph2);
int  stbtt_GetGlyphBox(const stbtt_fontinfo *info, int glyph_index, int *x0, int *y0, int *x1, int *y1);
// as above, but takes one or more glyph indices for greater efficiency


//////////////////////////////////////////////////////////////////////////////
//
// GLYPH SHAPES (you probably don't need these, but they have to go before
// the bitmaps for C declaration-order reasons)
//

int stbtt_IsGlyphEmpty(const stbtt_fontinfo *info, int glyph_index);
// returns non-zero if nothing is drawn for this glyph

int stbtt_GetCodepointShape(const stbtt_fontinfo *info, int unicode_codepoint, stbtt_vertex **vertices);
int stbtt_GetGlyphShape(const stbtt_fontinfo *info, int glyph_index, stbtt_vertex **vertices);
// returns # of vertices and fills *vertices with the pointer to them
//   these are expressed in "unscaled" coordinates
//
// The shape is a series of countours. Each one starts with
// a STBTT_moveto, then consists of a series of mixed
// STBTT_lineto and STBTT_curveto segments. A lineto
// draws a line from previous endpoint to its x,y; a curveto
// draws a quadratic bezier from previous endpoint to
// its x,y, using cx,cy as the bezier control point.

void stbtt_FreeShape(const stbtt_fontinfo *info, stbtt_vertex *vertices);
// frees the data allocated above

//////////////////////////////////////////////////////////////////////////////
//
// BITMAP RENDERING
//

void stbtt_FreeBitmap(ubyte *bitmap, void *userdata);
// frees the bitmap allocated below

ubyte *stbtt_GetCodepointBitmap(const stbtt_fontinfo *info, float scale_x, float scale_y, int codepoint, int *width, int *height, int *xoff, int *yoff);
// allocates a large-enough single-channel 8bpp bitmap and renders the
// specified character/glyph at the specified scale into it, with
// antialiasing. 0 is no coverage (transparent), 255 is fully covered (opaque).
// *width & *height are filled out with the width & height of the bitmap,
// which is stored left-to-right, top-to-bottom.
//
// xoff/yoff are the offset it pixel space from the glyph origin to the top-left of the bitmap

ubyte *stbtt_GetCodepointBitmapSubpixel(const stbtt_fontinfo *info, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint, int *width, int *height, int *xoff, int *yoff);
// the same as stbtt_GetCodepoitnBitmap, but you can specify a subpixel
// shift for the character

void stbtt_MakeCodepointBitmap(const stbtt_fontinfo *info, ubyte *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int codepoint);
// the same as stbtt_GetCodepointBitmap, but you pass in storage for the bitmap
// in the form of 'output', with row spacing of 'out_stride' bytes. the bitmap
// is clipped to out_w/out_h bytes. Call stbtt_GetCodepointBitmapBox to get the
// width and height and positioning info for it first.

void stbtt_MakeCodepointBitmapSubpixel(const stbtt_fontinfo *info, ubyte *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint);
// same as stbtt_MakeCodepointBitmap, but you can specify a subpixel
// shift for the character

void stbtt_GetCodepointBitmapBox(const stbtt_fontinfo *font, int codepoint, float scale_x, float scale_y, int *ix0, int *iy0, int *ix1, int *iy1);
// get the bbox of the bitmap centered around the glyph origin; so the
// bitmap width is ix1-ix0, height is iy1-iy0, and location to place
// the bitmap top left is (leftSideBearing*scale,iy0).
// (Note that the bitmap uses y-increases-down, but the shape uses
// y-increases-up, so CodepointBitmapBox and CodepointBox are inverted.)

void stbtt_GetCodepointBitmapBoxSubpixel(const stbtt_fontinfo *font, int codepoint, float scale_x, float scale_y, float shift_x, float shift_y, int *ix0, int *iy0, int *ix1, int *iy1);
// same as stbtt_GetCodepointBitmapBox, but you can specify a subpixel
// shift for the character

// the following functions are equivalent to the above functions, but operate
// on glyph indices instead of Unicode codepoints (for efficiency)
ubyte *stbtt_GetGlyphBitmap(const stbtt_fontinfo *info, float scale_x, float scale_y, int glyph, int *width, int *height, int *xoff, int *yoff);
ubyte *stbtt_GetGlyphBitmapSubpixel(const stbtt_fontinfo *info, float scale_x, float scale_y, float shift_x, float shift_y, int glyph, int *width, int *height, int *xoff, int *yoff);
void stbtt_MakeGlyphBitmap(const stbtt_fontinfo *info, ubyte *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int glyph);
void stbtt_MakeGlyphBitmapSubpixel(const stbtt_fontinfo *info, ubyte *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int glyph);
void stbtt_GetGlyphBitmapBox(const stbtt_fontinfo *font, int glyph, float scale_x, float scale_y, int *ix0, int *iy0, int *ix1, int *iy1);
void stbtt_GetGlyphBitmapBoxSubpixel(const stbtt_fontinfo *font, int glyph, float scale_x, float scale_y,float shift_x, float shift_y, int *ix0, int *iy0, int *ix1, int *iy1);


// @TODO: don't expose this structure
struct stbtt__bitmap {
   int w,h,stride;
   ubyte *pixels;
}

// rasterize a shape with quadratic beziers into a bitmap
void stbtt_Rasterize(stbtt__bitmap *result,        // 1-channel bitmap to draw into
                               float flatness_in_pixels,     // allowable error of curve in pixels
                               stbtt_vertex *vertices,       // array of vertices defining shape
                               int num_verts,                // number of vertices in above array
                               float scale_x, float scale_y, // scale applied to input vertices
                               float shift_x, float shift_y, // translation applied to input vertices
                               int x_off, int y_off,         // another translation applied to input
                               int invert,                   // if non-zero, vertically flip shape
                               void *userdata);              // context for to STBTT_MALLOC

//////////////////////////////////////////////////////////////////////////////
//
// Finding the right font...
//
// You should really just solve this offline, keep your own tables
// of what font is what, and don't try to get it out of the .ttf file.
// That's because getting it out of the .ttf file is really hard, because
// the names in the file can appear in many possible encodings, in many
// possible languages, and e.g. if you need a case-insensitive comparison,
// the details of that depend on the encoding & language in a complex way
// (actually underspecified in truetype, but also gigantic).
//
// But you can use the provided functions in two possible ways:
//     stbtt_FindMatchingFont() will use *case-sensitive* comparisons on
//             unicode-encoded names to try to find the font you want;
//             you can run this before calling stbtt_InitFont()
//
//     stbtt_GetFontNameString() lets you get any of the various strings
//             from the file yourself and do your own comparisons on them.
//             You have to have called stbtt_InitFont() first.


int stbtt_FindMatchingFont(const ubyte *fontdata, const char *name, int flags);
// returns the offset (not index) of the font that matches, or -1 if none
//   if you use STBTT_MACSTYLE_DONTCARE, use a font name like "Arial Bold".
//   if you use any other flag, use a font name like "Arial"; this checks
//     the 'macStyle' header field; i don't know if fonts set this consistently
const uint STBTT_MACSTYLE_DONTCARE = 0;
const uint STBTT_MACSTYLE_BOLD = 0;
const uint STBTT_MACSTYLE_ITALIC = 2;
const uint STBTT_MACSTYLE_UNDERSCORE = 4;
const uint STBTT_MACSTYLE_NONE = 8;   // <= not same as 0, this makes us check the bitfield is 0

int stbtt_CompareUTF8toUTF16_bigendian(const char *s1, int len1, const char *s2, int len2);
// returns 1/0 whether the first string interpreted as utf8 is identical to
// the second string interpreted as big-endian utf16... useful for strings from next func

const(char)* stbtt_GetFontNameString(const stbtt_fontinfo *font, int *length, int platformID, int encodingID, int languageID, int nameID);
// returns the string (which may be big-endian double byte, e.g. for unicode)
// and puts the length in bytes in *length.
//
// some of the values for the IDs are below; for more see the truetype spec:
//     http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6name.html
//     http://www.microsoft.com/typography/otspec/name.htm

enum { // platformID
   STBTT_PLATFORM_ID_UNICODE   =0,
   STBTT_PLATFORM_ID_MAC       =1,
   STBTT_PLATFORM_ID_ISO       =2,
   STBTT_PLATFORM_ID_MICROSOFT =3
};

enum { // encodingID for STBTT_PLATFORM_ID_UNICODE
   STBTT_UNICODE_EID_UNICODE_1_0    =0,
   STBTT_UNICODE_EID_UNICODE_1_1    =1,
   STBTT_UNICODE_EID_ISO_10646      =2,
   STBTT_UNICODE_EID_UNICODE_2_0_BMP=3,
   STBTT_UNICODE_EID_UNICODE_2_0_FULL=4
};

enum { // encodingID for STBTT_PLATFORM_ID_MICROSOFT
   STBTT_MS_EID_SYMBOL        =0,
   STBTT_MS_EID_UNICODE_BMP   =1,
   STBTT_MS_EID_SHIFTJIS      =2,
   STBTT_MS_EID_UNICODE_FULL  =10
};

enum { // encodingID for STBTT_PLATFORM_ID_MAC; same as Script Manager codes
   STBTT_MAC_EID_ROMAN        =0,   STBTT_MAC_EID_ARABIC       =4,
   STBTT_MAC_EID_JAPANESE     =1,   STBTT_MAC_EID_HEBREW       =5,
   STBTT_MAC_EID_CHINESE_TRAD =2,   STBTT_MAC_EID_GREEK        =6,
   STBTT_MAC_EID_KOREAN       =3,   STBTT_MAC_EID_RUSSIAN      =7
};

enum { // languageID for STBTT_PLATFORM_ID_MICROSOFT; same as LCID...
       // problematic because there are e.g. 16 english LCIDs and 16 arabic LCIDs
   STBTT_MS_LANG_ENGLISH     =0x0409,   STBTT_MS_LANG_ITALIAN     =0x0410,
   STBTT_MS_LANG_CHINESE     =0x0804,   STBTT_MS_LANG_JAPANESE    =0x0411,
   STBTT_MS_LANG_DUTCH       =0x0413,   STBTT_MS_LANG_KOREAN      =0x0412,
   STBTT_MS_LANG_FRENCH      =0x040c,   STBTT_MS_LANG_RUSSIAN     =0x0419,
   STBTT_MS_LANG_GERMAN      =0x0407,   STBTT_MS_LANG_SPANISH     =0x0409,
   STBTT_MS_LANG_HEBREW      =0x040d,   STBTT_MS_LANG_SWEDISH     =0x041D
};

enum { // languageID for STBTT_PLATFORM_ID_MAC
   STBTT_MAC_LANG_ENGLISH      =0 ,   STBTT_MAC_LANG_JAPANESE     =11,
   STBTT_MAC_LANG_ARABIC       =12,   STBTT_MAC_LANG_KOREAN       =23,
   STBTT_MAC_LANG_DUTCH        =4 ,   STBTT_MAC_LANG_RUSSIAN      =32,
   STBTT_MAC_LANG_FRENCH       =1 ,   STBTT_MAC_LANG_SPANISH      =6 ,
   STBTT_MAC_LANG_GERMAN       =2 ,   STBTT_MAC_LANG_SWEDISH      =5 ,
   STBTT_MAC_LANG_HEBREW       =10,   STBTT_MAC_LANG_CHINESE_SIMPLIFIED =33,
   STBTT_MAC_LANG_ITALIAN      =3 ,   STBTT_MAC_LANG_CHINESE_TRAD =19
};


} // extern(C)

