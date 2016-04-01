
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

import std.algorithm.comparison;
import std.math;

import core.sync.mutex;
import std.traits;

mixin Color.fract;

alias uivec4 = Vector!(uint, 4);

private class PalettedVertexShader : Shader!Vertex {
    @layout(location = 0)
    @input vec3 position;

    @layout(location = 1)
    @input int index;

    @output vec4 color;
    @uniform mat4 transform;
    @uniform samplerBuffer paletteSampler;

    void main () {
        color = texelFetch(paletteSampler, index);
        gl_Position = transform * vec4(position.xyz, 1.0);
    }
}
private class PalettedFragmentShader : Shader!Fragment {
    @input  vec4 color;
    @output vec4 fragColor;

    void main () {
        fragColor = color;
    }
}

private class BasicVertexShader : Shader!Vertex {
    @layout(location = 0)
    @input vec4 inPos;

    @layout(location = 1)
    @input vec4 inColor;

    @output vec4 color;
    @uniform mat4 transform;
    @uniform samplerBuffer paletteSampler;

    void main () {
        color = inColor;
        gl_Position = transform * inPos;
    }
}
private class BasicFragmentShader : Shader!Fragment {
    @input  vec4 color;
    @output vec4 fragColor;

    void main () {
        fragColor = color;
    }
}

private class ColoredVertexShader: Shader!Vertex {
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
private class ColoredFragmentShader: Shader!Fragment {
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

struct ColorPaletteCache {
    // Two algorithms for this; dunno which is faster. 
    // (linear lookup on dozens to _maybe_ several hundred elements vs hashing)

    alias ColorRGBA = vec4;
    protected struct Palette_linearLookup {
        ColorRGBA[] palette;

        uint getIndex (ColorRGBA color) {
            foreach (i, v; palette)
                if (v == color)
                    return cast(uint)i;
            palette ~= color;
            return cast(uint)palette.length - 1;
        }
        ColorRGBA[] getColorData () { 
            return palette; 
        }
        void clear () { palette.length = 0; }
    }
    //protected struct Palette_hashedLookup {
    //    ColorRGBA[] palette;
    //    uint[ColorRGBA] lookup;

    //    uint getIndex (ColorRGBA color) { 
    //        if (color !in lookup) {
    //            lookup[color] = cast(uint)palette.length;
    //            palette ~= color;
    //        }
    //        return lookup[color];
    //    }
    //    ColorRGBA[] getColorData () {
    //        return palette;
    //    }
    //    void clear () { 
    //        palette.length = 0; 
    //        foreach (key; lookup.keys())
    //            lookup.remove(key);
    //    }
    //}
    alias Palette = Palette_linearLookup;

    private immutable uint NUM_STATES = 3;

    private Palette[NUM_STATES] palettes; 
    private uint gthreadCurrent = 0, mthreadCurrent = 1;
    public BufferTexture texture = null;

    //private uint textureWidth = 256; // changed iff texture size gets really large; usually only the v dimension changes.
    // Main thread functions
    ushort getCoord (Color color) {
        return cast(ushort)palettes[mthreadCurrent].getIndex(color.components);
    }
    //{
    //    auto index = palettes[mthreadCurrent].getIndex(color.getBGRA());
    //    return vec2i(index % textureWidth, index / textureWidth);
    //}
    void swapState () {
        mthreadCurrent = (mthreadCurrent + 1) % NUM_STATES;
        assert(mthreadCurrent != gthreadCurrent);
    }

    // Graphics thread functions
    void updateTextureAndSwapState (uint textureUnit, BufferTexture texture) {
        auto lastState = gthreadCurrent;
        auto nextState = gthreadCurrent = (gthreadCurrent + 1) % NUM_STATES;
        assert(gthreadCurrent != mthreadCurrent);

        import std.algorithm.iteration;

        if (!equal(palettes[nextState].getColorData, palettes[lastState].getColorData) || !texture) {
            if (!texture)
                texture = new BufferTexture();
            texture.setData(textureUnit, GL_RGBA32F, palettes[nextState].getColorData());
            //log.write("using %d colors: %s", palettes[nextState].getColorData().length,
                //palettes[nextState].getColorData().map!((v) => format("%s", v)).join(", "));
        }//} else {
            log.write("using %d colors: %s", palettes[nextState].getColorData().length,
                palettes[nextState].getColorData().map!((v) => format("%s", v)).join(", "));
        //}
    }
    void release () {
        if (texture) {
            texture.release();
            texture = null;
        }
    }

    //void updateTextureAndSwapState (BufferTexture texture) {
    //    auto lastState = gthreadCurrent;
    //    auto nextState = gthreadCurrent = (gthreadCurrent + 1) % NUM_STATES;

    //    if (!equal(palettes[nextState].getColorData(), palettes[lastState].getColorData())) {

