import std.stdio;
import std.math: pow;

float parseFloat (string s) {
    auto s0 = s;

    bool sign = false;
    if (s[0] == '-') { sign = true; s = s[1..$]; }
    else if (s[0] == '+') s = s[1..$];

    uint mantissa = 0; int exp = 0;
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
        exp += e_sign ? -e : e;
    }

    auto v = cast(int)mantissa;
    if (sign) v = -v;

    //writefln("Value '%s' => %se%s", s0, v, exp);
    return cast(float)(cast(double)(v) * pow(10, cast(double)exp));
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
        "1234.456e20"
    ];
    foreach (flt; flts) {
        writefln("%s => %s (%s)", 
            flt, parseFloat(flt), parse!float(flt));
    }
}
