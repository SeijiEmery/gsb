import std.typecons;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.stdio;
import std.math;
import std.exception: enforce;
import std.container.array;

// Advance s up to the first eol or eof (incl end-of-string) character.
// Returns a slice of s from start to the first eol character or comment (#).
string munchToEol (ref string s) {
    size_t i = 0, j = 0;
    while (i < s.length && s[i] != '\n' && s[i] != '\r' && s[i] != '\0') {
        if (s[i] == '#' && j == 0)
            j = i;
        ++i;
    }
    auto slice = j ? s[0..j] : s[0..i];
    s = s[i..$];
    return slice;
}
unittest {
    string s;
    assert(munchToEol(s = " aslfkj \n\r") == " aslfkj " && s == "\n\r");
    assert(munchToEol(s = "asdf# blarg\n\r") == "asdf" && s == "\n\r");
    assert(munchToEol(s = "asdf# blarg\r\n") == "asdf" && s == "\r\n");
    assert(munchToEol(s = "\nblarg") == "" && s == "\nblarg");
    assert(munchToEol(s = "") == "" && s == "");
}

// Return a slice of s to eol / eof; ignores comments (#).
string sliceToEol (string s) {
    size_t i = 0;
    while (i < s.length && s[i] != '\n' && s[i] != '\r' && s[i] != '\0')
        ++i;
    return s[0..i];
}
unittest {
    assert(sliceToEol(" as;lfj\nblarg") == " as;lfj");
    assert(sliceToEol("\nblarg") == "");
    assert(sliceToEol("") == "");
}

bool atEol (string s) { return !s.length || s[0] == '\n' || s[0] == '\r' || s[0] == '\0' || s[0] == '#'; }
unittest {
    assert(!atEol(" \nlaksdjf "));
    assert(atEol("# foo"));
    assert(atEol("\n\r asdf"));
    assert(atEol("\r\n adsf"));
    assert(atEol("\0 foob"));
    assert(atEol(""));
}

bool munchEol (ref string s) {
    if (!s.length) return true;
    if (s[0] == '#') s.munchToEol;
    if (!s.length || s.munch("\r\n\0").length)
        return true;
    return false;
}
unittest {
    string s;
    assert(munchEol(s = "") && s == "");
    assert(!munchEol(s = " \n") && s == " \n");
    assert(munchEol(s = "\n") && s ==    "");
    assert(munchEol(s = "\n\r asdf\n") && s == " asdf\n");
    assert(munchEol(s = "# asdfklj \n\rasdf") && s == "asdf");
    assert(munchEol(s = "# asdf") && s == "");
}
bool munchWs (ref string s) {
    auto l = s.length;
    if (l && (s[0] == ' ' || s[0] == '\t')) {
        do {
            s = s[1..$];
        } while (l --> 1 && (s[0] == ' ' || s[0] == '\t'));
        return true;
    }
    return false;
    //return s.munch(" \t").length != 0; 
}
unittest {
    string s;
    assert(!munchWs(s = "") && s == "");
    assert(munchWs(s = " ") && s == "");
    assert(munchWs(s = " \t") && s == "");
    assert(!munchWs(s = "a 01293") && s == "a 01293");
    assert(!munchWs(s = "\n asdf") && s == "\n asdf");
}

bool eof (string s) {
    return !s.length;
}

uint parseUint ( ref string s ) {
    uint v = 0;
    while (s.length && !(s[0] < '0' || s[0] > '9')) {
        v *= 10;
        v += cast(uint)(s[0] - '0');
        s = s[1..$];
    }
    return v;
}
unittest {
    string s;
    assert(parseUint(s = "123 456") == 123 && s == " 456");
    assert(parseUint(s = "-12 34") == 0 && s == "-12 34");
    assert(parseUint(s = " 12 34") == 0 && s == " 12 34");

    // Should only parse up to what can be parsed, and should return 0 if cannot
    // parse. Detecting errors + predconditions is up to external code (eg. guard w/
    // isNumeric). The last two cases are important for parseIndex! (parseFace)
    assert(parseUint(s = "12.34e9") == 12 && s == ".34e9");
    assert(parseUint(s = "12/4/5")  == 12 && s == "/4/5");
    assert(parseUint(s = "/4/5")    == 0  && s == "/4/5");
}

bool isNumeric (string s) {
    return s.length && (s[0] == '-' || !(s[0] < '0' || s[0] > '9'));
}
unittest {
    assert(!"".isNumeric);
    assert(!"askfl;ajs".isNumeric);
    assert("120938".isNumeric);
    assert("-12093".isNumeric);
    assert(!" 9012".isNumeric);
}

private bool isDec (char c) {
    return !(c < '0' || c > '9');
}
unittest {
    assert('0'.isDec && '9'.isDec && '5'.isDec && !'a'.isDec);
}

