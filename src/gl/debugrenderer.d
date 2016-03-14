
module gsb.gl.debugrenderer;
import gsb.gl.algorithms;
import gsb.gl.state;
import gsb.gl.drawcalls;

import gsb.core.log;
import gsb.core.color;
import gsb.core.singleton;
import gsb.core.window;
import gsb.glutils;
import derelict.opengl3.gl3;
import dglsl;
import gl3n.linalg;

import core.sync.mutex;
import std.traits;

mixin Color.fract;

class ColoredVertexShader: Shader!Vertex {
    @layout(location=0)
    @input vec4   pcv;     // packed vertex position + color

    @uniform mat4 transform;

    @output vec4 color;
    @output float edgeDist;
    @output float edgeBorder;

    vec4 unpackRGBA (float packed) {
        vec4 enc = vec4(1.0, 255.0, 65025.0, 160581375.0) * packed;
        enc = fract(enc);
        vec4 foo = enc.yzww * vec4(1.0/255.0, 1.0/255.0, 1.0/255.0, 0.0);
        enc -= foo;
        //enc -= enc.yzww * vec4(1.0/255.0, 1.0/255.0, 1.0/255.0, 0.0);
        return enc;
    }

    void main () {
        edgeDist    = pcv.z;
        edgeBorder  = abs(pcv.z);

        gl_Position = transform * vec4(pcv.xy, 0.0, 1.0);
        color       = unpackRGBA(pcv.w);
    }
}

import std.math: abs;
class ColoredFragmentShader: Shader!Fragment {
    @input vec4 color;
    @input float edgeDist;
    @input float edgeBorder;
    @output vec4 fragColor;

    void main () {
        float dist = abs(edgeDist) > 1.0 ? 
            1.0 - (abs(edgeDist) - 1.0) / (edgeBorder - 1.0) :
            1.0;

        float alpha = dist;// * dist;

        //float alpha = abs(edgeDist) > 1.0 ? 0.5 : 1.0;
        //float alpha = edgeDist > 0.9 ? (1.0 - edgeDist) * 10.0 :
        //              edgeDist < 0.1 ? edgeDist * 10.0 :
        //              1.0;

        fragColor = vec4(color.rgb, alpha);

        //fragColor = vec4(color.xy, alpha, 1.0);
        //if (abs(edgeDist) > 1.0)
        //    fragColor.g += 0.2;
    }
}


@property auto DebugRenderer () { return DebugLineRenderer2D.instance; }
class DebugLineRenderer2D {
    mixin LowLockSingleton;

    protected struct State {
        //GLuint vao = 0;
        //GLuint[1] buffers;
        float[]   vbuffer;
        auto vao = new VAO();

        protected void render (ref mat4 transform) {
            if (!vbuffer.length)
                return;

            glState.enableDepthTest(false);
            glState.enableTransparency(true);

            glEnable(GL_BLEND);
            glDisable(GL_DEPTH_TEST);

            //foreach (i; 0 .. 1000) {
                DynamicRenderer.drawArrays(vao, GL_TRIANGLES, 0, cast(int)vbuffer.length / 4, [
                    VertexData(vbuffer.ptr, vbuffer.length * 4, [
                        VertexAttrib(0, 4, GL_FLOAT, GL_FALSE, 0, null)
                    ])
                ]);
            //}

            glState.enableDepthTest(true);
            glState.enableTransparency(true);
        }

        protected void releaseResources () {
            vao.release();
        }
    }
    private State[2] states;
    private int fstate = 0, gstate = 1;

    private void pushQuad (vec2 a, vec2 b, vec2 c, vec2 d, float color, float edgeFactor) {
        states[fstate].vbuffer ~= [
            a.x, a.y, +edgeFactor, color,// + 40.0 / 256.0,
            b.x, b.y, -edgeFactor, color,// + 40.0 / 256.0,
            d.x, d.y, -edgeFactor, color,// + 40.0 / 256.0,

            a.x, a.y, +edgeFactor, color,
            d.x, d.y, -edgeFactor, color,
            c.x, c.y, +edgeFactor, color,
        ];
    }
    private void pushQuad (vec3 a, vec3 b, vec3 c, vec3 d, float color, float edgeFactor) {
        pushQuad(
            vec2(a.x / a.z, a.y / a.z),
            vec2(b.x / b.z, b.y / b.z),
            vec2(c.x / c.z, c.y / c.z),
            vec2(d.x / d.z, d.y / d.z),
            color, edgeFactor
        );
    }

