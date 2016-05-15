
module gsb.core.mathutils;
public import gl3n.linalg;
public import gl3n.math;
import gsb.core.log;

// http://locklessinc.com/articles/next_pow2/
public auto nextPow2 (T)(T x) {
    x -= 1;
    x |= (x >> 1);
    x |= (x >> 2);
    x |= (x >> 4);
    x |= (x >> 8);
    x |= (x >> 16);
    static if (T.sizeof > 4)
        x |= (x >> 32);
    return x + 1;
}

unittest {
    assert(nextPow2(1) == 1);
    assert(nextPow2(3) == 4);
    assert(nextPow2(128) == 128);
    assert(nextPow2(127) == 128);
    assert(nextPow2(129) == 256);
    assert(nextPow2(114784) == 131072);
}


//
//  2d aabb utilities
//

// AABB / point intersection
bool rect_contains (vec2 a, vec2 b, vec2 pt) {
    assert(a.x <= b.x && a.y <= b.y);
    return !(pt.x < a.x || pt.x > b.x || pt.y < a.y || pt.y > b.y);
}
// AABB / AABB intersection
bool rect_contains (vec2 a, vec2 b, vec2 c, vec2 d) {
    assert(a.x <= b.x && a.y <= b.y && c.x <= d.x && c.y <= d.y);
    return !(d.x < a.x || d.y < a.y || c.x > b.x || c.y > b.y);
}
void rect_grow (ref vec2 a, ref vec2 b, vec2 pt) {
    assert(a.x <= b.x && a.y <= b.y);
    if      (pt.x < a.x)  a.x = pt.x;
    else if (pt.x > b.x)  b.x = pt.x;
    if      (pt.y < a.y)  a.y = pt.y;
    else if (pt.y > b.y)  b.y = pt.y;
}

unittest {
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(0,0)) == true);
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(4.5,0)) == true);
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(4.5,30)) == true);
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(4,10)) == true);

    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(-1,10)) == false);
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(-1,-1)) == false);
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(40,10)) == false);
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(2,40)) == false);
    assert(rect_contains(vec2(0, 0), vec2(4.5, 30), vec2(1,-22)) == false);

    bool rect_grow_eq (vec2 a, vec2 b, vec2 pt, vec2 expected_a, vec2 expected_b) {
        return rect_grow(a, b, pt), a == expected_a && b == expected_b;
    }
    assert(rect_grow_eq(vec2(0,0), vec2(0,0), vec2(1,4),   vec2(0,0), vec2(1,4)));
    assert(rect_grow_eq(vec2(0,0), vec2(0,0), vec2(-1,4),  vec2(-1,0), vec2(0,4)));
    assert(rect_grow_eq(vec2(4,2), vec2(22,12), vec2(-1,4),  vec2(-1,2), vec2(22,12)));
    assert(rect_grow_eq(vec2(-10,22), vec2(12,44), vec2(-1,4),  vec2(-10,4), vec2(12,44)));
}



































