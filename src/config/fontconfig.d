module gsb.config.fonts;
import gsb.core.text2.font_registry;

// Called by application to register font paths + info.
// – call registerFont( font-name, style, path, font-index = 0, base-scale = 1.0 ) with ttf/ttc files
// - call fontFamily( font-id, [ font-names... ])
//   or   fontAlias( font-id, existing-font-id ) to setup default fonts.
//
// Notes:
// – font-index is an optional index into a .ttc file. Multiple font typefaces (default, italic, bold, etc)
// may be either stored as individual entries within the same .ttc file (with specific indexes) or as separate
// files with index = 0.
// - font families are a list of specific fonts to use in order as fallbacks; these MUST cover
// the entire UTF charset as individual fonts usually only cover a charset (eg. on osx menlo does
// not cover kanji but arial unicode does); failure to cover the full charset will result in either
// runtime errors or invisible characters depending on the implementation.
// – paths _may_ be specified relative to "~/", "${PROJ_DIR}" (the root gsb source directory, eg. "${PROJ_DIR}/fonts"),
// the appdata directory "${LOCAL_DIR}" ("~/Library/Application Support/gsb", "~/.config/gsb", or "%APP_DATA%/gsb")),
// or the cache directory "${CACHE_DIR}" = "${LOCAL_DIR}/cache".
//
void gsb_registerFonts (IFontRegistry r) {
    version (OSX) {        
        // our fallback font (unicode characters, etc)
        r.registerFont("arial", FT_DEFAULT, "/System/Library/Fonts/Arial Unicode.ttf", 0);

        // default console font
        r.registerFont("menlo", FT_DEFAULT, "/System/Library/Fonts/Menlo.ttc", 0);
        r.registerFont("menlo", FT_ITALIC,  "/System/Library/Fonts/Menlo.ttc", 1);
        r.registerFont("menlo", FT_BOLD,    "/System/Library/Fonts/Menlo.ttc", 2);
        r.registerFont("menlo", FT_BOLD_ITALIC, "/System/Library/Fonts/Menlo.ttc", 3);
        r.fontFallback("menlo", "arial");

        // more fonts tbd...

        // Font families:
        //r.fontFamily("arial", [ "arial" ]);
        //r.fontFamily("menlo", [ "menlo", "arial" ]); // fallback for unicode

        // And define aliases (same as r.fontFamily("console", [ "menlo", "arial" ]))
        r.fontAlias("console", "menlo");
        r.fontAlias("default", "arial");
    }
    version (linux) {
        r.registerFont("droid-sans-mono", FT_DEFAULT, "/usr/share/fonts/truetype/droid/DroidSansMono.ttf", 0);
        r.registerFont("droid-sans",      FT_DEFAULT, "/usr/share/fonts/truetype/droid/DroidSans.ttf", 0);

        //r.fontFamily("droid-sans-mono", [ "droid-sans-mono" ]);
        //r.fontFamily("droid-sans",      [ "droid-sans"]);

        r.fontAlias("console", "droid-sans-mono");
        r.fontAlias("default", "droid-sans");
    }
    version (Windows) {
        r.registerFont("your-default-font", FT_DEFAULT, "your-font-file-here");
        r.registerFont("your-default-font", FT_ITALIC, "your-font-file-here");
        r.registerFont("your-default-font", FT_BOLD, "your-font-file-here");
        r.registerFont("your-default-font", FT_BOLD_ITALIC, "your-font-file-here");
        r.fontFallback("your-default-font", "your-font-fallback");

        r.registerFont("your-console-font", FT_DEFAULT, "your-font-file-here");
        r.registerFont("your-console-font", FT_ITALIC, "your-font-file-here");
        r.registerFont("your-console-font", FT_BOLD, "your-font-file-here");
        r.registerFont("your-console-font", FT_BOLD_ITALIC, "your-font-file-here");
        r.fontFallback("your-console-font", "your-font-fallback");

        r.fontAlias("console", "your-console-font");
        r.fontAlias("default", "your-default-font");

        //r.fontFamily("your-default-font", [ "your-default-font" ]);
        //r.fontFamily("your-console-font", [ "your-console-font" ]);
    }


}