private float parseFloat ( ref string s ) {
    string s0 = s;

    bool sign = false;
    if (s[0] == '-' || s[0] == '+') {
        sign = s[0] == '-';
        s = s[1..$];
    }

    long v = 0; long exp = 0;
    while (s.length && s[0].isDec) {
        v *= 10;
        v += cast(long)(s[0] - '0');
        s = s[1..$];
    }
    if (sign) v = -v;

    if (s.length && s[0] == '.') {
        s = s[1..$];
        while (s.length && s[0].isDec) {
            v *= 10;
            v += cast(long)(s[0] - '0');
            --exp;
            s = s[1..$];
        }
    }
    if (s.length && (s[0] == 'e' || s[0] == 'E')) {
        bool e_sign = s[1] == '-' ?
            (s = s[2..$], true) :
            (s = (s[1] == '+' ? s[2..$] : s[1..$]), false);
        long e = 0;
        while (s.length && s[0].isDec) {
            e *= 10;
            e += cast(long)(s[0] - '0');
            s = s[1..$];
        }
        exp += e_sign ? -e : e;
    }
    return cast(float)(cast(real)v * pow(10, cast(real)exp));
}
unittest {
    import core.exception: AssertError;
    import std.exception: enforce;

    immutable float epsilon = 2.6e-3; // up to 0.26% error (converting back via pow() is not always very accurate)
    void assertApproxEq (float a, float b, string file = __FILE__, size_t line = __LINE__) {
        //assert(abs(a - b) < epsilon, format("%s != %s", a, b));
        enforce!AssertError(abs((a - b) / (a + b) * 2) < epsilon, format("%s != %s", a, b), file, line);
        //writefln("%s vs %s: %s / %s = %s", a, b, abs(a - b), abs(a + b) / 2, abs((a - b) / (a + b) * 2));
    }
    string s;
    assertApproxEq(parseFloat(s = "1"), 1 );
    assertApproxEq(parseFloat(s = "-1"), -1 );
    assertApproxEq(parseFloat(s = "-120389012 "), -120389012 );
    assertApproxEq(parseFloat(s = "01923890"), 1923890);
    assertApproxEq(parseFloat(s = "34891809)()"), 34891809);
    assertApproxEq(parseFloat(s = "+213.34210198"), 213.34210198);
    assertApproxEq(parseFloat(s = "-102.012984"), -102.012984);
    assertApproxEq(parseFloat(s = "120.10293e-10"), 120.10293e-10);
    assertApproxEq(parseFloat(s = "110298e13"), 110298e13);
    assertApproxEq(parseFloat(s = "-01928.190284e14"), -1928.190284e14);
    //writefln("all tests passed.");
}

uint parseFloats (ref string s, ref Array!float values) {
    uint n = 0;
    s.munch(" \t");
    while (isNumeric(s)) {
        //values ~= parseFloat(s);
        try { values ~= parse!float(s); }
        catch (Exception e) { writefln("%s", e.msg); return 0; }
        s.munch(" \t");
        ++n;
    }
    return n;
}
unittest {
    import std.algorithm: equal;
    float epsilon = 1e-9;
    bool approxEqual (float a, float b) {
        if (abs(a - b) > epsilon) {
            writefln("%s != %s: %s (%s%%)", a, b, abs(a - b), abs((a - b) / (a + b) * 200));
            return false;
        }
        return true;
    }

    string s; Array!float values;
    assert(parseFloats(s = "2", values) == 1 && s == "" && values[$-1] == 2);
    assert(parseFloats(s = "2.04e-3 asdf", values) == 1 && s == "asdf" && approxEqual(values[$-1], 2.04e-3));
    assert(parseFloats(s = "2 3 4 5", values) == 4 && s == "" && equal!approxEqual(values[$-4..$].array, [ 2f, 3f, 4f, 5f]));
    assert(parseFloats(s = " ;alsdfh", values) == 0 && s == ";alsdfh");
    assert(parseFloats(s = "aslfjsaf", values) == 0 && s == "aslfjsaf");
}