    //        auto textureData = palettes[nextState].getColorData();
    //        immutable ColorRGBA[1] emptyValue;

    //        // Calculate texture height. Note: as a special case, if palette is empty we'll set height to 1
    //        // and fill using filler values (since even if pallete is empty, not creating / uploading texture
    //        // would be a bug).
    //        auto textureHeight = textureData.length ?
    //            (textureData.length - 1) / textureWidth + 1 : 1;

    //        // Append values to texture data to fill full W x H array.
    //        auto filler = textureWidth - textureData.length % textureWidth;
    //        if (filler)
    //            textureData ~= cycle(emptyValue).take(filler).array;

    //        // set texture values (they're cached by the texture object, so they don't really get reset 
    //        // every frame; this state effectively only gets set _once_), and upload palette data to the gpu.
    //        texture.bind(GL_TEXTURE_2D, GL_TEXTURE0);
    //        texture.setFiltering(GL_NEAREST);
    //        texture.setSampling(GL_CLAMP_TO_BORDER);
    //        //texture.setBorderColor([ 1.0f, 0.0f, 1.0f, 1.0f ]);
    //        texture.setData(0, 0, textureWidth, textureHeight, textureData);
    //    } else {
    //        log.write("Retaining last state (gthread current = %d, last = %d, mt = %d)",
    //            nextState, lastState, current);
    //    }
    //}
}

@property auto DebugRenderer () { return DebugLineRenderer2D.instance; }
class DebugLineRenderer2D {
    mixin LowLockSingleton;

    protected struct State {
        //GLuint vao = 0;
        //GLuint[1] buffers;
        float[]   vbuffer;
        auto vao = new VAO();

        struct VArray (GLenum prim, T) {
            T[] data;
            auto vao = new VAO();
            void draw (VertexAttrib[] attribs) {
                if (data.length) {
                    DynamicRenderer.drawArrays(vao, prim, 0, cast(int)data.length, [
                        VertexData(data.ptr, data.length * T.sizeof, attribs)
                    ]);
                }
            }
        }
        VArray!(GL_TRIANGLES, PackedVertex_palettedColor) palettedTris;
        protected void drawPaletted () {
            palettedTris.draw([
                VertexAttrib(0, 3, GL_FLOAT, GL_FALSE, PackedVertex_palettedColor.sizeof, cast(void*)(0)),
                VertexAttrib(1, 1, GL_INT,   GL_FALSE, PackedVertex_palettedColor.sizeof, cast(void*)(float.sizeof * 3)),
            ]);
        }

        VArray!(GL_TRIANGLES, PackedVertex_attribColor) attribTris;
        protected void drawAttribTris () {
            attribTris.draw([
                VertexAttrib(0, 4, GL_FLOAT, GL_FALSE, PackedVertex_attribColor.sizeof, cast(void*)(0)),
                VertexAttrib(1, 4, GL_FLOAT, GL_FALSE, PackedVertex_attribColor.sizeof, cast(void*)(float.sizeof * 4)),
            ]);
        }

        protected void clearForNextFrame () {
            attribTris.data.length = 0;
            palettedTris.data.length = 0;
        }

        //protected void render (ref mat4 transform) {
        //    if (!vbuffer.length)
        //        return;

        //    glState.enableDepthTest(false);
        //    glState.enableTransparency(true);

        //    //DynamicRenderer.drawArrays(vao, GL_TRIANGLES, 0, cast(int)vbuffer.length / 4, [
        //    //    VertexData(vbuffer.ptr, vbuffer.length * float.sizeof, [
        //    //        VertexAttrib(0, 4, GL_FLOAT, GL_FALSE, 0, null)
        //    //    ])
        //    //]);

        //    //if (tris) {
        //    //    DynamicRenderer.drawArrays(triVao, GL_TRIANGLES, 0, cast(int)tris.length, [
        //    //        VertexData(tris.ptr, tris.length * PackedVertexData.sizeof, [
        //    //            VertexAttrib(0, 3, GL_FLOAT,        GL_FALSE, PackedVertexData.sizeof, cast(void*)(0)),
        //    //            VertexAttrib(1, 1, GL_UNSIGNED_INT, GL_FALSE, PackedVertexData.sizeof, cast(void*)(float.sizeof * 3)),
        //    //        ])
        //    //    ]);
        //    //}
        //}

        protected void releaseResources () {
            vao.release();
        }
    }
    private State[2] states;
    private int fstate = 0, gstate = 1;
    private auto palette = new ColorPaletteCache();
    private auto paletteTexture = new BufferTexture();

    struct PackedVertex_palettedColor {
        float x, y, z; int colorIndex;
    }

    struct PackedVertex_attribColor {
        float x, y, z, w, r, g, b, a;
    }


