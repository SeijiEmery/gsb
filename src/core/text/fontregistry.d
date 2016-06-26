module gsb.text.fontregistry;

// PUBLIC INTERFACE MODULE

enum : uint {
    FT_DEFAULT = 0,
    FT_ITALIC  = 1,
    FT_BOLD    = 2,
    FT_BOLD_ITALIC = 3,
    FT_COUNT = 4
}
struct FontPath {
    string path;
    int    index = 0;
    float  baseScaleFactor = 1.0;
}

interface IFontRegistry {
    void registerFont (string name, uint typeface, FontPath path);
    void registerFont (Args...)(string name, uint typeface, Args args) 
                            if (__traits(compiles, FontPath(args)));

    void fontFamily   (string fontId, string[] names);
    void fontAlias    (string fontId, string existingId);
}
