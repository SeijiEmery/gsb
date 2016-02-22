
module gsb.text.font;

import gsb.core.log;

import std.file;
import std.format;

class Font {
    string name;
    int pixelSize;

    bool contains (dchar chr) {
        return true;
    }
}

class FontCache {
    static Font get (string fontname) { return new Font(); } 
}
