    void mainThread_onFrameEnd () {
        //palette.swapState();
    }

    private void pushQuad (vec2 a, vec2 b, vec2 c, vec2 d, Color color) {
        // super inefficient, but hopefully this works...
        states[fstate].attribTris.data ~= [
            PackedVertex_attribColor(a.x, a.y, 0, 1, color.r, color.g, color.b, color.a),
            PackedVertex_attribColor(b.x, b.y, 0, 1, color.r, color.g, color.b, color.a),
            PackedVertex_attribColor(d.x, d.y, 0, 1, color.r, color.g, color.b, color.a),

            PackedVertex_attribColor(a.x, a.y, 0, 1, color.r, color.g, color.b, color.a),
            PackedVertex_attribColor(d.x, d.y, 0, 1, color.r, color.g, color.b, color.a),
            PackedVertex_attribColor(c.x, c.y, 0, 1, color.r, color.g, color.b, color.a),
        ];
    }

    //private void pushQuad (vec2 a, vec2 b, vec2 c, vec2 d, Color color) {
    //    auto index = cast(int)palette.getCoord(color);
    //    states[fstate].palettedTris.data ~= [
    //        PackedVertex_palettedColor(a.x, a.y, 0, index),
    //        PackedVertex_palettedColor(b.x, b.y, 0, index),
    //        PackedVertex_palettedColor(d.x, d.y, 0, index),

    //        PackedVertex_palettedColor(a.x, a.y, 0, index),
    //        PackedVertex_palettedColor(d.x, d.y, 0, index),
    //        PackedVertex_palettedColor(c.x, c.y, 0, index),
    //    ];
    //}

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
        static void pushMiterPoints (ref vec2[] output, vec2 left, vec2 pt, vec2 right, float width, float cutoff) {
            auto a = pt - left;  a.normalize();       // relative angles
            auto b = right - pt; b.normalize();

            if (dot(a, b) > cutoff) {
                auto miter = (a + b); miter.normalize(); // miter vector (half-interp between a, b)
                auto costheta = dot(a, miter);           // cos(half angle between a, b)

                miter = invert(miter);
                miter *= width / costheta;

                output ~= pt + miter;
                output ~= pt - miter;

            } else {
                auto offset = invert(a) * width;

                output ~= pt + offset;
                output ~= pt - offset;

                // bowtie fix
                if (dot(a, b) < 0) {
                    output ~= pt - offset;
                    output ~= pt + offset;
                }
            }
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

    void drawLines (vec2[] points, Color color, float width, float edgeSamples = 1.0, float angle_cutoff = 15.0) {
        synchronized {
            //float packedColor = color.toPackedFloat();

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
                //float edgeFactor = 1.0 + edgeSamples / (width - edgeSamples * 1.0);
                for (auto i = tbuf.length; i >= 4; i -= 2) {
                    //pushQuad(tbuf[i-4], tbuf[i-3], tbuf[i-2], tbuf[i-1], packedColor, edgeFactor);
                    pushQuad(tbuf[i-4], tbuf[i-3], tbuf[i-2], tbuf[i-1], color);
                }
            }
        }
    }
    void drawPolygon (vec2[] points, Color color, float width, float edgeSamples = 1.0, float angle_cutoff = 15.0) {
        synchronized {
            import std.math: PI, cos;
            float cutoff = -cos(angle_cutoff * PI / 180.0);
            width = abs(width) + sqrt(edgeSamples) * 2.0;
            tbuf.length = 0;
            if (points.length >= 3) {
                // Note: no duplicate filtering
                Algorithms.pushMiterPoints(tbuf, points[$-2], points[$-1], points[0], width, cutoff);
                Algorithms.pushMiterPoints(tbuf, points[$-1], points[0], points[1], width, cutoff);
                for (size_t i = 0; i < points.length - 2; ++i) {
                    Algorithms.pushMiterPoints(tbuf, points[i], points[i+1], points[i+2], width, cutoff);
                }
                assert(tbuf.length == 2 * points.length);

                // Push geometry
                for (auto i = tbuf.length; i >= 4; i -= 2) {
                    pushQuad(tbuf[i-4], tbuf[i-3], tbuf[i-2], tbuf[i-1], color);
                }
                pushQuad(tbuf[$-2], tbuf[$-1], tbuf[0], tbuf[1], color);
            } else {
                throw new Exception(format("drawPolygon requires > 3 points (not %d: %s)", points.length, points));
            }
        }
    }

