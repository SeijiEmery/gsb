
module gsb.text.textrenderer;

import std.stdio;
import std.file;
import stb.truetype;

class Font {
	stbtt_fontinfo font;
	float scale;
	int ascent, baseline;

	this (string filename) {
		ubyte[] contents = cast(ubyte[])read(filename);
		stbtt_InitFont(&font, &contents[0], 0);

		scale = stbtt_ScaleForPixelHeight(&font, 15);
		stbtt_GetFontVMetrics(&font, &ascent, null, null);
		baseline = cast(int)(ascent * scale);
	}
}

Font loadFont (string filename) {
	if (!exists(filename) || !attrIsFile(getAttributes(filename))) {
		writefln("Cannot open '%s'", filename);
		return null;
	}

	return new Font(filename);
}

class TextBuffer {
	Font font;
	float[] quads;
	float[] uvs;

	this (Font font) {
		font = font;
	}
	TextBuffer appendText (string text) {

		foreach (chr; text) {

		}
		return this;
	}
}
































































