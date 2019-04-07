// color.d

import gl3n.linalg;

vec4 rgb  (T)(T r, T g, T b, T a = 1) { 
    return vec4(r, g, b, a); 
}
vec4 rgb (string color) {
    if (color[0] == '#') {

    } else {

    }
}
vec4 hsv (T)(T h, T s, T v, T a = 1) {
    assert(0, "TBD!");
}
vec4 hsv (string color) {
    if (color[0] == '#') {

    } else {

    }
}

// More stuff tbd...
