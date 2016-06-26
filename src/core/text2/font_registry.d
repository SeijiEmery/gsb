module gsb.core.text2.font_registry;

//
// PUBLIC FONT REGISTRY INTERFACE (used by config/fontconfig.d)
//

// Typeface enums. FT_DEFAULT, etc., are aliased to FontTypeface values.
enum FontTypeface : uint { DEFAULT = 0, ITALIC = 1, BOLD = 2, BOLD_ITALIC = 3 };
enum : uint { FT_DEFAULT = 0, FT_ITALIC = 1, FT_BOLD = 2, FT_BOLD_ITALIC = 3, FT_COUNT = 4 };

interface IFontRegistry {
    // Define a font typeface (bold/italic/default/etc) for a given font path + index.
    // @path should be a valid gsb path to a system or local .ttf or .ttc file.
    // @fontIndex is an optional argument used for .ttc files that contain multiple fonts.
    //
    // see fontconfig.d for examples.
    void registerFont (string name, FontTypeface typeface, string path, int fontIndex = 0);

    // Define a font fallback for a given font (if unicode character does not exist in that
    // font, fallback to X). Not providing full fallback chains for all fonts will cause
    // warnings + invisible text if undefined characters are used for that font (eg. hiragana)
    void fontFallback (string font, string fallback);

    // Create an aliased font name (eg. your-system-font => "default"). 
    // Aliased font names share the same internal data structures, so there is no overhead
    // from doing this.
    void fontAlias    (string name, string existing);
}

// Helper method -- allows registerFont to be called with FT_DEFAULT, etc.
void registerFont (IFontRegistry r, string name, uint typeface, string path, int fontIndex = 0) {
    import std.format;
    assert( typeface < FT_COUNT, format("Invalid typeface: %s", typeface) );
    r.registerFont(name, cast(FontTypeface)typeface, path, fontIndex);
}
