
module gsb.text.font;

import gsb.core.log;
import gsb.core.singleton;
import gsb.core.errors;
import gsb.core.pseudosignals;
import stb.truetype;
import core.sync.mutex;

import std.file;
import std.format;
import std.algorithm.iteration: map;
import std.array;

class Font {
    string   name;
    FontData data;

    this (string name) {
        this.name = name;
        this.data = FontCache.getFontData(name);
    }

    @property int pixelSize () { return 0; }
    bool contains (dchar chr) {
        return true;
    }
}

struct FontCache {
    static FontData getFontData (string fontName) {
        auto font = FontRegistry.getFontPath(fontName);
        return FontLoader.getFont(font.path, font.index);
    }
    static FontData[] getFontFamily (string name) {
        return FontRegistry.getFontFamily(name).map!getFontData().array();
    }
}

private class FontData {
    stbtt_fontinfo fontInfo;
    ubyte[]        contents;
    string         fontPath;
    int            fontIndex;
}

private struct FontLoader {
    private static __gshared FontLoader.Instance instance;
    //private static __gshared auto mutex = new Mutex();

    static struct Instance {
        struct RawFontData {
            ubyte[] contents;
        }
        alias FileData = ubyte[];

        private FileData[string] loadedFiles;
        private FontData[string] loadedFonts;

        Signal!(string)          onFontFileLoaded;
        Signal!(string,FontData) onFontLoaded;

        FontData getFont (string fontPath, int fontIndex) {
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
    static auto getFont (string fontPath, int fontIndex) {
        synchronized /*(mutex)*/ { return instance.getFont(fontPath, fontIndex); }
    }
}

struct FontRegistry {
    private static __gshared FontRegistry.Instance instance;
    //private static __gshared auto mutex = new Mutex();

    static struct Instance {
        private struct FontId {
            string path;
            int index;
        }

        private FontId[string]   fontPaths;
        private string[][string] fontFamilies;

        public void registerFont (string fontName, string fontPath, int fontIndex) {
            if (fontName in fontPaths && (fontPaths[fontName].path != fontPath || fontPaths[fontName].index != fontIndex))
                throw new ResourceError("FontRegistry: overriding font lookup for '%s': '%s:%d' with '%s:%d'", 
                    fontName, fontPaths[fontName].path, fontPaths[fontName].index, fontPath, fontIndex);
            fontPaths[fontName] = FontId(fontPath, fontIndex);
        }
        public void registerFontFamily (string fontFamilyName, string[] listOfFontNames) {
            fontFamilies[fontFamilyName] = listOfFontNames;
        }
        public auto getFontPath (string name) { 
            if (name !in fontPaths)
                throw new ResourceError("No registered font '%s'", name);
            return fontPaths[name];
        }
        public auto getFontFamily (string name) {
            if (name !in fontFamilies)
                throw new ResourceError("No registered font family '%s'", name);
            return fontFamilies[name];
        }
    }

    // Global versions
    static void registerFont (string fontName, string fontPath, int fontIndex) {
        synchronized /*(mutex)*/ { instance.registerFont(fontName, fontPath, fontIndex); }
    }
    static void registerFontFamily (string fontFamilyName, string[] listOfFontNames) {
        synchronized /*(mutex)*/ { instance.registerFontFamily(fontFamilyName, listOfFontNames); }
    }
    static auto getFontPath (string fontName) {
        synchronized /*(mutex)*/ { return instance.getFontPath(fontName); }
    }
    static auto getFontFamily (string fontFamilyName) {
        synchronized /*(mutex)*/ { return instance.getFontFamily(fontFamilyName); }
    }
}

