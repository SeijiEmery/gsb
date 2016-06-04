module gsb.core.slate.slateui;

enum FixedUIDir : ubyte {
    // fixed directions: horizontal | vertical
    HORIZONTAL, VERTICAL,

    // relative (to parent) directions: parallel | perpendicular
    PARALLEL,   PERP
}
bool isConcrete (FixedUIDir dir) {
    return dir == FixedUIDir.HORIZONTAL || dir == FixedUIDir.VERTICAL;
}
bool horizontal (FixedUIDir dir)
in { assert(dir.isConcrete); }
body { return dir == FixedUIDir.HORIZONTAL; }

bool vertical (FixedUIDir dir)
in { assert(dir.isConcrete); }
body { return dir == FixedUIDir.VERTICAL; }



enum Dir4 { LEFT = 0, RIGHT, UP, DOWN }



private immutable auto prop_readonly (string name, string value)() {
    return `auto `~name~` () { return `~value~`; }`;
}
private immutable auto prop_write_rvalue (string name, string value)() {
    return `auto `~name~` (typeof(`~value~`) v) { return `~value~` = v; }`;
}
private immutable auto prop_write_rself (string name, string value)() {
    return `auto `~name~` (typeof(`~value~`) v) { `~value~` = v; return self; }`;
}
private immutable auto value_prop (string name, string value)() {
    return prop_readonly!(name,value) ~ prop_write_rvalue!(name, value);
}
private immutable auto self_prop (string name, string value)() {
    return prop_readonly!(name,value) ~ prop_write_rself!(name, value);
}


struct Anchor {
    mixin slateui_anchor;

    this (SlateObj owner) {
        m_owner = owner;
    }
}

struct rect4f {
    vec2 topLeft = vec2(0, 0);
    vec2 btmRight = vec2(0, 0);

    this (vec2 tl, vec2 br) { topLeft = tl; br = btmRight; }
    this (rect4f r) { topLeft = r.topLeft; btmRight = r.btmRight; }

    @property auto minx () { return topLeft.x; }
    @property auto maxx () { return btmRight.x; }
    @property auto miny () { return btmRight.y; }
    @property auto maxy () { return topLeft.y; }

    @property auto width  () const { return btmRight.x - topLeft.x; }
    @property auto height () const { return topLeft.y  - btmRight.y; }
    @property auto center () const { return (topLeft + btmRight) * 0.5; }

    auto ref clampZero () {
        if (width < 0) width = 0;
        if (height < 0) height = 0;
        return this;
    }

    @property auto width (float w) {
        auto cx = topLeft.x + btmRight.x;
        topLeft.x  = (cx - w) * 0.5;
        btmRight.x = (cx + w) * 0.5;
    }
    @property auto height (float h) {
        auto cy = topLeft.y + btmRight.y;
        topLeft.y  = (cy + h) * 0.5;
        btmRight.y = (cy - h) * 0.5;
    }
    @property auto center (vec2 pt) {
        auto rel = center + pt;
        topLeft  += rel;
        btmRight += rel;
    }
    auto ref grow (vec2 pt) {
        if (pt.x < topLeft.x) topLeft.x = pt.x;
        else                  btmRight.x = pt.x;
        if (pt.y < btmRight.y) btmRight.y = pt.y;
        else                   topLeft.y = pt.y;
        return this;
    }
}

rect4f join (rect4f a, rect4f b) {
    return rect4f(
        vec2( min(a.minx, b.minx), max(a.maxy, b.maxy) ),
        vec2( max(a.maxx, b.maxx), min(a.miny, b.miny) )
    );
}
rect4f join (rect4f a, vec2 b) {
    return rect4f(
        vec2( min(a.minx, b.x), max(a.maxy, b.y) ),
        vec2( max(a.maxx, b.x), max(a.miny, b.y) )
    );
}
rect4f join (vec2 a, vec2 b) {
    return rect4f(
        vec2( min(a.x, b.x), max(a.y, b.y) ),
        vec2( max(a.x, b.x), min(a.y, b.y) )
    );
}

