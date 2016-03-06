
module gsb.gl.debugrenderer;
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
        GLuint vao = 0;
        GLuint[1] buffers;
        float[]   vbuffer;

        protected void render (ref mat4 transform) {
            if (!vbuffer.length)
                return;

            if (!vao) {
                checked_glGenVertexArrays(1, &vao);
                checked_glGenBuffers(1, buffers.ptr);
                checked_glBindVertexArray(vao);

                checked_glEnableVertexAttribArray(0);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, vbuffer.length * 4, vbuffer.ptr, GL_STREAM_DRAW);
                checked_glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, null);
            } else {
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, vbuffer.length * 4, vbuffer.ptr, GL_STREAM_DRAW);
            }

            checked_glBindVertexArray(vao);

            glDisable(GL_DEPTH_TEST);
            checked_glDrawArrays(GL_TRIANGLES, 0, cast(int)vbuffer.length / 4);
            glEnable(GL_DEPTH_TEST);

            //string s = "";
            //for (uint i = 0; i < vbuffer.length; i += 4) {
            //    auto v = vec4(vbuffer[i],vbuffer[i+1],vbuffer[i+2],1.0) * transform;
            //    s ~= format("(%0.2f, %0.2f, %0.2f, color=%s), ", v.x, v.y, v.z, Color.unpack(vbuffer[i+3]));
            //}
            //log.write("Drawing stuff: %s", s);

        }
        protected void releaseResources () {
            if (vao) {
                checked_glDeleteVertexArrays(1, &vao);
                checked_glDeleteBuffers(1, buffers.ptr);
                vao = 0;
            }
        }
    }
    private State[2] states;
    private int fstate = 0, gstate = 1;

    private void pushQuad (vec2 a, vec2 b, vec2 c, vec2 d, float color, float edgeFactor) {
        states[fstate].vbuffer ~= [
            a.x, a.y, +edgeFactor, color,
            b.x, b.y, -edgeFactor, color,
            d.x, d.y, -edgeFactor, color,

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

    // temp buffer used by drawLines
    private vec3[] tbuf;

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
                vec2 dir;

                // Push front cap
                dir = points[1] != points[0] ?
                    points[1] - points[0] : points[0] + vec2(1e-3, 0);
                dir = points[1] - points[0];
                dir *= width * 0.5 / dir.magnitude();
                tbuf ~= vec3(points[0].x - dir.y, points[0].y + dir.x, 1.0);
                tbuf ~= vec3(points[0].x + dir.y, points[0].y - dir.x, 1.0);    

                // Push intermediate points
                for (auto i = 1; i < points.length-1; ++i) {
                    if (points[i] == points[i-1])
                        continue;

                    vec2 v1 = vec2(points[i-1].y - points[i].y, points[i].x - points[i-1].x) * width * 0.5 / distance(points[i], points[i-1]);
                    vec2 v2 = vec2(points[i+1].y - points[i].y, points[i].x - points[i+1].x) * width * 0.5 / distance(points[i], points[i+1]);

                    vec3 intersect (real a1, real b1, real c1, real a2, real b2, real c2) {
                        return vec3(
                            cast(float)(b1 * c2 - b2 * c1),
                            cast(float)(a2 * c1 - a1 * c2),
                            cast(float)(a2 * b1 - a1 * b2));
                    }

                    float k1 = (points[i-1].x - points[i].x) / (points[i].y - points[i-1].y);
                    float k2 = (points[i+1].x - points[i].x) / (points[i].y - points[i+1].y);

                    auto pt1 = intersect(1.0, k1, points[i].x + v1.x + k1 * (points[i].y + v1.y),
                                         1.0, k2, points[i].x - v2.x + k2 * (points[i].y - v2.y));

                    auto pt2 = intersect(1.0, k1, points[i].x - v1.x + k1 * (points[i].y - v1.y),
                                         1.0, k2, points[i].x + v2.x + k2 * (points[i].y + v2.y));
                   
                    vec2 r1 = points[i] - points[i-1]; r1 /= r1.magnitude();
                    vec2 r2 = points[i+1] - points[i]; r2 /= r2.magnitude();

                    if (dot(r1, r2) > cutoff) {
                        tbuf ~= pt1;
                        tbuf ~= pt2;
                    } else {
                        dir = points[i] - points[i-1];
                        dir *= width * 0.5 / dir.magnitude();
                        tbuf ~= vec3(points[i].x - dir.y, points[i].y + dir.x, 1.0); 
                        tbuf ~= vec3(points[i].x + dir.y, points[i].y - dir.x, 1.0);
                        if (dot(r1,r2) < 0) {
                            tbuf ~= vec3(points[i].x + dir.y, points[i].y - dir.x, 1.0);
                            tbuf ~= vec3(points[i].x - dir.y, points[i].y + dir.x, 1.0); 
                        }
                    }
                }

                // Push end cap
                dir = points[$-1] - points[$-2];
                dir *= width * 0.5 / dir.magnitude();
                tbuf ~= vec3(points[$-1].x - dir.y, points[$-1].y + dir.x, 1.0);
                tbuf ~= vec3(points[$-1].x + dir.y, points[$-1].y - dir.x, 1.0);

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






































































