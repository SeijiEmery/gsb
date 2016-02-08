
module gsb.text.textrendertest;
import gsb.text.textrenderer;
import std.stdio;
import std.file;
import std.utf;
import std.container.rbtree;


import gsb.glutils;

import stb.truetype;
import derelict.opengl3.gl3;
import dglsl;


private class VertexShader : Shader!Vertex {
    @layout(location=0)
    @input vec3 textPosition;

    @layout(location=1)
    @input vec2 texCoordIn;

    @output vec2 texCoord;

    @uniform mat4 transform;

    void main () {
        gl_Position = transform * vec4(textPosition, 1.0);
        texCoord = texCoordIn;
    }
}
private class FragmentShader : Shader!Fragment {
    @input vec2 texCoord;
    @output vec4 fragColor;

    @uniform sampler2D textureSampler;

    void main () {
        vec4 color = texture(textureSampler, texCoord);

        //fragColor = color.r > 0.1 ?
        //    vec4(color.r) :
        //    vec4(0.5, 1.0, 0.5, 1.0);

        fragColor = vec4(color.r);
    }
}

class StbTextRenderTest {
    public string fontPath = "/Library/Fonts/Arial Unifoob.ttf";
    public int BITMAP_WIDTH = 1024, BITMAP_HEIGHT = 1024;
    public float fontSize = 40; // in pixels
    float fontScale;
    float fontBaseline;

    uint[3] gl_vbos;
    uint    gl_vao = 0;
    uint    gl_texture = 0;
    Program!(VertexShader, FragmentShader) shader = null;
    uint ntriangles = 0;

    // debug
    auto fullScreenQuad = new FullScreenTexturedQuad();
    static immutable bool RENDER_FULLSCREEN_QUAD = true;

    public void setText (string text) {
        if (__ctfe) 
            return;

        writeln("Starting StbTextRenderTest");

        // Load font
        if (!exists(fontPath) || (!attrIsFile(getAttributes(fontPath))))
            throw new ResourceError("Cannot load font file '%s'", fontPath);

        auto fontData = cast(ubyte[])read(fontPath);
        if (fontData.length == 0)
            throw new ResourceError("Failed to load font file '%s'", fontPath);

        stbtt_fontinfo fontInfo;
        if (!stbtt_InitFont(&fontInfo, fontData.ptr, 0))
            throw new ResourceError("stb: Failed to load font '%s'");

        fontScale = stbtt_ScaleForPixelHeight(&fontInfo, fontSize);
        writefln("Font scale = %0.2f", fontScale);
        int ascent;
        stbtt_GetFontVMetrics(&fontInfo, &ascent, null, null);
        fontBaseline = ascent * fontScale;

        // Determine charset
        auto rbcharset = new RedBlackTree!dchar();
        foreach (chr; byDchar(text))
            rbcharset.insert(chr);
        writef("charset: ");
        foreach (chr; rbcharset)
            writef("%c, ", chr);
        writef("\n");

        // Convert charset to an array and create lookup table
        dchar[] charset;
        int[dchar] chrLookup;
        {
            int i = 0;
            writef("Text := ");
            foreach (chr; rbcharset) {
                charset ~= chr;
                chrLookup[chr] = i++;
                writef("%c", chr);
            }
            writefln(" (%d)", i);
        }

        // Create bitmap + pack chars
        ubyte[] bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * 1];

        stbtt_pack_context pck;
        stbtt_PackBegin(&pck, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, cast(void*)null);

        auto packedChrData = new stbtt_packedchar[ charset.length ];

        // Pack charset
        stbtt_pack_range r;
        r.font_size = fontScale;
        r.first_unicode_codepoint_in_range = 0;
        r.array_of_unicode_codepoints = cast(int*)charset.ptr;
        r.num_chars = cast(int)charset.length;
        r.chardata_for_range = packedChrData.ptr;

        stbtt_PackSetOversampling(&pck, 1, 1);
        stbtt_PackFontRanges(&pck, fontData.ptr, 0, &r, 1);
        stbtt_PackEnd(&pck);