// Rect union (equiv to join())
rect4f join (rect4f a, rect4f b) {
    if (b.minx < a.minx) a.minx = b.minx;
    if (b.miny < a.miny) a.miny = b.miny;
    if (b.maxy > a.maxy) a.maxy = b.maxy;
    if (b.maxx > a.maxx) a.maxx = b.maxx;
    return a;
}
rect4f join (rect4f a, vec2 b) {
    if      (b.x < a.minx) a.minx = b.x;
    else if (b.x > a.maxx) a.maxx = b.x;
    if      (b.y < a.miny) a.miny = b.y;
    else if (b.y > a.maxy) a.maxy = b.y;
    return a;
}
rect4f join (vec2 a, vec2 b) {
    if (b.x < a.x) swap(a.x, b.x);
    if (b.y < a.y) swap(a.x, b.y);
    return rect4f(a, b);
}

// Rect difference
rect4f trim (rect4f a, rect4f b) {
    a.topLeft += b.topLeft;
    a.btmRight -= b.btmRight;
    return a.clampZero;
}
rect4f trim (rect4f a, vec2 b) {
    a.topLeft  += b * 0.5;
    a.btmRight -= b * 0.5;
    return a.clampZero;
}

// And finally, our intersection algorithms:

// Classic aabb / aabb and aabb / point tests
bool contains (rect4f a, rect4f b) {
    return !(a.minx > b.maxx || a.maxx > b.minx || a.miny > b.maxy || a.maxy > b.miny);
}
bool contains (rect4f rect, vec2 pt) {
    return !(pt.x < rect.minx || pt.x > rect.maxx || pt.y < rect.miny || pt.y > rect.maxy);
}

// Original, less efficient algorithm
bool contains (rect4f rect, vec2 pt, float radius) {
    if (pt.x - radius < rect.minx ||
        pt.x + radius > rect.maxx ||
        pt.y - radius < rect.miny ||
        pt.y + radius > rect.maxy)
            return false;
    if (pt.x < rect.minx && pt.y > rect.maxy)
        return pt.distance(rect.topLeft) <= radius;
    if (pt.x < rect.minx && pt.y < rect.miny)
        return pt.distance(rect.btmLeft) <= radius;
    if (pt.x > rect.maxx && pt.y > rect.maxy)
        return pt.distance(rect.topRight) <= radius;
    if (pt.x > rect.maxx && pt.y < rect.miny)
        return pt.distance(rect.btmRight) <= radius;
    return true;
}

// Rect / circle test. Also equivalent to the rounded rect / point test,
// or rounded rect + circle test.
bool contains (rect4f rect, vec2 pt, float radius) {
    float rx = 0, ry = 0;
    //vec2 nearest = pt;

    if (pt.x < rect.minx) {
        if (pt.x + radius < rect.minx)
            return false;
        //nearest.x = rect.minx;
        rx = rect.minx - pt.x;

    } else if (pt.x > rect.maxx) {
        if (pt.x - radius > rect.maxx)
            return false;
        //nearest.x = rect.maxx;
        rx = pt.x - rect.maxx;      // note: can be in any order; sign irrelevant
    }
    // last case (pt _inside_ rect minx / maxx) handled by default rx = 0.
    // if rx == 0 and ry == 0, last test will always pass.
    // if rx == 0 (or vice versa), test becomes ry * ry <= radius * radius,
    //            or just ry <= radius.
    //
    // We can handle all 4 major cases: point (circle center) completely inside 
    // or outside rect, point/circle crossing rect edge, and the circle in rect corner
    // case (which requires a circular bounds check) with some fairly simple logic
    // and at most 6 branches (which I'm sure could be eliminated if necessary with branchless simd).
    //
    // FWIW, our algorithm works as follows:
    // – first, determine whether point is fully inside / outside rect, and which side it's on
    //   (first branch; the second short circuits for the circle-is-fully-outside-rect case)
    // - next, store the distance to the nearest rect coordinate, which we know due to the 
    //   first branches. If our point lies fully within the rectangle, the distance is 0 as
    //   defined for the default rx/ry values.
    // - repeat this for the x and y coordinates, and finally just do a distance check between
    //   the nearest point (we know the x/y distances) and the circle radius.
    //   We could detect the fully-within-circle case, but this is handled by the above step,
    //   and a dp + cmp is probably cheaper than another branch instruction.

    if (pt.y < rect.miny) {
        if (pt.y + radius < rect.miny)
            return false;
        //nearest.y = rect.miny;
        ry = rect.miny - pt.y;

    } else if (pt.y > rect.maxy) {
        if (pt.y - radius > rect.maxy)
            return false;
        //nearest.y = rect.maxy;
        ry = pt.y - rect.maxy;
    }

    //nearest -= pt;
    //return dot(nearest, nearest) <= radius * radius;
    return rx * rx + ry * ry <= radius * radius;
}