// Combined tests for munchEol, munchToEof, munchWs, and eof.
unittest {
    import std.exception;
    import core.exception;

    auto s1 = "\nfoobarbaz\n\r\n# borg\n  #bazorfoo\n #blarg";
    assertNotThrown!RangeError(assert(s1.munchEol && s1 == "foobarbaz\n\r\n# borg\n  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(!s1.munchEol && s1 == "foobarbaz\n\r\n# borg\n  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(!s1.munchWs  && s1 == "foobarbaz\n\r\n# borg\n  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(s1.munchToEol && s1 == "\n\r\n# borg\n  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(s1.munchEol && s1 == "# borg\n  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(!s1.munchWs && s1 == "# borg\n  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(s1.munchEol && s1 == "  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(!s1.munchEol && s1 == "  #bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(s1.munchWs && s1 == "#bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(!s1.munchWs && s1 == "#bazorfoo\n #blarg"));
    assertNotThrown!RangeError(assert(s1.munchEol && s1 == " #blarg"));
    assertNotThrown!RangeError(assert(!s1.munchEol && s1 == " #blarg"));
    assertNotThrown!RangeError(assert(s1.munchWs && s1 == "#blarg"));
    assertNotThrown!RangeError(assert(!s1.munchWs && s1 == "#blarg"));
    assertNotThrown!RangeError(assert(!s1.eof && s1 == "#blarg"));
    assertNotThrown!RangeError(assert(s1.munchEol && s1 == ""));
    assertNotThrown!RangeError(assert(s1.munchEol && s1 == ""));
    assertNotThrown!RangeError(assert(s1.eof));
}

private bool tryParseInt (ref string s, ref int value) {
    bool sign = false;
    if (s.length && (s[0] == '-' || s[0] == '+')) {
        sign = s[0] == '-';
        s = s[1..$];
    }
    writefln("%s", s);
    if (!s.length || !s[0].isDec)
        return false;

    long v = 0;
    while (s.length && s[0].isDec) {
        v *= 10;
        v += cast(long)(s[0] - '0');
        s = s[1..$];
    }
    writefln("%s, %s", sign, v);
    if (!s.length || s[0] == ' ' || s[0] == '\t' || s[0] == '/') {
        value = sign ? -cast(int)v : cast(int)v;
        return true;
    }
    return false;
}
unittest {
    string s; int value;
    assert(!tryParseInt(s = "", value));
    assert(!tryParseInt(s = " 1234", value) && s == " 1234");
    assert(tryParseInt(s = "-1234 asdf", value) && s == " asdf" && value == -1234);
    assert(tryParseInt(s = "+1234 02193", value) && s == " 02193" && value == 1234);
    assert(!tryParseInt(s = "123.04e6", value) && s == ".04e6");
}



private enum ParseCmd {
    UNKNOWN = 0, COMMENT,
    VERTEX, VERTEX_NORMAL, VERTEX_UV, FACE,
    GROUP, OBJECT, MATERIAL, MATERIAL_LIB
}

/// Parses a line in an obj file. Returns ParseCmd.UNKNOWN if unparseable, or
/// ParseCmd.COMMENT for a comment _or_ empty line (possibly containing a comment).
///
/// Otherwise, returns a corresponding ParseCmd for that line and advances s up to the
/// start of that line, at which point it should be parseable.
private ParseCmd parseLine (ref string s) {
    s.munchWs();
    if (s.length < 2 || s.atEol)  // eol includes '#', '\n', '\r'
        return ParseCmd.COMMENT;

    switch (s[0]) {
        case 'v': switch (s[1]) {
            case ' ': return (s = s[2..$]).munchWs, ParseCmd.VERTEX;
            case 't':
                if (s[2] == ' ') return (s = s[3..$]).munchWs, ParseCmd.VERTEX_UV;
                else break;
            case 'n':
                if (s[2] == ' ') return (s = s[3..$]).munchWs, ParseCmd.VERTEX_NORMAL;
                else break;
            default:
        } break;
        case 'f':
            if (s[1] == ' ') return (s = s[2..$]).munchWs, ParseCmd.FACE;
            else break;
        case 'o':
            if (s[1] == ' ') return (s = s[2..$]).munchWs, ParseCmd.OBJECT;
            else break;
        case 'g':
            if (s[1] == ' ') return (s = s[2..$]).munchWs, ParseCmd.GROUP;
            else break;
        case 'u':
            if (s.length > 7 && s[0..7] == "usemtl ")
                return (s = s[7..$]).munchWs, ParseCmd.MATERIAL;
            break;
        case 'm':
            if (s.length > 7 && s[0..7] == "mtllib ")
                return (s = s[7..$]).munchWs, ParseCmd.MATERIAL_LIB;
            break;
        default:
    }
    return ParseCmd.UNKNOWN;
}
unittest {
    string s;
    assert(parseLine(s = "") == ParseCmd.COMMENT);
    assert(parseLine(s = "\t  #asdf") == ParseCmd.COMMENT);
    assert(parseLine(s = "\t   asdf") == ParseCmd.UNKNOWN);
    assert(parseLine(s = "\t   v asdf") == ParseCmd.VERTEX && s == "asdf");
    assert(parseLine(s = "v foo") == ParseCmd.VERTEX && s == "foo");
    assert(parseLine(s = "vfoo") == ParseCmd.UNKNOWN);

    assert(parseLine(s = "vt foo")   == ParseCmd.VERTEX_UV && s == "foo");
    assert(parseLine(s = "vn \tfoo") == ParseCmd.VERTEX_NORMAL && s == "foo");
    assert(parseLine(s = "o  foo")   == ParseCmd.OBJECT && s == "foo");
    assert(parseLine(s = "g \t bar") == ParseCmd.GROUP && s == "bar");
    assert(parseLine(s = "usemtl b") == ParseCmd.MATERIAL && s == "b");
    assert(parseLine(s = "mtllib bar \n") == ParseCmd.MATERIAL_LIB && s == "bar \n");
}


/// Get a detailed error description for an unparseable line in an .obj file.
/// Line is a slice of the given line where the error occured, from the start 
/// (includes .obj commands like 'vn', 'o', etc) to the end of the line (does 
/// not include newline or comment characters)
string getErrorContext (string line, string err) {
    // TODO: better error descriptions
    return format("Could not parse '%s': %s", line, err);
}

/// Parse an .obj identifier (object / group / material / mtllib).
/// Can return null; should throw a parse exception on error (invalid name like 'blorg;198791ha alsdfbal hiuf').
/// Is passed a string that contains no leading whitespace; should advance string to end of line w/ munchToEol.
string parseIdent (ref string s) {
    return s.munchToEol.strip();
}
unittest {
    // parseIdent should:
    // - be capable of taking null strings, and strings w/out eols
    // - take long strings (not slices) and respect / only slice to eols
    // - strip surrounding whitespaces from names

    string s;
    assert(parseIdent(s = "") == "" && s == "");
    assert(parseIdent(s = "f") == "f" && s == "");
    assert(parseIdent(s = "foo \n foob blah") == "foo" && s == "\n foob blah");
    assert(parseIdent(s = "foo blarg  \r\nblah\n\r") == "foo blarg" && s == "\r\nblah\n\r");
    assert(parseIdent(s = "foo blarg # forb") == "foo blarg" && s == "");
}


// Try parsing vertex after 'v ' (no 'v' or whitespace), storing 3 floats into verts.
// Should return false or throw to indicate an error.
private bool parseVertex (ref string s, ref Array!float verts) {
    auto n = parseFloats( s, verts );

    // Accepts 3 floats _or_ 4, according to spec, but discards the last value (for 4)
    // so we only ever push 3 values onto verts.
    if (n == 3) return true;
    else if (n == 4) return verts.removeBack, true;
    else {
        // If an unexpected number of floats was parsed, returns false to report an error
        // but will _also_ do error recovery (pops off parsed values; pushes on 3 nans),
        // so parse can continue even if there's an error on one line.
        // (not doing this will mess up triangle indices, causing a cascade of misleading
        // error messages. The loader may / may not be configured to support multiple and/or
        // non-critical error messages (the alternative is to just throw, catch, and terminate
        // w/ an exception on error), but it's important that we support this just in case).
        while (n --> 0) verts.removeBack;
        verts ~= [ float.nan, float.nan, float.nan ];
        return false;
    }
}
unittest {
    import std.algorithm: equal;
    import std.math: approxEqual;

    string s; Array!float values;
    assert(!parseVertex(s = "", values));
    assert(!parseVertex(s = "a10.24 2.93 4.4", values));
    assert(parseVertex(s = "10.24 2.93 4.4 \nfoo", values) && s == "\nfoo" && equal!approxEqual(values[$-3..$], [ 10.24, 2.93, 4.4 ]));
    assert(parseVertex(s = "1 2 3 4", values) && s == "" && equal!approxEqual(values[$-3..$], [ 1f, 2f, 3f ]));
    assert(!parseVertex(s = "1 2 3 4 5 6\nfoo", values) && s == "\nfoo");
    assert(!parseVertex(s = "1 2 3 4 5# \r\nfoo", values) && s == "# \r\nfoo");
    assert(!parseVertex(s = "1 2 ", values) && s == "");

    assert(parseVertex(s = "1 2 3 4\n 4 5 6", values) && s == "\n 4 5 6");
    assert(parseVertex(s = "1 2 3 4# foo\n", values) && s == "# foo\n");
    assert(parseVertex(s = "1 2 3 4\t # foo asdf\r", values) && s == "# foo asdf\r");
}

// Parse vertex normal (vn). Accepts a tuple of 3 floats; always pushes 3 onto normals.
private bool parseVertexNormal (ref string s, ref Array!float normals) {

    // Normal should only ever consist of 3 floats.
    auto n = parseFloats( s, normals );
    if (n == 3) return true;
    else {
        while (n --> 0) normals.removeBack;
        normals ~= [ float.nan, float.nan, float.nan ];
        return false;
    }
}
unittest {
    import std.algorithm: equal;
    import std.math: approxEqual;

    string s; Array!float values;
    assert(!parseVertexNormal(s = "1 2", values));
    assert(parseVertexNormal(s = "1 2 3", values) && equal!approxEqual(values[$-3..$], [ 1f, 2f, 3f ]));
    assert(!parseVertexNormal(s = "1 2 3 4", values));
}

// Parse vertex uv / tex coord (vt). Accepts 2-3 floats; always pushes 2 onto uvs.
private bool parseVertexUv (ref string s, ref Array!float uvs) {

    // Uv _may_ consist of 2 floats or 3, according to spec, 
    // but only 2 are supported so we ignore the 3rd.
    auto n = parseFloats( s, uvs );
    if (n == 2) return true;
    else if (n == 3) return uvs.removeBack, true;
    else {
        while (n --> 0) uvs.removeBack;
        uvs ~= [ float.nan, float.nan ];
        return false;
    }
}
unittest {
    import std.algorithm: equal;
    import std.math: approxEqual;

    string s; Array!float values;
    assert(!parseVertexUv(s = "1 ", values));
    assert(parseVertexUv(s = "1 2", values) && equal!approxEqual(values[$-2..$], [ 1f, 2f ]));
    assert(parseVertexUv(s = "4 5 6", values) && equal!approxEqual(values[$-2..$], [ 4f, 5f ]));
    assert(!parseVertexUv(s = "1 2 3 4", values));
}

private bool parseIndex ( ref string s, ref int index, uint max_bound ) {
    if (!s.length || !s.isNumeric) {
        index = 0;
        return false;

    } else {
        if (s[0] == '-') {
            s = s[1..$];
            enforce(s.length && s.isNumeric, "parse error");

            auto v = cast(int)parseUint(s);
            enforce(v != 0, ".obj vertex indices cannot be 0");

            index = max_bound - v + 1;
        } else {
            auto v = index = parseUint(s);
            enforce( v != 0, ".obj vertex indices cannot be 0");
        }
        enforce(index - 1 < max_bound, format("Face index out of bounds: %s > %s",
            index, max_bound));
        return true;
    }
}
unittest {
    string s; int v; uint max_bound = 20;
    bool tryParseIndex ( string line ) {
        v = int.max;
        try { 
            return parseIndex(s = line, v, max_bound); 
        } catch (Exception e) {
            return false; 
        }
    }

    // Basically just an extension of parseUint, but should also check that:
    // - 0 is illegal (.obj indices are 1-based)
    // - minor parse errors ("/" => 0) return 0, false
    // - positive indices are bounded by [1, N]
    // - negative indices are bounded by [-N, -1] and mapped to [1, N]
    assert(!tryParseIndex("") && v == 0);
    assert(!tryParseIndex("0"));
    assert(!tryParseIndex("-0"));
    assert(!tryParseIndex("asdf0") && v == 0);
    assert(!tryParseIndex("/12/")  && v == 0);
    assert(tryParseIndex("1")  && v == 1);
    assert(tryParseIndex("20") && v == 20);
    assert(!tryParseIndex("21"));
    assert(tryParseIndex("-1")  && v == 20);
    assert(tryParseIndex("-20") && v == 1);
}

private bool parseFace (ref string s, MeshPart* mesh, const ref ObjParserContext parser) {
    int[12] indices = 0;
    int vcount = 0, tcount = 0, ncount = 0;

    auto vertexCount = cast(int)parser.vertexData.length / 3;
    auto normalCount = cast(int)parser.normalData.length / 3;
    auto uvCount     = cast(int)parser.uvData.length / 2;

    
    s.munchWs();
    while (!s.atEol) {
        enforce(s.isNumeric, format("Expected face index, not '%s'", s.sliceToEol));
        if (vcount > 4 || !parseIndex(s, indices[vcount * 3], vertexCount))
            return false;

        if (s.length && s[0] == '/') {
            s = s[1..$];
            if (s.isNumeric && parseIndex(s, indices[vcount * 3 + 1], cast(uint)uvCount )) {
                enforce(tcount++ == vcount, format("Unmatched indices: %s verts != %s uvs", vcount, tcount));
            }
            if (s.length && s[0] == '/') {
                s = s[1..$];
                if (s.isNumeric && parseIndex( s, indices[vcount * 3 + 2], cast(uint)normalCount)) {
                    enforce(ncount++ == vcount, format("Unmatched indices: %s verts != %s normals", vcount, ncount));
                }
            }
        }
        ++vcount;
        s.munchWs();
    }
    enforce(vcount >= 3, format("Not enough indices for face (%s)", vcount));
    switch (vcount) {
        case 3:
            mesh.tris ~= indices[0..9];
            //writefln("tri %s '%s'", indices, lineStart.sliceToEol);
            break;
        case 4:
            mesh.quads ~= indices[0..12];
            //writefln("quad %s '%s'", indices, lineStart.sliceToEol);
            break;
        default: assert(0, format("%s!", vcount));
    }
    return true;
}
unittest {
    import std.algorithm: equal;
    import std.math: approxEqual;

    ObjParserContext parser;
    auto mesh = parser.currentMesh;
    assert(mesh !is null);
    auto quadLength = mesh.quads.length, triLength = mesh.tris.length;
    bool pushedQuad = false, pushedTri = false;

    // try/catch wrapper for parseFace since it can signal errors by returning false or
    // throwing exceptions; we'll convert both of these to 'return false' for unit testing purposes.
    bool tryParseFace (ref string s) {
        auto s0 = s;
        bool ok = true;
        try {
            ok = parseFace(s, mesh, parser);
        } catch (Exception e) {
            //writefln("Failed: %s '%s'", e.msg, s0.sliceToEol);
            ok = false;
        }
        pushedQuad = quadLength != mesh.quads.length; quadLength = mesh.quads.length;
        pushedTri  = triLength  != mesh.tris.length; triLength = mesh.tris.length;
        return ok;
    }

    // "add" verts, uvs, and normals so bounds checks don't kick in!
    for (auto i = 12; i --> 0; ) {
        parser.vertexData.insertBack([ 0, 0, 0 ]);
        parser.normalData.insertBack([ 0, 0, 0 ]);
        parser.uvData.insertBack([ 0, 0 ]);
    }

    string s;
    assert(!tryParseFace(s = "") && !pushedTri && !pushedQuad);
    assert(!tryParseFace(s = "a12 3 4\n") && s == "a12 3 4\n" && !pushedTri && !pushedQuad);
    assert(tryParseFace(s = "12 3 4#foo \n") && s == "#foo \n" && pushedTri && !pushedQuad);
    assert(tryParseFace(s = "12 3 4  # foo \n") && s == "# foo \n" && pushedTri &&
        equal!approxEqual(mesh.tris[$-9..$], [ 12, 0, 0, 3, 0, 0, 4, 0, 0 ]));
    assert(tryParseFace(s = "12 3 4 5  \t \n") && s == "\n" && pushedQuad &&
        equal!approxEqual(mesh.quads[$-12..$], [ 12, 0, 0, 3, 0, 0, 4, 0, 0, 5, 0, 0 ]));

    assert(tryParseFace(s = "1// 2// 3// 4//") && pushedQuad &&
        equal!approxEqual(mesh.quads[$-12..$], [ 1, 0, 0, 2, 0, 0, 3, 0, 0, 4, 0, 0 ]));
    assert(tryParseFace(s = "1/2/ 3/4 \t5/5/ 8/8") && pushedQuad &&
        equal!approxEqual(mesh.quads[$-12..$], [ 1, 2, 0, 3, 4, 0, 5, 5, 0, 8, 8, 0 ]));
    assert(tryParseFace(s = "1//2 3//4 5//2") && pushedTri &&
        equal!approxEqual(mesh.tris[$-9..$], [ 1, 0, 2, 3, 0, 4, 5, 0, 2 ]));
    assert(tryParseFace(s = "1/2/3 4/5/6 7/8/9") && pushedTri &&
        equal!approxEqual(mesh.tris[$-9..$], [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]));

    // Test bounds checking + negative indices
    assert(tryParseFace(s = "12 9 1") && pushedTri && !pushedQuad);
    assert(!tryParseFace(s = "13 9 1") && !pushedTri && !pushedQuad);  // out of bounds (0-12 vert indices)
    assert(!tryParseFace(s = "0 9 1")  && !pushedTri && !pushedQuad);  // .obj indices are 1-based; '0' is invalid
    assert(!tryParseFace(s = "-0 9 1") && !pushedTri && !pushedQuad);  // ditto (should get interpreted as -0 = 0)
    assert(tryParseFace(s = "-12 9 1") && pushedTri && mesh.tris[$-9..$] == [ 1, 0, 0, 9, 0, 0, 1, 0, 0 ],
        format("%s", mesh.tris[$-9..$]));
    assert(tryParseFace(s = "-1 9 1")  && pushedTri && mesh.tris[$-9..$] == [ 12, 0, 0, 9, 0, 0, 1, 0, 0 ]);
    assert(!tryParseFace(s = "-13 9 1") && !pushedTri && !pushedQuad); // out of bounds
}


private struct MeshPart {
    string object = null;
    string group  = null;
    string mtl    = null;

    // Tris / quads intermed indices.
    // Note: these are wierd, b/c the .obj format is wierd and lets you specify
    // separate vertex / uv / normal indices, and since we have to process in two
    // stages (to detect missing normals or generate them ourselves), we have to
    // store a _lot_ of extra data (memory consumption for this is probably horrible)
    //   tris:  v0, t0, n0, v1, t1, n1, v2, t2, n2  for each triangle
    //   quads: v0, t0, n0, v1, t1, n1, v2, t2, n2, v3, t3, n3 for each quad
    // 
    // Each value is a bounds-checked positive integer (ignore the sign) into
    // the vertexData / normalData / uvData array, _except_:
    //    t0 == -1  =>  has no uvs
    //    n0 == -1  =>  has no normals
    //
    // See parseTriangle / processTriangles for the implementation.
    //
    int[] tris;
    int[] quads;
}

struct ObjParserContext {
    uint                  lineNum = 0;
    Array!(Tuple!(uint,string)) lineErrors;

    Array!float vertexData, normalData, uvData;
    MeshPart[] parts;
    string currentObject = null, currentGroup = null, currentMtl = null;
    private MeshPart* _currentMesh = null;
    string[] mtlLibs;

    @property auto currentMesh () {
        if (!_currentMesh)
            selectMesh(currentObject, currentGroup, currentMtl);
        return _currentMesh;
    }
    @property auto vertexCount () { return vertexData.length / 3; }
    @property auto normalCount () { return normalData.length / 3; }
    @property auto uvCount     () { return uvData.length / 3; }

    void reportError (string err) {
        lineErrors.insertBack(tuple(lineNum, err));
        //lineErrors ~= tuple(lineNum, err);
    }
    void selectMesh (string object, string group, string material) {
        currentObject = object;
        currentGroup  = group;
        currentMtl    = material;

        foreach (ref mesh; parts) {
            if (mesh.object == object && mesh.group == group && mesh.mtl == material) {
                _currentMesh = &mesh;
                return;
            }
        }
        parts ~= MeshPart( object, group, material );
        _currentMesh = &parts[$-1];
    }
    void materialLib ( string libName ) {
        foreach (lib; mtlLibs)
            if (lib == libName)
                return;
        mtlLibs ~= libName;
    }
    void reset () {
        parts.length = 0;
        selectMesh(currentObject = null, currentGroup = null, currentMtl = null);
        vertexData.length = 0;
        normalData.length = 0;
        uvData.length = 0;
        lineNum = 0;
        lineErrors.length = 0;
        mtlLibs.length = 0;
    }
}
unittest {
    // Test init state + mesh selection (should reselect existing meshes, etc)
    // Trivial, but worth testing in case the impl changes.

    ObjParserContext parser;
    assert( parser.currentMesh !is null && parser.parts.length == 1 && 
        parser.currentMesh.group is null && parser.currentMesh.object is null && parser.currentMesh.mtl is null );
    auto prevMesh = parser.currentMesh;

    parser.selectMesh(null, null, null);
    assert( parser.currentMesh == prevMesh && parser.parts.length == 1 );

    parser.selectMesh("foo", null, null);
    assert( parser.currentMesh != prevMesh && parser.parts.length == 2 &&
        parser.currentMesh.object == parser.currentObject && parser.currentObject == "foo");

    parser.selectMesh("foo", "blarg", null);
    parser.selectMesh("foo", null, null);
    assert( parser.parts.length == 3 );
}

// Calculate cross product + add to r.
private void cp_add (const(float)* a, const(float)* b, const(float)* c, float* r) {
    auto x0 = a[0] - c[0], x1 = b[0] - c[0];
    auto y0 = a[1] - c[1], y1 = b[1] - c[1];
    auto z0 = a[2] - c[2], z1 = b[2] - c[2];

    r[0] += y0 * z1 - z0 * y1;
    r[1] += z0 * x1 - x0 * z1;
    r[2] += x0 * y1 - y0 * x1;
}
unittest {
    float[4] a = [ 5, 2, 1, 1 ], b = [ 4, 3, 1, 1 ], c = [ 4, 2, 1, 1 ], r = 0;
    cp_add(&a[0], &b[0], &c[0], &r[0]);
    assert(r == [ 0, 0, 1, 0 ], format("%s", r));
}

//private auto shuffle_yzx (Args...)(Args args) {
//    //                           x->z    y->x     z->y      w->w
//    return __simd(SHUFPS, args, (2<<0) | (0<<2) | (1<<4) | (3<<6));
//}
//private auto shuffle_zxy (Args...)(Args args) {
//    return __simd(SHUFPS, args, (1<<0) | (2<<2) | (0<<4) | (3<<6));
//}

//private void cp_add2 (float* a, float* b, float* c, float* r) {
//    //float[4] a_yzx = [ a[1], a[2], a[0], 0 ], a_zxy = [ a[2], a[0], a[1], 0 ];
//    //float[4] b_yzx = [ b[1], b[2], b[0], 0 ], b_zxy = [ b[2], b[0], b[1], 0 ];
//    //float[4] c_yzx = [ c[1], c[2], c[0], 0 ], c_zxy = [ c[2], c[0], c[1], 0 ];
//    import core.simd;

//    auto a_yzx = shuffle_yzx(float4(a[0..4])), a_zxy = shuffle_zxy(cast(float4)a[0..4]);
//    auto b_yzx = shuffle_yzx(cast(float4)b[0..4]), b_zxy = shuffle_zxy(cast(float4)b[0..4]);
//    auto c_yzx = shuffle_yzx(cast(float4)c[0..4]), c_zxy = shuffle_zxy(cast(float4)c[0..4]);

//    a_yzx -= c_yzx; b_zxy -= c_zxy;
//    a_yzx *= b_zxy;

//    a_zxy -= c_zxy; b_yzx -= c_yzx;
//    a_zxy *= b_yzx;

//    a_yzx -= a_zxy;
//    r[0..3] += a_yzx[0..3];
//}
//unittest {
//    float[4] a = [ 5, 2, 1, 1 ], b = [ 4, 3, 1, 1 ], c = [ 4, 2, 1, 1 ], r = 0;
//    cp_add2(&a[0], &b[0], &c[0], &r[0]);
//    assert(r == [ 0, 0, 1, 0 ], format("%s", r));
//}


private void genSmoothNormals (ref ObjParserContext parser, bool forceGenNormals) {
    if (!parser.normalCount || forceGenNormals) {
        parser.normalData.clear();
        parser.normalData.reserve(parser.vertexData.length);

        // Clear + fill normals from 0 .. vertex length w/ vec4(0)
        foreach (i; 0 .. parser.vertexData.length) {
            parser.normalData ~= 0f;
        }
        // For each triangle + quad, add surface normal to vertex normal (cross product)
        foreach (mesh; parser.parts) {
            assert(mesh.tris.length % 9 == 0, format("%s, %s", mesh.tris.length, mesh.tris.length % 9));
            for (auto i = mesh.tris.length; i > 0; i -= 9) {
                // Get triangle indices + set normal indices to match vert indices
                auto a = mesh.tris[i-2] = mesh.tris[i-3];
                auto b = mesh.tris[i-5] = mesh.tris[i-6];
                auto c = mesh.tris[i-8] = mesh.tris[i-9];

                float[3] r = 0;
                cp_add(&parser.vertexData[a], &parser.vertexData[b], &parser.vertexData[c], &r[0]);

                parser.normalData[a+0] += r[0]; parser.normalData[a+1] += r[1]; parser.normalData[a+2] += r[2];
                parser.normalData[b+0] += r[0]; parser.normalData[b+1] += r[1]; parser.normalData[b+2] += r[2];
                parser.normalData[c+0] += r[0]; parser.normalData[c+1] += r[1]; parser.normalData[c+2] += r[2];
            }
            assert(mesh.quads.length % 12 == 0, format("%s, %s", mesh.quads.length, mesh.quads.length % 12));
            for (auto i = mesh.quads.length; i > 0; i -= 12) {
                int[4] v = [
                    mesh.quads[i-2]  = mesh.quads[i-3],
                    mesh.quads[i-5]  = mesh.quads[i-6],
                    mesh.quads[i-8]  = mesh.quads[i-9],
                    mesh.quads[i-11] = mesh.quads[i-12],
                ];

                // Calculate avg normal at all verts in case quad is not coplanar
                float[3] normal = 0;
                for (auto j = 0; j < 4; ++j) {
                    auto k = (j+1) % 4; auto l = (j+2) % 4;
                    cp_add(&parser.vertexData[v[j]], &parser.vertexData[v[k]], &parser.vertexData[v[l]], &normal[0]);
                }
                // normalize
                auto m_inv = 1.0 / sqrt( normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2] );
                normal[0] *= m_inv;
                normal[1] *= m_inv;
                normal[2] *= m_inv;

                // Add to vertex normals
                for (auto j = 0; j < 4; ++j) {
                    parser.normalData[v[j]+0] += normal[0];
                    parser.normalData[v[j]+1] += normal[1];
                    parser.normalData[v[j]+2] += normal[2];
                }
            }
        }

        // Average normals by re-normalizing
        for (auto i = parser.normalData.length; i > 0; i -= 3) {
            auto x = parser.normalData[i-3], y = parser.normalData[i-2], z = parser.normalData[i-1];
            auto m_inv = 1.0 / sqrt(x * x + y * y + z * z);

            parser.normalData[i-3] *= m_inv;
            parser.normalData[i-2] *= m_inv;
            parser.normalData[i-1] *= m_inv;
        }
    }
}
unittest {

}

private void parseLines (ref string s, ref ObjParserContext parser) {
    bool parseLine () {
        final switch (s.parseLine) {
            case ParseCmd.UNKNOWN:       return false;
            case ParseCmd.COMMENT:       return s.munchToEol, true;
            case ParseCmd.VERTEX:        return s.parseVertex( parser.vertexData );
            case ParseCmd.VERTEX_NORMAL: return s.parseVertexNormal( parser.normalData );
            case ParseCmd.VERTEX_UV:     return s.parseVertexUv( parser.uvData );
            case ParseCmd.FACE:          return s.parseFace( parser.currentMesh, parser );
            case ParseCmd.OBJECT:        return parser.selectMesh( s.parseIdent, parser.currentGroup, parser.currentMtl ), true;
            case ParseCmd.GROUP:         return parser.selectMesh( parser.currentObject, s.parseIdent, parser.currentMtl ), true;
            case ParseCmd.MATERIAL:      return parser.selectMesh( parser.currentObject, parser.currentGroup, s.parseIdent ), true;
            case ParseCmd.MATERIAL_LIB:  return parser.materialLib( s.parseIdent ), true;
        }    
    }
    while (s.length) {
        string s0 = s;
        try {
            if (!parseLine()) {
                parser.reportError(getErrorContext(s0.sliceToEol, "error parsing"));
                s.munchToEol();
            }
        } catch (Exception e) {
            parser.reportError(getErrorContext(s0.sliceToEol, e.msg));
            s.munchToEol();
        }
        if (!s.atEol) {
            parser.reportError(format("Unused character(s): '%s'", s.sliceToEol));
            s.munchToEol();
        }
        s.munchEol();
        ++parser.lineNum;
    }
}

void fast_parse_obj (string file) {
    ObjParserContext parser;
    parseLines(file, parser);
    
    if (parser.lineErrors.length) {
        writefln("%s error(s):", parser.lineErrors.length);
        foreach (err; parser.lineErrors) {
            writefln("\tERROR (line %s): %s", err[0], err[1]);
        }
    } else {
        writefln("%s verts, %s uvs, %s normals", parser.vertexCount, parser.uvCount, parser.normalCount);
        assert(parser.vertexData.length % 3 == 0 && parser.uvData.length % 2 == 0 && parser.normalData.length % 3 == 0,
            format("internal error: uneven vertex / uv / normal counts: %s, %s, %s", 
                parser.vertexData.length, parser.uvData.length, parser.normalData.length));
        
        writefln("mtl lib(s): %s", parser.mtlLibs.join(", "));
        writefln("%s mesh parts:", parser.parts.length);
        foreach (ref mesh; parser.parts) {
            if (mesh.tris.length || mesh.quads.length)
                writefln("\tobject '%s'.'%s' material '%s':\n\t\t %s tri(s) %s quad(s)",
                    mesh.object ? mesh.object : "<none>",
                    mesh.group  ? mesh.group : "<none>",
                    mesh.mtl ? mesh.mtl : "<none>",
                    mesh.tris.length / 9,
                    mesh.quads.length / 12
                );
        }
        writefln("");
    }
}

struct ObjBenchmarkInfo {
    string fcn;
    double totalTime = 0;
    uint runCount = 0;
    double perCallTime = 0;   // total time / run count
}
private string fmtSecs (double seconds) {
    if (seconds >= 1.0)  return format("%s secs", seconds);
    if (seconds >= 1e-3) return format("%s ms", seconds * 1e3);
    if (seconds >= 1e-6) return format("%s µs", seconds * 1e6);
    return format("%s ns", seconds * 1e9);
}

private void runBenchmark (string name, void delegate() bench)(uint workCount, uint reqWorkCount) {
    import std.datetime;

    uint iterations = reqWorkCount / workCount + (reqWorkCount % workCount ? 1 : 0);
    StopWatch sw; sw.start();
    for (auto i = iterations; i --> 0; ) {
        bench();
    }
    auto time = cast(double)sw.peek.usecs * 1e-6;

    writefln("%s:\n\ttotal time: %s\n\tper iteration: %s (%s iterations)\n\tper call: %s (%s calls)",
        name, time.fmtSecs, 
        (time / cast(double)iterations).fmtSecs, iterations,
        (time / cast(double)(iterations * workCount)).fmtSecs, iterations * workCount);
}

void benchmarkObjLoad (string fileName, string file, uint min_line_count = 1000_000) {
    // Do a pre-pass to mark lines so we can benchmark individual parser functions
    Array!string[ParseCmd.max+1] lines;
    auto s = file;
    uint totalLineCount = 0;
    while (s.length) {
        string s0 = s;
        try {
            auto cmd = s.parseLine;
            if (cmd != ParseCmd.UNKNOWN && cmd != ParseCmd.COMMENT)
                lines[cmd] ~= s.munchToEol;
        } catch (Exception e) {}
        if (!s.atEol)
            s.munchToEol;
        s.munchEol;
        ++totalLineCount;
    }
    ObjBenchmarkInfo[] benchResults;
    ObjParserContext parser;

    writefln("Benchmarking %s (%s, %s lines)", fileName, file.length.fmtBytes, totalLineCount);
    {
        runBenchmark!("parseLines", {
            parseLines(s = file, parser);
            parser.reset();
        })(cast(uint)totalLineCount, min_line_count);
    }

    void benchVertexFcn (string fcn, ParseCmd cmd)(ref Array!float values) {
        if (lines[cmd].length) {
            runBenchmark!(fcn, {
                values.length = 0;
                foreach (line; lines[cmd]) {
                    mixin(fcn~"(line, values);");
                }
            })(cast(uint)lines[cmd].length, min_line_count);
        }
    }
    benchVertexFcn!("parseVertex", ParseCmd.VERTEX)(parser.vertexData);
    benchVertexFcn!("parseVertexNormal", ParseCmd.VERTEX_NORMAL)(parser.normalData);
    benchVertexFcn!("parseVertexUv", ParseCmd.VERTEX_UV)(parser.uvData);

    {
        runBenchmark!("parseFace", {
            auto mesh = parser.currentMesh;
            foreach (line; lines[ParseCmd.FACE])
                parseFace(line, mesh, parser);
            //parser.resetFaces();
        })(cast(uint)lines[ParseCmd.FACE].length, min_line_count);
    }
}

string fmtBytes (double bytes) {
    if (bytes < 1e3) return format("%s bytes", bytes);
    if (bytes < 1e6) return format("%s kb", bytes * 1e-3);
    if (bytes < 1e9) return format("%s mb", bytes * 1e-6);
    return format("%s gb", bytes * 1e-9);
}

void main (string[]) {
    import std.path;
    import std.file;
    import std.datetime;
    import std.conv;

    void runBenchmarks () {
        string flt = "-109809947.1238098e-19";
        StopWatch sw;

        sw.start();
        float[] std_results;
        for (auto i = 1_000_000; i --> 0; ) {
            auto s = flt;
            std_results ~= parse!float(s);
        }
        auto std_parseFlt = sw.peek();

        sw.reset();
        float[] custom_results;
        for (auto i = 1_000_000; i --> 0; ) {
            auto s = flt;
            custom_results ~= parseFloat(s);
        }
        auto custom_parseFlt = sw.peek();
        sw.stop(); sw.reset();

        foreach (i, r; custom_results) {
            if (r != std_results[i]) {
                writefln("%s != %s!", r, std_results[i]);
                break;
            }
        }

        writefln("parse!float 1m: %s", cast(double)std_parseFlt.usecs * 1e-6);
        writefln("parseFloat  1m: %s", cast(double)custom_parseFlt.usecs * 1e-6);
    }

    string readFile (string path) {
        import std.file;
        import std.zip;
        if (path.endsWith(".zip")) {
            auto archive = new ZipArchive(read(path));
            auto file = path[0..$-4].baseName;
            assert(file.endsWith(".obj"), file);
            assert(file in archive.directory, file);
            return cast(string)archive.expand(archive.directory[file]);
        }
        return readText(path);
    }

    void testObjLoad () {
        Tuple!(string, double, TickDuration, TickDuration)[] loadTimes;
        
        void testObj (string path) {
            if (!path.exists)
                writefln("Could not open '%s'!", path);
            else {
                StopWatch sw; sw.start();
                auto contents = readFile(path);
                auto fileReadTime = sw.peek;

                writefln("Loading %s", path.baseName);
                fast_parse_obj(contents);
                auto objLoadTime = sw.peek - fileReadTime;

                loadTimes ~= tuple(path.baseName, cast(double)contents.length, fileReadTime, objLoadTime);
            }
        }
        StopWatch sw; sw.start();
        testObj("/Users/semery/misc-projects/GLSandbox/assets/cube/cube.obj");
        testObj("/Users/semery/misc-projects/GLSandbox/assets/teapot/teapot.obj");
        testObj("/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj");
        testObj("/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj.zip");
        testObj("/Users/semery/misc-projects/GLSandbox/assets/sibenik/sibenik.obj");

        writefln("Loaded %s models in %s:", loadTimes.length, sw.peek.msecs * 1e-3);
        foreach (kv; loadTimes) {
            writefln("'%s' %s | read %s ms | load %s ms | %s / sec", 
                kv[0], kv[1].fmtBytes, kv[2].msecs, kv[3].msecs, (kv[1] / (kv[3].msecs * 1e-3)).fmtBytes);
        }    
    }
    void benchObjLoad () {
        void benchFile (string path) {
            benchmarkObjLoad(path.baseName, readFile(path));
        }
        benchFile("/Users/semery/misc-projects/GLSandbox/assets/teapot/teapot.obj");
        benchFile("/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj");
        benchFile("/Users/semery/misc-projects/GLSandbox/assets/sibenik/sibenik.obj");
    }

    benchObjLoad();
    testObjLoad();
    runBenchmarks();
}