        // Render to quads
        static if (RENDER_FULLSCREEN_QUAD)        
            float[] quads = [ 
                0, 0, 0,     //-1, -1, 0, 
                800, 600, 0, //+1, +1, 0, 
                800, 0, 0, //+1, -1, 0,

                0, 0, 0, //-1, -1, 0,
                0, 600, 0, //-1, +1, 0,
                800, 600, 0,//+1, +1, 0,
            ];
        else
            float[] quads;

        // UVs are flipped since stb_truetype uses flipped y-coords
        static if (RENDER_FULLSCREEN_QUAD)
            float[] uvs   = [ 
                0, 1,
                1, 0,
                1, 1,

                0, 1,
                0, 0,
                1, 0
            ];
        else
            float[] uvs;

        int pw = BITMAP_WIDTH, ph = BITMAP_HEIGHT;
        //int pw = 800, ph = 600;
        float x = 0, y = 0;
        bool align_to_integer = false;
        foreach (chr; text.byDchar()) {
            if (chr == '\n') {
                x = 0;
                y += fontScale * 1.4;
            } else {
                stbtt_aligned_quad q;
                stbtt_GetPackedQuad(packedChrData.ptr, pw, ph, chrLookup[chr], &x, &y, &q, align_to_integer);
                writefln("Encoding %c (%d) => quad (%0.2f,%0.2f),(%0.2f,%0.2f) at (%0.2f,%0.2f)", chr, chrLookup[chr], q.x0, q.y0, q.x1, q.y1, x, y);

                // Push geometry
                quads ~= [
                    q.x0, q.y0, 0.0,
                    q.x1, q.y1, 0.0,
                    q.x1, q.y0, 0.0,

                    q.x0, q.y0, 0.0,
                    q.x0, q.y1, 0.0,
                    q.x1, q.y1, 0.0,
                ];
                uvs ~= [
                    q.s0, q.t1,
                    q.s1, q.t0,
                    q.s1, q.t1,

                    q.s0, q.t1,
                    q.s0, q.t0,
                    q.s1, q.t0
                ];
            }
        }

        // Create gl resources
        if (!gl_vao) {
            glGenVertexArrays(1, &gl_vao); CHECK_CALL("glGenVertexArrays");
            glBindVertexArray(gl_vao);

            glGenBuffers(3, gl_vbos.ptr); CHECK_CALL("glGenBuffers");

            glEnableVertexAttribArray(0); CHECK_CALL("glEnableVertexAttribArray");
            glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[0]); CHECK_CALL("glBindBuffer");
            glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

