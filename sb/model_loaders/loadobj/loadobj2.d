import std.typecons;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.stdio;
import std.math;
import std.exception: enforce;

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

uint parseFloats (ref string s, ref float[] values) {
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
    float epsilon = 1e-9;
    bool approxEqual (float a, float b) {
        if (abs(a - b) > epsilon) {
            writefln("%s != %s: %s (%s%%)", a, b, abs(a - b), abs((a - b) / (a + b) * 200));
            return false;
        }
        return true;
    }

    string s; float[] values;
    assert(parseFloats(s = "2", values) == 1 && s == "" && values[$-1] == 2);
    assert(parseFloats(s = "2.04e-3 asdf", values) == 1 && s == "asdf" && approxEqual(values[$-1], 2.04e-3));
    assert(parseFloats(s = "2 3 4 5", values) == 4 && s == "" && values[$-4..$] == [ 2f, 3f, 4f, 5f]);
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
    assertNotThrown!RangeError(assert(s1.munchToEol == "\n\r\n# borg\n  #bazorfoo\n #blarg"));
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

private bool nonIntChar (string s) {
    return !s.length || ((s[0] < '0' || s[0] > '9') && s[0] != '-');
}
unittest {
    assert("asdf".nonIntChar);
    assert(!"-10".nonIntChar);
    assert(!"99".nonIntChar);
    assert(".22".nonIntChar);
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
            if (s.length < 7 && s[0..7] == "mtllib ")
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
private bool parseVertex (ref string s, ref float[] verts) {
    auto n = parseFloats( s, verts );

    // Accepts 3 floats _or_ 4, according to spec, but discards the last value (for 4)
    // so we only ever push 3 values onto verts.
    if (n == 3) return true;
    if (n == 4) return --verts.length, true;
    else {
        // If an unexpected number of floats was parsed, returns false to report an error
        // but will _also_ do error recovery (pops off parsed values; pushes on 3 nans),
        // so parse can continue even if there's an error on one line.
        // (not doing this will mess up triangle indices, causing a cascade of misleading
        // error messages. The loader may / may not be configured to support multiple and/or
        // non-critical error messages (the alternative is to just throw, catch, and terminate
        // w/ an exception on error), but it's important that we support this just in case).
        if (n) verts.length -= n;
        verts ~= [ float.nan, float.nan, float.nan ];
        return false;
    }
}
unittest {
    string s; float[] values;
    assert(!parseVertex(s = "", values));
    assert(!parseVertex(s = " 10.24 2.93 4.4", values));
    assert(parseVertex(s = "10.24 2.93 4.4 \nfoo", values) && s == "\nfoo" && values[$-3..$] == [ 10.24, 2.93, 4.4 ]);
    assert(parseVertex(s = "1 2 3 4", values) && s == "" && values[$-3..$] == [ 1f, 2f, 3f ]);
    assert(!parseVertex(s = "1 2 3 4 5 6\nfoo", values) && s == "\nfoo");
    assert(!parseVertex(s = "1 2 3 4 5# \r\nfoo", values) && s == "# \r\nfoo");
    assert(!parseVertex(s = "1 2 ", values) && s == "");

    assert(parseVertex(s = "1 2 3 4\n 4 5 6", values) && s == "\n 4 5 6");
    assert(parseVertex(s = "1 2 3 4# foo\n", values) && s == "# foo\n");
    assert(parseVertex(s = "1 2 3 4\t # foo asdf\r", values) && s == "# foo asdf\r");
}

// Parse vertex normal (vn). Accepts a tuple of 3 floats; always pushes 3 onto normals.
private bool parseVertexNormal (ref string s, ref float[] normals) {

    // Normal should only ever consist of 3 floats.
    auto n = parseFloats( s, normals );
    if (n == 3) return true;
    else {
        if (n) normals.length -= n;
        normals ~= [ float.nan, float.nan, float.nan ];
        return false;
    }
}
unittest {
    string s; float[] values;
    assert(!parseVertexNormal(s = "1 2", values));
    assert(parseVertexNormal(s = "1 2 3", values) && values[$-3..$] == [ 1f, 2f, 3f ]);
    assert(!parseVertexNormal(s = "1 2 3 4", values));
}

// Parse vertex uv / tex coord (vt). Accepts 2-3 floats; always pushes 2 onto uvs.
private bool parseVertexUv (ref string s, ref float[] uvs) {

    // Uv _may_ consist of 2 floats or 3, according to spec, 
    // but only 2 are supported so we ignore the 3rd.
    auto n = parseFloats( s, uvs );
    if (n == 2) return true;
    else if (n == 3) return --uvs.length, true;
    else {
        if (n) uvs.length -= n;
        uvs ~= [ float.nan, float.nan ];
        return false;
    }
}
unittest {
    string s; float[] values;
    assert(!parseVertexUv(s = "1 ", values));
    assert(parseVertexUv(s = "1 2", values) && values[$-2..$] == [ 1f, 2f ]);
    assert(parseVertexUv(s = "4 5 6", values) && values[$-2..$] == [ 4f, 5f, 6f ]);
    assert(!parseVertexUv(s = "1 2 3 4", values));
}



bool parseFace (ref string s, MeshPart* mesh, const ref ObjParserContext parser) {
    int[15] indices = 0;
    int vcount = 0, tcount = 0, ncount = 0;

    auto vertexCount = cast(int)parser.vertexData.length / 3;
    auto normalCount = cast(int)parser.normalData.length / 3;
    auto uvCount     = cast(int)parser.uvData.length / 2;

    bool parseIndex ( ref string s, uint i, uint max_bound ) {
        auto index = s[0] == '-' ?
            max_bound - parseUint( s = s[1..$] ) + 1 :
            parseUint( s );

        enforce(index - 1 < max_bound, format("Face index out of bounds: %s > %s",
            index, max_bound));

        indices[i] = index;
        return true;
    }
    s.munchWs();
    while (!s.atEol) {
        enforce(s[0] == '-' || s[0].isDec, format("Expected face index, not '%s'", s.sliceToEol));

        if (++vcount > 4 || !parseIndex(s, vcount * 3, vertexCount))
            return false;

        if (s[0] == '/') {
            s = s[1..$];
            if (s[0] != '/' && parseIndex(s, vcount * 3 + 1, cast(uint)uvCount )) {
                enforce(++tcount == vcount, format("Unmatched indices: %s verts != %s uvs", vcount, tcount));
            }
            if (s[0] == '/') {
                s = s[1..$];
                if (parseIndex( s, vcount * 3 + 2, cast(uint)normalCount)) {
                    enforce(++ncount == vcount, format("Unmatched indices: %s verts != %s normals", vcount, ncount));
                }
            }
        }
        s.munchWs();
    }
    enforce(vcount >= 3, format("Not enough indices for face: %s", vcount));
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
    ObjParserContext parser;
    auto mesh = parser.currentMesh;
    assert(mesh !is null);
    auto quadLength = mesh.quads.length, triLength = mesh.tris.length;
    bool pushedQuad = false, pushedTri = false;

    // try/catch wrapper for parseFace since it can signal errors by returning false or
    // throwing exceptions; we'll convert both of these to 'return false' for unit testing purposes.
    bool tryParseFace (ref string s) {
        bool ok = true;
        try {
            ok = parseFace(s, mesh, parser);
        } catch (Exception) {
            ok = false;
        }
        pushedQuad = quadLength != mesh.quads.length; quadLength = mesh.quads.length;
        pushedTri  = triLength  != mesh.tris.length; triLength = mesh.tris.length;
        return ok;
    }

    // "add" verts, uvs, and normals so bounds checks don't kick in!
    parser.vertexData.length += 3 * 12;
    parser.normalData.length += 3 * 12;
    parser.uvData.length     += 2 * 12;

    string s;
    assert(!tryParseFace(s = "") && !pushedTri && !pushedQuad);
    assert(!tryParseFace(s = " 12 3 4\n") && s == " 12 3 4\n" && !pushedTri && !pushedQuad);
    assert(tryParseFace(s = "12 3 4#foo \n") && s == "# foo \n" && pushedTri && !pushedQuad);
    assert(tryParseFace(s = "12 3 4  # foo \n") && s == "# foo \n" && pushedTri &&
        mesh.tris[$-9..$] == [ 12, 0, 0, 3, 0, 0, 4, 0, 0 ]);
    assert(tryParseFace(s = "12 3 4 5  \t \n") && s == "\n" && pushedQuad &&
        mesh.quads[$-12..$] == [ 12, 0, 0, 3, 0, 0, 4, 0, 0, 5, 0, 0 ]);

    assert(tryParseFace(s = "1// 2// 3// 4//") && pushedQuad &&
        mesh.quads[$-12..$] == [ 1, 0, 0, 2, 0, 0, 3, 0, 0, 4, 0, 0 ]);
    assert(tryParseFace(s = "1/2/ 3/4 \t5/5/ 8/8") && pushedQuad &&
        mesh.quads[$-12..$] == [ 1, 2, 0, 3, 4, 0, 5, 5, 0, 8, 8, 0 ]);
    assert(tryParseFace(s = "1//2 3//4 5//2") && pushedTri &&
        mesh.tris[$-9..$] == [ 1, 0, 2, 3, 0, 4, 5, 0, 2 ]);
    assert(tryParseFace(s = "1/2/3 4/5/6 7/8/9") && pushedTri &&
        mesh.tris[$-9..$] == [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]);

    // Test bounds checking + negative indices
    assert(tryParseFace(s = "12 9 1") && pushedTri && !pushedQuad);
    assert(!tryParseFace(s = "13 9 1") && !pushedTri && !pushedQuad);  // out of bounds (0-12 vert indices)
    assert(!tryParseFace(s = "0 9 1")  && !pushedTri && !pushedQuad);  // .obj indices are 1-based; '0' is invalid
    assert(!tryParseFace(s = "-0 9 1") && !pushedTri && !pushedQuad);  // ditto (should get interpreted as -0 = 0)
    assert(tryParseFace(s = "-12 9 1") && pushedTri && mesh.tris[$-9..$] == [ 1, 0, 0, 9, 0, 0, 1, 0, 0 ]);
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
    Tuple!(uint,string)[] lineErrors;

    float[] vertexData, normalData, uvData;
    MeshPart[] parts;
    string currentObject = null, currentGroup = null, currentMtl = null;
    MeshPart* currentMesh = null;
    string[] mtlLibs;

    this (this) { selectMesh(currentObject, currentGroup, currentMtl); }

    void reportError (string err) {
        lineErrors ~= tuple(lineNum, err);
    }
    void selectMesh (string object, string group, string material) {
        currentObject = object;
        currentGroup  = group;
        currentMtl    = material;

        foreach (ref mesh; parts) {
            if (mesh.object == object && mesh.group == group && mesh.mtl == material) {
                currentMesh = &mesh;
                return;
            }
        }
        parts ~= MeshPart( object, group, material );
    }
    void materialLib ( string libName ) {
        foreach (lib; mtlLibs)
            if (lib == libName)
                return;
        mtlLibs ~= libName;
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

private void parseLines (ref string s, ref ObjParserContext parser) {
    bool parseLine () {
        final switch (s.parseLine) {
            case ParseCmd.UNKNOWN: return false;
            case ParseCmd.COMMENT: s.munchToEol; return true;
            case ParseCmd.VERTEX: return s.parseVertex( parser.vertexData );
            case ParseCmd.VERTEX_NORMAL: return s.parseVertexNormal( parser.normalData );
            case ParseCmd.VERTEX_UV:     return s.parseVertexUv( parser.uvData );
            case ParseCmd.FACE:          return s.parseFace( parser.currentMesh, parser );
            case ParseCmd.OBJECT: return parser.selectMesh( s.parseIdent, parser.currentGroup, parser.currentMtl ), true;
            case ParseCmd.GROUP:  return parser.selectMesh( parser.currentObject, s.parseIdent, parser.currentMtl ), true;
            case ParseCmd.MATERIAL: return parser.selectMesh( parser.currentObject, parser.currentGroup, s.parseIdent ), true;
            case ParseCmd.MATERIAL_LIB: return parser.materialLib( s.parseIdent ), true;
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
    Tuple!(uint, string)[] badLines;
    Tuple!(uint, string)[] lineWarnings;
    Tuple!(uint, string)[] lineErrors;
    uint   lineNum = 0;
    string lineStart = file;

    // list of material libs by mtllib declaration.
    // Will probably _not_ handle multiple mtllib statements with conflicting references
    // to materials with the same name (but then again, most .obj parsers won't handle that
    // either).
    string[] mtlLibs;

    float[] vertexData;   // 3 components per vertex
    float[] normalData;   // 3 components per normal
    float[] uvData;       // 2 components per uv

    size_t vertexCount = 0, normalCount = 0, uvCount = 0;

    string current_obj   = null;
    string current_group = null;
    string current_mtl   = null;

    MeshPart[] parts; parts ~= MeshPart();
    MeshPart*  currentMesh = &parts[$-1];

    void selectPart (string object, string group, string mtl) {
        foreach (i, part; parts) {
            if (part.object == object && part.group == group && part.mtl == mtl) {
                currentMesh = &parts[i];
                return;
            }
        }
        parts ~= MeshPart(object, group, mtl);
        currentMesh = &parts[$-1];
    }

    // Signal bad line (do thorough error checking later) and skip to eol
    void badLine (ref string s) {
        writefln("Bad line! %s, '%s'", lineNum, lineStart.sliceToEol);
        //badLines ~= tuple(lineNum, lineStart);
        s.munchToEol;
    }
    // Advance to next line. string must point to an eol character!
    void advanceLine (ref string s) {

        auto s0 = s;

        bool munched = s.munchEol();
        assert(munched, format("%s: '%s' => '%s' ('%s')", lineNum, s0.sliceToEol, s.sliceToEol, lineStart.sliceToEol));
        ++lineNum;
        lineStart = s;
        //writefln("line %s: '%s'", lineNum, s.sliceToEol);
    }
    // Warn line not fully used; emits a line warning.
    void warnUnused (string s) {
        lineWarnings ~= tuple(lineNum, format("Unused '%s' (%s)",
            s.sliceToEol, lineStart.sliceToEol));
    }

    //
    // Pass 1: parse vertex, uv, and normal data + mark other lines
    //
    void doParse () {
        //parseLines(file);

        writefln("%s verts, %s uvs, %s normals", vertexCount, uvCount, normalCount);
        writefln("%s, %s, %s", vertexData.length, uvData.length, normalData.length);

        if (badLines.length) {
            writefln("Error parsing %s line(s):", badLines.length);
            foreach (line; badLines)
                writefln("\n%s: '%s'", line[0], line[1]);
            writefln("");
        }
        if (lineErrors.length) {
            writefln("%s error(s):", lineErrors.length);
            foreach (err; lineErrors)
                writefln("\tERROR (line %s): %s", err[0], err[1]);
            writefln("");
        }
        if (lineWarnings.length) {
            writefln("%s warning(s):", lineWarnings.length);
            foreach (err; lineWarnings)
                writefln("\tWARNING (line %s): %s", err[0], err[1]);
        }
    }
    doParse();
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

    void testObjLoad () {
        import std.file;
        import std.zip;

        Tuple!(string, double, TickDuration, TickDuration)[] loadTimes;
        string readFile (string path) {
            if (path.endsWith(".zip")) {
                auto archive = new ZipArchive(read(path));
                auto file = path[0..$-4].baseName;
                assert(file.endsWith(".obj"), file);
                assert(file in archive.directory, file);
                return cast(string)archive.expand(archive.directory[file]);
            }
            return readText(path);
        }
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

        writefln("Loaded %s models in %s:", loadTimes.length, sw.peek.msecs * 1e-3);
        foreach (kv; loadTimes) {
            writefln("'%s' %s | read %s ms | load %s ms | %s / sec", 
                kv[0], kv[1].fmtBytes, kv[2].msecs, kv[3].msecs, (kv[1] / (kv[3].msecs * 1e-3)).fmtBytes);
        }
    }

    testObjLoad();
    runBenchmarks();
}

