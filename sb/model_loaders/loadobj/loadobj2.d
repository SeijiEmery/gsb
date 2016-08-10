import std.typecons;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.stdio;
import std.math;

string munchToEol (ref string s) {
    while (s.length && s[0] != '\n' && s[0] != '\r' && s[0] != '\0')
        s = s[1..$];
    return s;
}
unittest {
    string s;
    assert(munchToEol(s = " aslfkj \n\r") == "\n\r");
    assert(munchToEol(s = "asdf# blarg\n\r") == "\n\r");
    assert(munchToEol(s = "asdf# blarg\r\n") == "\r\n");
    assert(munchToEol(s = "\nblarg") == "\nblarg");
    assert(munchToEol(s = "") == "");
}

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

    void parseVertex (ref string s) {
        auto st = s;
        ++vertexCount;

        s.munchWs();
        uint n = parseFloats( s, vertexData );
        if (n < 3 || n > 4) {
            writefln("Expected 3-4, not %s! '%s'", n, st.sliceToEol);
            badLine(s);
            assert(vertexData.length >= n, format("%s < %s!", vertexData.length, n));
            if (n) 
                vertexData.length -= n;
            vertexData ~= [ float.nan, float.nan, float.nan ];
        }
        if (n == 4) {
            --vertexData.length;
        }
        //writefln("vertex: %s '%s'", vertexData[$-3..$], lineStart.sliceToEol);
    }
    void parseVertexNormal (ref string s) {

        s.munchWs();
        uint n = parseFloats( s, normalData );
        ++normalCount;

        if (n != 3) {
            badLine(s);
            assert(vertexData.length >= n, format("%s < %s!", normalData.length, n));
            if (n)
                normalData.length -= n;
            normalData ~= [ float.nan, float.nan, float.nan ];
        } else {
            //writefln("normal: %s '%s'", normalData[$-3..$], lineStart.sliceToEol);
        }
    }
    void parseVertexUv (ref string s) {
        s.munchWs();
        uint n = parseFloats( s, uvData );
        ++uvCount;

        if (n == 3) uvData.length--;
        else if (n != 2) {
            badLine(s);
            assert(uvData.length >= n, format("%s < %s!", uvData.length, n));
            if (n)
                uvData.length -= n;
            uvData ~= [ float.nan, float.nan ];
        } else {
            //writefln("uv: %s '%s'", uvData[$-2..$], lineStart.sliceToEol);
        }
    }
    void parseUsemtl (ref string s) {
        selectPart(current_obj, current_group, current_mtl = s.strip);
        s.munchToEol;
    }
    void parseObject (ref string s) {
        selectPart(current_obj = s.strip, current_group, current_mtl);
        s.munchToEol;
    }
    void parseGroup (ref string s) {
        selectPart(current_obj, current_group = s.strip, current_mtl);
        s.munchToEol;
    }
    void parseMtllib (ref string s) {
        mtlLibs ~= s.sliceToEol.strip;
        s.munchToEol; assert(!s.length || s[0] == '\n' || s[0] == '\r');
        //writefln("mtllib '%s': '%s'", mtlLibs[$-1], lineStart.sliceToEol);
    }

    void parseFace (ref string s) {
        int[15] indices = 0;
        int vcount = 0, tcount = 0, ncount = 0;

        bool parseIndex ( ref string s, uint i, uint max_bound ) {
            auto index = s[0] == '-' ?
                max_bound - parseUint( s = s[1..$] ) + 1 :
                parseUint( s );

            if (index - 1 < max_bound) {
                indices[i] = index;
                return true;
            }

            writefln("Index out of bounds: %s > %s '%s' '%s'",
                index, max_bound, s.sliceToEol, lineStart.sliceToEol);
            return false;
        }

        s.munchWs();
        while (!s.atEol) {
            if (s[0] != '-' && (s[0] < '0' || s[0] > '9')) {
                writefln("Not numeric: '%s' ('%s')", s.sliceToEol, lineStart.sliceToEol);
                goto parseError;
            }

            if (!parseIndex( s, ++vcount * 3, cast(uint)vertexCount )) {
                goto parseError;
            }

            if (++vcount > 4)
                goto invalidPairs;

            if (s[0] == '/') {
                s = s[1..$];
                if (s[0] != '/' && parseIndex(s, vcount * 3 + 1, cast(uint)uvCount )) {
                    if (++tcount != vcount)
                        goto invalidPairs;
                }

                if (s[0] == '/') {
                    s = s[1..$];
                    if (parseIndex( s, vcount * 3 + 2, cast(uint)normalCount)) {
                        if (++ncount != ncount)
                            goto invalidPairs;
                    }
                }
            }
            s.munchWs();
        }
        if (vcount < 3) { 
            writefln("Not enough value pairs (vcount = %s)", vcount);
            goto invalidPairs;
        }
        switch (vcount) {
            case 3:
                currentMesh.tris ~= indices[0..9];
                //writefln("tri %s '%s'", indices, lineStart.sliceToEol);
                break;
            case 4:
                currentMesh.quads ~= indices[0..12];
                //writefln("quad %s '%s'", indices, lineStart.sliceToEol);
                break;
            default: assert(0, format("%s!", vcount));
        }
        return;
    invalidPairs:
        writefln("Invalid value pair(s): %s, %s, %s '%s'",
            vcount, tcount, ncount, lineStart.sliceToEol);
    parseError:
        //badLine(s);
    }

    void parseLines (ref string s) {
        //writefln("Line %s '%s'", lineNum, s.sliceToEol);
        while (!s.eof) {
            s.munchWs();
            while (s.atEol && !s.eof) {
                advanceLine(s);
                s.munchWs();
            }
            if (s.eof) break;

            switch (s[0]) {
                case 'v': switch (s[1]) {
                    case ' ': parseVertex(s = s[2..$]); break;
                    case 't': 
                        if (s[2] != ' ') badLine(s);
                        else parseVertexUv(s = s[3..$]); break;
                    case 'n':
                        if (s[2] != ' ') badLine(s);
                        else parseVertexNormal(s = s[3..$]); break;
                    default:
                        writefln("Unhandled: '%s'", s.sliceToEol); 
                        badLine(s);
                } break;
                case 'f': 
                    if (s[1] != ' ') badLine(s);
                    else parseFace(s = s[2..$]); break;
                case 'o':
                    if (s[1] != ' ') badLine(s);
                    else parseObject(s = s[2..$]); break;
                case 'g':
                    if (s[1] != ' ') badLine(s);
                    else parseObject(s = s[2..$]); break;
                case 'u':
                    if (s.length < 7 || s[0..7] != "usemtl ") badLine(s);
                    else parseUsemtl(s = s[7..$]); break;
                case 'm':
                    if (s.length < 7 || s[0..7] != "mtllib ") badLine(s);
                    else parseMtllib(s = s[7..$]); break;
                default: 
                    writefln("Unhandled: '%s'", s.sliceToEol);
                    badLine(s);
            }

            auto s_end = s;
            if (s.eof) break;
            else if (s.atEol) {
                advanceLine(s);
            } else {
                warnUnused(s_end);
                s.munchToEol;
                if (!s.eof) {
                    advanceLine(s);
                }
            }
        }
    }
    void doParse () {
        parseLines(file);

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