            glEnableVertexAttribArray(1); CHECK_CALL("glEnableVertexAttribArray");
            glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[1]); CHECK_CALL("glBindBuffer");
            glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

            glEnableVertexAttribArray(2); CHECK_CALL("glEnableVertexAttribArray");
            glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[2]); CHECK_CALL("glBindBuffer");
            glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

            glBindVertexArray(0); CHECK_CALL("glBindVertexArray(0)");
        }
        if (!gl_texture) {
            glGenTextures(1, &gl_texture); CHECK_CALL("glGenTexture");
        }
        if (!shader) {
            auto vs = new VertexShader(); vs.compile(); CHECK_CALL("vs.compile()");
            auto fs = new FragmentShader(); fs.compile(); CHECK_CALL("fs.compile()");
            shader = new Program!(VertexShader,FragmentShader)(vs,fs); CHECK_CALL("makeProgram!(vs,fs)");
            //shader = makeProgram!(vs, fs); CHECK_CALL("makeProgram!(vs, fs)");

            glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
            glBindTexture(GL_TEXTURE_2D, gl_texture); CHECK_CALL("glBindTexture");
            //shader.textureSampler = 0; CHECK_CALL("shader.textureSampler = 0");
            auto loc = glGetUniformLocation(shader.id, "textureSampler"); CHECK_CALL("glGetUniformLocation");
            glUniform1i(loc, 0); CHECK_CALL("glUniform1i (setting texture sampler = 0)");
        }

        // Upload bitmap to gpu
        glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
        glBindTexture(GL_TEXTURE_2D, gl_texture); CHECK_CALL("glBindTexture");
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, BITMAP_WIDTH, BITMAP_HEIGHT, 0, GL_RED, GL_UNSIGNED_BYTE, bitmapData.ptr); CHECK_CALL("glTexImage2D");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); CHECK_CALL("glTexParameteri(MIN_FILTER = LINEAR)");
        glBindTexture(GL_TEXTURE_2D, 0); CHECK_CALL("glBindTexture(0)");

        // Upload geometry to gpu
        glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[0]); CHECK_CALL("glBindBuffer");
        glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData");
        glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[1]); CHECK_CALL("glBindBuffer");
        glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBindBuffer(0)");
        glBindBuffer(GL_ARRAY_BUFFER, 0); CHECK_CALL("glBindBuffer(0)");

        ntriangles = cast(uint)quads.length / 3;
        //assert(quads.length / 3 == uvs.length / 2);

        writefln("Setup utf text render test");
        writefln("text = %s", text);
        writefln("tris = %d", ntriangles);
        writefln("expected: %d", text.length * 2);
    }

    public void render () {
        if (gl_vao && gl_texture && shader) {
            glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
            glBindTexture(GL_TEXTURE_2D, gl_texture); CHECK_CALL("glBindTexture");
            glUseProgram(shader.id); CHECK_CALL("glUseProgram");
            shader.transform = mat4.identity();
            //shader.transform = mat4.identity().scale(1.0 / 800.0, 1.0 / 600.0, 1.0);

            glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray");
            glDrawArrays(GL_TRIANGLES, 0, ntriangles); CHECK_CALL("glDrawArrays");
            writefln("Drew %d triangles", ntriangles);

            //fullScreenQuad.draw();

            glUseProgram(0); CHECK_CALL("glUseProgram(0)");
            glBindVertexArray(0); CHECK_CALL("glBindVertexArray(0)");
        }
    }
    ~this () {
        // Cleanup resources
        if (gl_vao) {
            glDeleteVertexArrays(1, &gl_vao); CHECK_CALL("glDeleteVertexArrays");
            glDeleteBuffers(3, &gl_vbos[0]); CHECK_CALL("glDeleteBuffers");
        }
        if (gl_texture) {
            glDeleteTextures(1, &gl_texture); CHECK_CALL("glDeleteTexture");
        }
    }

    static auto defaultTest () {
        auto test = new StbTextRenderTest();
        test.setText("hello world\nMa Chérie\nさいごの果実 / ミツバチと科学者");
        return test;
    }
}

private class FullScreenTexturedQuad {
    uint gl_vao = 0;
    uint[2] gl_vbos;

    this () {
        if (__ctfe) return;

        glGenVertexArrays(1, &gl_vao); CHECK_CALL("glGenVertexArrays");
        glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray");

        float[] quad = [
            -1, -1, 0,
            -1, +1, 0,
            +1, +1, 0,

            +1, +1, 0,
            -1, +1, 0,
            -1, -1, 0,
        ];
        float[] uvs = [
            -1, -1,
            -1, +1,
            +1, +1,

            +1, +1,
            -1, +1,
            -1, -1
        ];
        glGenBuffers(2, gl_vbos.ptr); CHECK_CALL("glGenBuffers");

        glEnableVertexAttribArray(0); CHECK_CALL("glEnableVertexAttribArray");
        glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[0]); CHECK_CALL("glBindBuffer");
        glBufferData(GL_ARRAY_BUFFER, quad.length * 4, quad.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData");
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

        glEnableVertexAttribArray(1); CHECK_CALL("glEnableVertexAttribArray");
        glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[1]); CHECK_CALL("glBindBuffer");
        glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData");
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

        glBindVertexArray(0); CHECK_CALL("glBindVertexArray(0)");
    }
    void draw () {
        glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray");
        glDrawArrays(GL_TRIANGLES, 0, 6); CHECK_CALL("glDrawArrays (fstq)");
    }
}













