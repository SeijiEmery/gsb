
module gsb.text.font;

import gsb.core.log;
import gsb.core.singleton;
import gsb.core.errors;
import gsb.core.pseudosignals;
import stb.truetype;

import std.file;
import std.format;

class Font {
    string   name;
    FontData data;

    @property int pixelSize () { return 0; }
    bool contains (dchar chr) {
        return true;
    }
}

private class FontData {
    stbtt_fontinfo fontInfo;
    ubyte[]        contents;
    string         fontPath;
    int            fontIndex;
}

private struct FontLoader {
    struct RawFontData {
        ubyte[] contents;
    }
    alias FileData = ubyte[];

    private FileData[string] loadedFiles;
    private FontData[string] loadedFonts;

    Signal!(string)          onFontFileLoaded;
    Signal!(string,FontData) onFontLoaded;

    FontData loadFont (string fontPath, int fontIndex) {
        auto index = format("%s:%d", fontPath, fontIndex);
        if (index in loadedFonts) {
            return loadedFonts[index];
        }
        if (fontPath !in loadedFiles) {
            if (!exists(fontPath) || !attrIsFile(getAttributes(fontPath)))
                throw new ResourceError("Invalid font file: '%s' does not exist", fontPath);
            auto contents = cast(ubyte[])read(fontPath);
            if (contents.length == 0)
                throw new ResourceError("Invalid font file: '%s' file length is zero", fontPath);
            loadedFiles[fontPath] = contents;
            onFontFileLoaded.emit(fontPath);
        }
        auto font = new FontData();
        font.contents = loadedFiles[fontPath];
        font.fontPath = fontPath;
        font.fontIndex = fontIndex;
        auto offset = stbtt_GetFontOffsetForIndex(font.contents.ptr, fontIndex);
        if (offset == -1)
            throw new ResourceError("Invalid font file (could not get offset for index %d in '%s')", fontIndex, fontPath);
        if (!stbtt_InitFont(&font.fontInfo, font.contents.ptr, offset))
            throw new ResourceError("Invalid font file (stbtt failed to init font data: '%s', index %d)", fontPath, fontIndex);
        loadedFonts[index] = font;
        onFontLoaded.emit(fontPath, font);
        return font;
    }
}

class FontCache {
private:
    FontLoader loader;

public:
    static Font get (string fontname) { return new Font(); }

    static void registerFont (string fontname, string fontpath, int fontindex = 0) {

    }
}
