// And, since I love to endlessly refactor things:
bool contains (rect4f rect, vec2 pt, float radius) {

    // calculate distance from rect bounds to pt for a given x/y coordinate.
    // - if pt is fully inside rect returns 0
    // – if pt is fully outside rect, returns NaN, which will fail comparisons and
    //   ultimately return false, which is actually what we want (assuming IEEE754, etc)
    // - returns the distance between pt and the component of the nearest rect point
    //   otherwise.
    auto dist (T)(T v, T minv, T maxv) {
        if (v < minv) {
            return v + radius < minv ? 
                T.nan :   // out of (rect) bounds
                v - minv; // component of distance to nearest rect pt

        } else if (v > maxv) {
            return v - radius > maxv ?
                T.nan :   // out of (rect) bounds
                v - maxv; // component of distance to nearest rect pt
        } else {
            return 0;     // fully inside rect => distance is 0
        }
    }

    auto rx = dist(pt.x, rect.minx, rect.maxx);
    auto ry = dist(pt.y, rect.miny, rect.maxy);

    return rx * rx + ry * ry <= radius * radius;
}




















private auto relPos (rect4f bounds, FixedUIDir orientation, vec2 rel, rect4f border)
in {
    assert(rel.x.inRange(-1, 1) && rel.y.inRange(-1, 1));
    assert(orientation.isConcrete);
} body {
    bounds.topLeft  += border.topLeft;
    bounds.btmRight -= border.btmRight;

    auto x = bounds.width > 0 ? bounds.width * 0.5 * rel.x : 0.0;
    auto y = bounds.height > 0 ? bounds.height * 0.5 * rel.y : 0.0;

    return rel.horizontal ?
        vec2(x, y) :
        vec2(y, x);
}













private template mixin slateui_anchor {
    FixedUIDir  m_orient; // layout orientation (vertical | horizontal)
    vec2        m_rel;    // 2d center pos in [-1,1] relative to parent left / right / center
    float[4]    m_border; // and border in directions LEFT / RIGHT / UP / DOWN

    SlateObj    m_owner;
    SlateObj    m_target;

    mixin self_prop!(`orient`, `m_orient`);
    mixin self_prop!(`rel`,    `m_rel`);
    mixin self_prop!(`border`, `m_border`);
    mixin readonly_prop!(`owner`, `m_owner`);
    mixin self_prop!(`target`, `m_target`);

    @property auto minRect () {
        return m_target.minRect
            .subDim(
                m_border[Dir4.LEFT] + m_border[Dir4.RIGHT],
                m_border[Dir4.TOP]  + m_border[Dir4.BTM] );
    }
    @property auto innerRect () {
        return m_owner.rect
            .trim(m_border[Dir4.LEFT],  m_border[Dir4.TOP],
                  m_border[Dir4.RIGHT], m_border[Dir4.BTM])
    }

    @property auto innerRect () {
        return m_owner.rect
            .trim(m_border[Dir4.LEFT],  m_border[Dir4.TOP],
                  m_border[Dir4.RIGHT], m_border[Dir4.BTM])
            .emplace(
                m_target.innerRect
                )
    }
}






