    void drawCircle (vec2 center, float radius, Color color, float width, uint numPoints = 80, float samples = 1.0) {
        vec2[] points;
        foreach (i; 0 .. numPoints) {
            points ~= vec2(
                center.x + radius * cos(PI * 2 * cast(float)i / cast(float)numPoints),
                center.y + radius * sin(PI * 2 * cast(float)i / cast(float)numPoints));
        }
        drawPolygon(points, color, width, samples);
        //drawLineRect(center - vec2(radius, radius), center + vec2(radius, radius), color, width, samples);
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
            //states[fstate].vbuffer ~= [
            //    verts[0], verts[1], edgeFactor, packedColor + 40 / 255.0,
            //    verts[2], verts[3], edgeFactor, packedColor + 40 / 255.0,
            //    pt.x,     pt.y,    0, packedColor + 40 / 255.0,

            //    verts[2], verts[3], edgeFactor, packedColor + 40 / (255.0 * 255.0),
            //    verts[4], verts[5], edgeFactor, packedColor + 40 / (255.0 * 255.0),
            //    pt.x,     pt.y,    0, packedColor + 40 / (255.0 * 255.0),

            //    verts[4], verts[5], edgeFactor, packedColor + 40 / (255.0 * 255.0 * 255.0),
            //    verts[0], verts[1], edgeFactor, packedColor + 40 / (255.0 * 255.0 * 255.0),
            //    pt.x,     pt.y,    0, packedColor + 40 / (255.0 * 255.0 * 255.0),
            //];
        }
    }
    void drawRect (vec2 a, vec2 b, Color color) {
        //pushQuad(vec2(a.x, a.y), vec2(b.x, a.y), vec2(b.x, b.y), vec2(a.x, b.y), color.toPackedFloat(), 1.0);
        pushQuad(vec2(a.x, a.y), vec2(b.x, a.y), vec2(a.x, b.y), vec2(b.x, b.y), color);
    }
    void drawLineRect (vec2 a, vec2 b, Color color, float width, float samples = 1.0, float cutoff = 15.0) {
        drawPolygon([ vec2(a.x, a.y), vec2(b.x, a.y), vec2(b.x, b.y), vec2(a.x, b.y) ],
            color, width, samples, cutoff);
    }

    struct Shader(Fragment, Vertex) {
        Vertex   vertex   = null;
        Fragment fragment = null;
        Program!(Vertex, Fragment) program = null;

        void bind () {
            if (!program) {
                vertex   = new Vertex(); vertex.compile(); CHECK_CALL(format("compiling %s", fullyQualifiedName!Vertex));
                fragment = new Fragment(); fragment.compile(); CHECK_CALL(format("compiling %s", fullyQualifiedName!Fragment));
                program = makeProgram(vertex, fragment); CHECK_CALL(format("compling / linking %s, %s", fullyQualifiedName!Vertex, fullyQualifiedName!Fragment));
            }
            glState.bindShader(program.id);
        }
        alias program this;
    }

    Shader!(ColoredFragmentShader, ColoredVertexShader) oldShader;
    Shader!(PalettedFragmentShader, PalettedVertexShader) paletteShader;
    Shader!(BasicFragmentShader, BasicVertexShader) basicShader;

    //ColoredFragmentShader fs = null;
    //ColoredVertexShader   vs = null;
    //Program!(ColoredVertexShader,ColoredFragmentShader) program = null;
    void renderFromGraphicsThread () {
        //log.write("rendering!");

        synchronized {
            if (fstate) fstate = 0, gstate = 1;
            else        fstate = 1, gstate = 0;

            states[fstate].clearForNextFrame();
            //states[fstate].vbuffer.length = 0;
        }

        //paletteTexture.bind(GL_TEXTURE0);
        //palette.updateTextureAndSwapState(GL_TEXTURE0, paletteTexture);

        //paletteShader.bind();
        //paletteShader.transform = g_mainWindow.screenSpaceTransform(true);
        //paletteShader.paletteSampler   = GL_TEXTURE0;
        //states[gstate].drawPaletted();

        glState.enableTransparency(true);
        glState.enableDepthTest(true, GL_LEQUAL);

        basicShader.bind();
        basicShader.transform = g_mainWindow.screenSpaceTransform(true);
        states[gstate].drawAttribTris();

        glState.bindShader(0);


        //if (states[gstate].vbuffer.length) {
        //    //if (!program) {
        //    //    fs = new ColoredFragmentShader(); fs.compile(); CHECK_CALL("compiling fragment shader");
        //    //    vs = new ColoredVertexShader(); vs.compile(); CHECK_CALL("compiling vertex shader");
        //    //    program = makeProgram(vs, fs); CHECK_CALL("compiling/linking shader program");
        //    //}
        //    //glState.bindShader(program.id);

        //    oldShader.bind();
        //    oldShader.transform = g_mainWindow.screenSpaceTransform(true);
        //    auto transform = g_mainWindow.screenSpaceTransform(false); // non-transposed
        //    states[gstate].render(transform);
        //    glState.bindShader(0);
        //}
    }
}






































































