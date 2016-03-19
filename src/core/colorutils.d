
module gsb.core.colorutils;
import gl3n.linalg;
import std.math;


// Converts RGB color space to normalized HSL values:
// https://en.wikipedia.org/wiki/HSL_and_HSV.
// All values are clamped between [0, 1]; for a conventional HSL
// color cylinder, multiply the H component by 360.0 (or 2 pi, etc).
vec3 rgb_to_hsl (vec3 rgb) {
    auto r = rgb.x, g = rgb.y, b = rgb.z;

    // tbd...
    return rgb_to_hsv(rgb);
}
vec3 hsl_to_rgb (vec3 hsl) {
    auto h = hsl.x, s = hsl.y, l = hsl.z;

    // tbd...
    return hsv_to_rgb(hsl);
}

// Converts RGB color space to normalized HSV values:
// https://en.wikipedia.org/wiki/HSL_and_HSV.
// All values are clamped between [0, 1]; for a conventional HSV
// color cylinder, multiply the H component by 360.0 (or 2 pi, etc).
vec3 rgb_to_hsv (vec3 rgb) {
    auto r = rgb.x, g = rgb.y, b = rgb.z;

    auto M = max(r, g, b);
    auto m = min(r, g, b);
    auto c = M - m;

    float h;
    if (r > max(g, b))      h = fmod((g - b) / c, 6);
    else if (g > max(r, b)) h = (b - r) / c + 2;
    else if (b > max(r, g)) h = (b - r) / c + 4;
    else h = 0.0; // "undefined"; doesn't really matter what this value is though

    float v = M;
    float s = c ? c / v : 0;

    return vec3(h / 6, s, v);
}
vec3 hsv_to_rgb (vec3 hsv) {
    auto h = hsv.x, s = hsv.y, v = hsv.z;
    
    h *= 6;

    float c = s * v; // chroma
    float x = c * (1 - abs(fmod(h, 2) - 1));
    
    vec3 rgb;
    if      (h <= 1) rgb = vec3(c, x, 0);
    else if (h <= 2) rgb = vec3(x, c, 0);
    else if (h <= 3) rgb = vec3(0, c, x);
    else if (h <= 4) rgb = vec3(0, x, c);
    else if (h <= 5) rgb = vec3(x, 0, c);
    else if (h <= 6) rgb = vec3(c, 0, x);

    auto m = vec3(v - c, v - c, v - c);
    return rgb + m;
}

















