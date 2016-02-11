//
// Basic stb lib for stuff that I'll be using.
//


#include "stdlib.h"

void * stbtt_alloc (size_t sz, void * ctx);
void stbtt_free (void * ptr, void * ctx);

#define STBTT_malloc stbtt_alloc
#define STBTT_free   stbtt_free

#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"