    struct Algorithms {
        static vec2 invert (vec2 v) {
            return vec2(-v.y, v.x);
        }
        static vec2 getMiterOffset (vec2 left, vec2 pt, vec2 right, float width, float cutoff) {
            auto a = pt - left;  a.normalize();       // relative angles
            auto b = right - pt; b.normalize();

            if (dot(a, b) > cutoff) {
                auto miter = (a + b); miter.normalize(); // miter vector (half-interp between a, b)
                auto costheta = dot(a, miter);           // cos(half angle between a, b)

                miter *= width / costheta;
                return invert(miter);
            
            } else {
                return dot(a, b) >= 0 ?
                    a * width : 
                    a * -width;
            }
        }

        static void pushMiterPoints (ref vec2[] output, vec2 left, vec2 pt, vec2 right, float width, float cutoff) {
            auto offset = getMiterOffset(left, pt, right, width, cutoff);

            output ~= pt + offset;
            output ~= pt - offset;
        }

        static void pushRegularLineCap (ref vec2[] output, vec2 a, vec2 b, float width) {
            auto dir = invert(b - a).normalized();

            output ~= a + dir * width;
            output ~= a - dir * width;
        }

        // original algorithm (dunno what I was thinking when I wrote this, as it's _significantly_
        // more complex than the geometrical approach (this one calculates line-line intersections),
        // but it does work)
        static vec2[2] getMiterOffsetUsingIntersects (vec2 left, vec2 pt, vec2 right, float width, float cutoff) {
            vec2 v1 = invert(left  - pt) * width / distance(left, pt);
            vec2 v2 = invert(right - pt) * width / distance(right, pt);

            vec3 intersect (real a1, real b1, real c1, real a2, real b2, real c2) {
                return vec3(
                    cast(float)(b1 * c2 - b2 * c1),
                    cast(float)(a2 * c1 - a1 * c2),
                    cast(float)(a2 * b1 - a1 * b2));
            }

            float k1 = (left.x  - pt.x) / (pt.y - left.y);
            float k2 = (right.x - pt.x) / (pt.y - right.y);

            auto pt1 = intersect(1.0, k1, pt.x + v1.x + k1 * (pt.y + v1.y),
                                 1.0, k2, pt.x - v2.x + k2 * (pt.y - v2.y));

            auto pt2 = intersect(1.0, k1, pt.x - v1.x + k1 * (pt.y - v1.y),
                                 1.0, k2, pt.x + v2.x + k2 * (pt.y + v2.y));

            vec2 r1 = pt - left; r1.normalize();
            vec2 r2 = right - pt; r2.normalize();

            if (dot(r1, r2) > cutoff) {
                return [
                    vec2(pt1.x / pt1.z, pt1.x / pt1.z),
                    vec2(pt2.x / pt2.z, pt2.x / pt2.z),
                ];
            } else {
                auto dir = invert(pt - left);
                dir *= width / dir.magnitude();
                return dot(r1, r2) >= 0 ?
                    [ pt + dir, pt - dir ] :
                    [ pt - dir, pt + dir ];
            }
        }
    }

    // temp buffer used by drawLines
    private vec2[] tbuf;

