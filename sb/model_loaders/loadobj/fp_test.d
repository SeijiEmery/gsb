import std.stdio;
import std.math;


// http://stackoverflow.com/a/23862121
uint clz (uint x) {
    immutable char[32] debruijn32 = [
        0, 31, 9, 30, 3, 8, 13, 29, 2, 5, 7, 21, 12, 24, 28, 19,
        1, 10, 4, 14, 6, 22, 25, 20, 11, 15, 23, 26, 16, 27, 17, 18
    ];
    x |= x>>1;
    x |= x>>2;
    x |= x>>4;
    x |= x>>8;
    x |= x>>16;
    x++;
    return debruijn32[x*0x076be629>>27];
}

float decimalToFlt (bool sign, uint mantissa, int exp) {
    if (exp > +128) return +float.nan;
    if (exp < -127) return -float.nan;

    exp += 127;
    mantissa = (exp << 23) | (mantissa & 0x7FFFFF);
    //if (sign) mantissa |= 1 << 31;
    return *(cast(float*)&mantissa);
}

void parseDecimal (ref string s, ref bool sign, ref uint mantissa, ref int exp, bool useDecExp = true) {
    auto s0 = s;
    if (!s.length)
        return;

    if (s[0] == '-') { 
        sign = true; 
        s = s[1..$]; }
    else {
        if (s[0] == '+') 
            s = s[1..$];
        sign = false;
    }

    mantissa = 0; exp = 0;
    while (s.length && !(s[0] < '0' || s[0] > '9')) {
        mantissa *= 10;
        mantissa += cast(uint)(s[0] - '0');
        s = s[1..$];
    }
    if (s.length && s[0] == '.') {
        s = s[1..$];
        while (s.length && !(s[0] < '0' || s[0] > '9')) {
            mantissa *= 10;
            mantissa += cast(uint)(s[0] - '0');
            --exp;
            s = s[1..$];
        }
    }
    if (s.length && (s[0] == 'e' || s[0] == 'E')) {
        bool e_sign = void;
        if (s[1] == '-') {
            s = s[2..$];
            e_sign = true;
        } else if (s[1] == '+') {
            s = s[2..$];
            e_sign = false;
        } else {
            s = s[1..$];
            e_sign = false;
        }

        uint e = 0;
        while (s.length && !(s[0] < '0' || s[0] > '9')) {
            e *= 10;
            e += cast(uint)(s[0] - '0');
            s = s[1..$];
        }
        if (useDecExp)
            exp += e_sign ? -e : e;
        else
            exp = e_sign ? -e : e;
    }
}
float parseFloat_powMethod (ref string s) {
    bool sign; uint mantissa; int exp;
    parseDecimal(s, sign, mantissa, exp);
    return cast(float)(cast(double)(mantissa) * pow(10, cast(double)exp));
}
float parseFloat_shiftMethod (ref string s) {
    bool sign; uint mantissa; int exp; auto s0 = s;
    parseDecimal(s, sign, mantissa, exp, false);

    auto v0 = mantissa;

    auto shifts = 0;
    while ((mantissa & (1 << 23)) == 0) {
        mantissa <<= 1;
        ++shifts;
    }
    //writefln("%s | %s | %s | %s | shifts: %s", s0, v0, mantissa, exp, shifts);
    //writefln("%s shifts | exp = %s", shifts, exp);
    return decimalToFlt(sign, mantissa, 23 - shifts);
}

float parseFloat_clzMethod (ref string s) {
    bool sign; uint mantissa; int exp; auto s0 = s;
    parseDecimal(s, sign, mantissa, exp);

    int shift = cast(int)clz(mantissa) - 8;

    //writefln("%s | %s | %s | %s | adj clz: %s", 
    //    s0, mantissa, mantissa << (clz(mantissa)-8), 
    //    exp, shift);

    //writefln("base exp %s + %s => %s", 23 - shift, exp, exp, 23 - shift + exp);
    mantissa <<= shift;
    return decimalToFlt(sign, mantissa, 23 - shift);
}

void main () {
    import std.stdio;
    import std.conv : parse;

    string[] flts = [
        "1",
        "-1",
        "23",
        "7894.21",
        "1234.456",
        "1234.456e-20",
        "1234.456e20",
        "1231094801928.021380192012"
    ];
    foreach (flt; flts) {
        string s;
        writefln("%s => %s | %s | %s | %s", flt, parse!float(s = flt),
            parseFloat_powMethod(s = flt), 
            parseFloat_shiftMethod(s = flt),
            parseFloat_clzMethod(s = flt));
    }

    double benchmark (string fcn)() {
        import std.datetime;
        string flt, s = "1234.56328947e-89";
        auto n = 1_000_000;
        float[] results;

        //writefln("Running benchmark: %s", fcn);
        StopWatch sw; sw.start();
        while (n --> 0) {
            mixin(`results ~= `~fcn~`(flt = s);`);
        }
        return cast(double)sw.peek.usecs * 1e-6;
    }
    double benchStd () {
        import std.datetime;
        string flt, s = "1234.56328947e-89";
        auto n = 1_000_000;
        float[] results;

        StopWatch sw; sw.start();
        while (n --> 0) {
            results ~= parse!float(flt = s);
        }
        return cast(double)sw.peek.usecs * 1e-6;
    }
    writefln("bench parse!float:      %s", benchmark!(`parse!float`));
    writefln("bench parseFloat_pow:   %s", benchmark!(`parseFloat_powMethod`));
    writefln("bench parseFloat_shift: %s", benchmark!(`parseFloat_shiftMethod`));
    writefln("bench parseFloat_clz:   %s", benchmark!(`parseFloat_clzMethod`));
}
