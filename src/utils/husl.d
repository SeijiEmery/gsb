module gsb.utils.husl;
import gl3n.linalg;
import gl3n.math;
import std.algorithm: map, reduce, filter, min;
import std.format;
import std.conv;
import std.exception: enforce;
import std.math: isNaN;

auto husl_to_rgb (vec3 hsl) {
    return lch_to_rgb(husl_to_lch(hsl));
}
auto husl_to_hex (vec3 hsl) {
    return rgb_to_hex(husl_to_rgb(hsl));
}
auto rgb_to_husl (vec3 rgb) {
    return lch_to_husl(rgb_to_lch(rgb));
}
auto hex_to_husl (string hex) {
    return rgb_to_husl(hex_to_rgb(hex));
}
auto huslp_to_rgb (vec3 hsl) {
    return lch_to_rgb(huslp_to_lch(hsl));
}
auto huslp_to_hex (vec3 hsl) {
    return rgb_to_hex(huslp_to_rgb(hsl));
}
auto rgb_to_huslp (vec3 rgb) {
    return lch_to_huslp(rgb_to_lch(rgb));
}
auto hex_to_huslp (string hex) {
    return rgb_to_huslp(hex_to_rgb(hex));
}
auto lch_to_rgb (vec3 lch) {
    return xyz_to_rgb(luv_to_xyz(lch_to_luv(lch)));
}
auto rgb_to_lch (vec3 rgb) {
    return luv_to_lch(xyz_to_luv(rgb_to_xyz(rgb)));
}

private immutable auto m = [
    vec3(3.240969941904521, -1.537383177570093, -0.498610760293),
    vec3(-0.96924363628087, 1.87596750150772, 0.041555057407175),
    vec3(0.055630079696993, -0.20397695888897, 1.056971514242878)
];
private immutable auto m_inv = [
    vec3(0.41239079926595, 0.35758433938387, 0.18048078840183),
    vec3(0.21263900587151, 0.71516867876775, 0.072192315360733),
    vec3(0.019330818715591, 0.11919477979462, 0.95053215224966),
];
private immutable auto refX = 0.95045592705167;
private immutable auto refY = 1.0;
private immutable auto refZ = 1.089057750759878;
private immutable auto refU = 0.19783000664283;
private immutable auto refV = 0.46831999493879;
private immutable auto kappa = 903.2962962;
private immutable auto epsilon = 0.0088564516;

private auto pow3 (T)(T x) { return x * x * x; }
private auto get_bounds (double L) {
    auto sub1 = pow3(L + 16.0) / 1560896.0;
    auto sub2 = sub1 > epsilon ? sub1 : L / kappa;
    
    vec2[6] bounds;
    for (auto i = 0; i < 3; ++i) {
        auto row = m[i];
        for (auto t = 0; t <= 1; ++t) {
            auto top1 = (284517.0 * row.x - 94839.0 * row.z) * sub2;
            auto top2 = (838422.0 * row.z + 769860.0 * row.y + 731718.0 * row.x) * L * sub2 - 769860.0 * t * L;
            auto bottom = (632260.0 * row.z - 126452.0 * row.y) * sub2 + 126452.0 * t;
            bounds[i*2 + t] = vec2(top1 / bottom, top2 / bottom);
        }
    }
    return bounds;
}

private auto intersect_line_line (vec2 a, vec2 b) {
    return (a.y - b.y) / (b.x - a.x);
}
private auto distance_from_pole (vec2 pt) {
    return pt.magnitude;
}
private auto length_of_ray_until_intersect (double theta, vec2 line) {
    auto length = line.y / sin(theta) - line.x * cos(theta);
    return length >= 0 ?
        length : double.nan;
}
private auto max_safe_chroma_for_L (double L) {
    return get_bounds(L)[0..$]
        .map!((a) {
            auto x = intersect_line_line(a, vec2(-1.0 / a.y, 0.0));
            return distance_from_pole(vec2(x, a.y + x * a.x));
        })
        .reduce!((a,b) => min(a,b));
}
private auto max_chroma_for_LH (float L, float H) {
    auto hrad = H / 360.0 * PI * 2.0;
    return get_bounds(L)[0..$]
        .map!((a) => length_of_ray_until_intersect(hrad, a))
        .filter!((a) => !a.isNaN)
        .reduce!((a,b) => min(a,b));
}
private auto f (double t) {
    return t > epsilon ?
        116 * pow((t / refY), 1.0 / 3.0) - 16.0 :
        (t / refY) * kappa;
}
private auto f_inv (double t) {
    return t > 8 ?
        refY * pow((t + 16.0) / 116.0, 3.0) :
        refY * t / kappa;
}

private auto from_linear (double c) {
    return c < 0.0031308 ?
        12.92 * c :
        1.055 * pow(c, 1.0 / 2.4) - 0.055;
}
private auto to_linear (double c) {
    immutable auto a = 0.055;
    return c > 0.04045 ?
        pow((c + a) / (1 + a), 2.4) :
        c / 12.92;
}