    void drawLines (vec2[] points, Color color, float width, float edgeSamples = 2.0, float angle_cutoff = 15.0) {
        synchronized {
            float packedColor = color.toPackedFloat();

            import std.math: PI, cos;
            float cutoff = -cos(angle_cutoff * PI / 180.0);

            // Note: edgeSamples is recommended to to be in [0, 2] for retina resolutions (2x scale factor), 
            // or [0, 4] for nonretina (1x). 0 = no samples (jagged edges), 2/4 = smooth (visually optimal).
            // 1/2 is inbetween, and above 2/4 the lines become noticably blurry.
            // We _have_ minimized apparent size changes though (lines appear to be the same width at all 
            // sample values < ~10); this is why we do sqrt(edgeSamples * 4.0) here, and dist * dist in the
            // fragment shader.
            width = abs(width) + sqrt(edgeSamples * 4.0);// + edgeSamples * 2.0;

            tbuf.length = 0;
            if (points.length >= 2) {
                {
                    // Push front cap (find first non-duplicated point pair and push that)
                    size_t i = 1;
                    while (i < points.length && points[i] == points[0]) 
                        ++i;
                    if (i >= points.length)
                        return;

                    Algorithms.pushRegularLineCap(tbuf, points[0], points[i], width);

                    // Push intermediate points
                    for (; i < points.length-1; ++i) {
                        if (points[i] == points[i-1])
                            continue;

                        Algorithms.pushMiterPoints(tbuf, points[i-1], points[i], points[i+1], width, cutoff);
                    }

                    // Push end cap
                    Algorithms.pushRegularLineCap(tbuf, points[i], points[i-1], width);
                    import std.algorithm.mutation: swap;
                    swap(tbuf[$-1], tbuf[$-2]);
                }

                // Push quads
                float edgeFactor = 1.0 + edgeSamples / (width - edgeSamples * 1.0);
                for (auto i = tbuf.length; i >= 4; i -= 2) {
                    pushQuad(tbuf[i-4], tbuf[i-3], tbuf[i-2], tbuf[i-1], packedColor, edgeFactor);
                }
            }
        }
    }
    void drawTri (vec2 pt, Color color, float size, float edgeSamples = 2.0) {
        import std.math: sqrt;
        immutable float k = 1 / sqrt(3.0);

        float packedColor = color.toPackedFloat();
        synchronized {
            //states[fstate].vbuffer ~= [
            //    pt.x,              pt.y + k * size,       0.0, packedColor,
            //    pt.x + 0.5 * size, pt.y - k * size * 0.5, 0.0, packedColor,
            //    pt.x - 0.5 * size, pt.y - k * size * 0.5, 0.0, packedColor,
            //];

            float edgeFactor = 1.0 + edgeSamples / (size - edgeSamples);
            float[6] verts = [
                pt.x,              pt.y + k * size,      
                pt.x + 0.5 * size, pt.y - k * size * 0.5,
                pt.x - 0.5 * size, pt.y - k * size * 0.5,
            ];
            states[fstate].vbuffer ~= [
                verts[0], verts[1], edgeFactor, packedColor + 40 / 255.0,
                verts[2], verts[3], edgeFactor, packedColor + 40 / 255.0,
                pt.x,     pt.y,    0, packedColor + 40 / 255.0,

                verts[2], verts[3], edgeFactor, packedColor + 40 / (255.0 * 255.0),
                verts[4], verts[5], edgeFactor, packedColor + 40 / (255.0 * 255.0),
                pt.x,     pt.y,    0, packedColor + 40 / (255.0 * 255.0),

                verts[4], verts[5], edgeFactor, packedColor + 40 / (255.0 * 255.0 * 255.0),
                verts[0], verts[1], edgeFactor, packedColor + 40 / (255.0 * 255.0 * 255.0),
                pt.x,     pt.y,    0, packedColor + 40 / (255.0 * 255.0 * 255.0),
            ];
        }
    }

    ColoredFragmentShader fs = null;
    ColoredVertexShader   vs = null;
    Program!(ColoredVertexShader,ColoredFragmentShader) program = null;
    void renderFromGraphicsThread () {
        synchronized {
            if (fstate) fstate = 0, gstate = 1;
            else        fstate = 1, gstate = 0;
            states[fstate].vbuffer.length = 0;
        }

        if (states[gstate].vbuffer.length) {
            if (!program) {
                fs = new ColoredFragmentShader(); fs.compile(); CHECK_CALL("compiling fragment shader");
                vs = new ColoredVertexShader(); vs.compile(); CHECK_CALL("compiling vertex shader");
                program = makeProgram(vs, fs); CHECK_CALL("compiling/linking shader program");
            }
            checked_glUseProgram(program.id);
            auto inv_scale_x =  1.0 / g_mainWindow.screenDimensions.x * 2.0;
            auto inv_scale_y = -1.0 / g_mainWindow.screenDimensions.y * 2.0;
            auto transform = mat4.identity()
                .scale(inv_scale_x, inv_scale_y, 1.0)
                .translate(-1.0, 1.0, 0.0);
            transform.transpose();
            program.transform = transform;

            states[gstate].render(transform);
            checked_glUseProgram(0);
        }
    }
}






































































