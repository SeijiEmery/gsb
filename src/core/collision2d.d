
module gsb.core.collision2d;
import gsb.core.log;
import gl3n.linalg;
import gl3n.math;
import std.algorithm.comparison;
import std.algorithm.mutation;

struct Collision2d {
    struct AABB {
        vec2 p1, p2;

        this (vec2 p1, vec2 p2) {
            if (p1.x > p2.x) swap(p1.x, p2.x);
            if (p1.y > p2.y) swap(p1.y, p2.y);

            this.p1 = p1; this.p2 = p2;
        }
        @property auto dim () { return p2 - p1; }
        @property auto width () { return p2.x - p2.x; }
        @property auto height () { return p2.y - p2.y; }
        @property auto center () { return (p1 + p2) * 0.5; }
    }
    struct OBB {
        vec2 center, dim, dir;
    }
    struct Circle {
        vec2 center; float radius;
    }
    struct LineSegment {
        vec2 p1, p2; float width;
    }
    struct PolyLine {
        vec2[] points; float width;
    }
    // represents the union of two equal-sized circles, and a box joining them.
    // used for realtime collisions of moving circles (circle_t1, circle_t2)
    struct Capsule {
        vec2 p1, p2; float width;
        // Actually, it looks like this is the exact definition of a line segment
        // w/ width + rounded eges (if line width is potentially very large); 
        // maybe we don't need this.
    }

    // misc algorithms
    AABB bounds (vec2[] points) {
        assert(points.length);
        vec2 a = points[0], b = points[1];
        foreach (p; points[1..$]) {
            a.x = min(a.x, p.x);
            a.y = min(a.y, p.y);

            b.x = max(b.x, p.x);
            b.y = max(b.y, p.y);
        }
        return AABB(a, b);
    }

    AABB bounds (LineSegment line) {
        auto a = min(line.p1, line.p2), b = max(line.p1, line.p2);

        a -= vec2(line.width, line.width);
        b += vec2(line.width, line.width);

        return AABB(a, b);
    }


    AABB bounds (Circle circle) {
        return AABB(
            circle.center - vec2(circle.radius, circle.radius),
            circle.center + vec2(circle.radius, circle.radius));
    }

    // returns a circle inscribed inside of box's max extents.
    // area is slightly smaller than box (for full extents see toMaxCircle), but
    // repeated calls of toMinCircle / fromCircle will return _approximately_ the same
    // circles / boxes, instead of growing w/out bound.
    Circle toMinCircle (AABB box) {
        return Circle(box.center, max(box.width, box.height));
    }

    // returns a circle that fully contains box
    Circle toMaxCircle (AABB box) {
        return Circle(box.center, box.dim.length);
    }

    bool intersects (Circle circle, vec2 pt) {
        return distance(circle.center, pt) <= circle.radius;
    }
    bool intersects (AABB box, vec2 pt) {
        return !(pt.x < box.p1.x || pt.x > box.p2.x
              || pt.y < box.p1.y || pt.y > box.p2.y);
    }
    bool intersects (OBB box, vec2 pt) {
        assert(0, "Unimplemented!");
    }
    bool intersects (LineSegment line, vec2 pt) {
        return line_pt_distance(line.p1, line.p2, pt) <= line.width;
    }
    bool intersects (PolyLine line, vec2 pt) {
        assert(0, "Unimplemented!");
    }

    bool intersects (Circle a, Circle b) {
        return distance(a.center, b.center) <= a.radius + b.radius;
    }
    bool intersects (Circle a, AABB box) {
        assert(0, "Unimplemented!");
    }
    bool intersects (Circle a, LineSegment line) {
        assert(0, "Unimplemented!");
    }



}

//
// Core algorithms
//

//vec2 min (vec2 a, vec2 b) {
//    return vec2(min(a.x, b.x), min(a.y, b.y));
//}
//vec2 max (vec2 a, vec2 b) {
//    return vec2(max(a.x, b.x), max(a.y, b.y));
//}


// http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
float line_pt_distance (vec2 v, vec2 w, vec2 p) {
    float l2 = dot(v - w, v - w);
    if (l2 == 0) 
        return distance(p, v);

    float t = max(0, min(1, dot(p - v, w - v) / l2));
    auto proj = v + t * (w - v);
    return distance(p, proj);
}







struct Circle {
    vec2 center;
    float r;
}




























































