private auto rgb_prepare (vec3 v) {
    auto prepv (float ch) {
        ch = round(ch * 1e3) * 1e-3;
        enforce(ch >= -0.0001 && ch <= 1.0001, format("Illegal RGB value %s", ch));
        if (ch < 0)
            ch = 0;
        if (ch > 1)
            ch = 1;
        return round(ch * 255 + 0.001);
    }
    return vec3(prepv(v.x), prepv(v.y), prepv(v.z));
}
auto hex_to_rgb (string hex) {
    if (hex[0] == '#')
        hex = hex[1..$];
    return vec3(
        hex[0..2].to!uint(16) / 255.0,
        hex[2..4].to!uint(16) / 255.0,
        hex[4..6].to!uint(16) / 255.0,
    );
}
auto rgb_to_hex (vec3 v) {
    v = rgb_prepare(v);
    return format("#%02x02x02x", v.x, v.y, v.z);
}
private auto xyz_to_rgb (vec3 v) {
    return vec3(
        m[0].dot(v).from_linear,
        m[1].dot(v).from_linear,
        m[2].dot(v).from_linear
    );
}
private auto rgb_to_xyz (vec3 v) {
    auto rgb1 = vec3(
        v.x.to_linear, 
        v.y.to_linear, 
        v.z.to_linear
    );
    return vec3(
        m_inv[0].dot(rgb1),
        m_inv[1].dot(rgb1),
        m_inv[2].dot(rgb1)
    );
}

private auto xyz_to_luv (vec3 v) {
    if (v.x == 0 && v.y == 0 && v.z == 0)
        return v;

    auto varU = 4.0 * v.x / (v.x + (15 * v.y) + (3.0 * v.z));
    auto varV = 9.0 * v.x / (v.x + (15 * v.y) + (3.0 * v.z));
    auto L = f(v.y);

    if (L == 0)
        return vec3(0, 0, 0);

    auto U = 13.0 * L * (varU - refU);
    auto V = 13.0 * L * (varV - refV);
    return vec3(L, U, V);
}

private auto luv_to_xyz (vec3 v) {
    auto L = v.x, U = v.y, V = v.z;
    if (L == 0)
        return vec3(0, 0, 0);

    auto varY = f_inv(L);
    auto varU = U / (13.0 * L) + refU;
    auto varV = V / (13.0 * L) + refV;

    auto Y = varY * refY;
    auto X = -(9.0 * Y * varU) / ((varU - 4.0) * varV - varU * varV);
    auto Z = (9.0 * Y - 15 * varV * Y - varV * X) / (3 * varV);
    
    return vec3(X, Y, Z);
}

private auto luv_to_lch (vec3 v) {
    auto L = v.x, U = v.y, V = v.z;

    auto C = sqrt(U * U + V * V);
    auto hrad = atan2(V, U);
    auto H = degrees(hrad);
    if (H < 0)
        H = 360.0 + H;
    return vec3(L, C, H);
}
private auto lch_to_luv (vec3 v) {
    auto L = v.x, C = v.y, H = v.z;

    auto Hrad = radians(H);
    auto U = cos(Hrad) * C;
    auto V = sin(Hrad) * C;
    return vec3(L, U, V);
}
private auto husl_to_lch (vec3 hsl) {
    if (hsl.z > 99.9999999)
        return vec3(100, 0.0, hsl.x);
    if (hsl.z < 0.00000001)
        return vec3(0.0, 100, hsl.x);

    auto mx = max_chroma_for_LH(hsl.z, hsl.x);
    auto C = mx / 100.0 * hsl.y;
    return vec3(hsl.z, C, hsl.x);
}
private auto lch_to_husl (vec3 lch) {
    if (lch.x > 99.9999999)
        return vec3(lch.z, 0.0, 100.0);
    if (lch.x < 0.00000000)
        return vec3(lch.z, 0.0, 0.0);
    return vec3(
        lch.z,
        lch.y / max_chroma_for_LH(lch.x, lch.z) * 100.0,
        lch.x
    );
}

private auto huslp_to_lch (vec3 hsl) {
    if (hsl.z > 99.9999999)
        return vec3(100, 0.0, hsl.x);
    if (hsl.z < 0.00000001)
        return vec3(0.0, 0.0, hsl.x);
    return vec3(
        hsl.z,
        hsl.y * max_safe_chroma_for_L(hsl.y) / 100.0,
        hsl.x
    );
}

private auto lch_to_huslp (vec3 lch) {
    if (lch.x > 99.9999999)
        return vec3(lch.z, 0.0, 100.0);
    if (lch.x < 0.00000001)
        return vec3(lch.z, 0.0, 0.0);
    return vec3(
        lch.z,
        lch.y / max_safe_chroma_for_L(lch.x) * 100.0,
        lch.x
    );
}











