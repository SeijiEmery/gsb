
module gsb.text.textrendertest;
import gsb.text.textrenderer;
import std.file;
import std.utf;
import std.container.rbtree;
import std.math;
import std.format;
import std.algorithm.mutation;

import gsb.core.window;
import gsb.core.log;
import gsb.core.errors;
import gsb.glutils;

import stb.truetype;
import gl3n.linalg;
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

        fragColor = vec4(color.r); // stored as 1-channel bitmap, 
    }
}

class StbTextRenderTest {
    //public string fontPath = "/System/Library/Fonts/Helvetica.dfont";
    //public string fontPath = "/System/Library/Fonts/Menlo.ttc";
    public string fontPath = "/Library/Fonts/Arial Unicode.ttf";
    public int BITMAP_WIDTH = 1024, BITMAP_HEIGHT = 1024;
    public float fontSize = 50; // in pixels
    float fontScale;
    float fontBaseline;

    int ascent;
    int descent;
    int lineGap;


    uint[3] gl_vbos;
    uint    gl_vao = 0;
    uint    gl_texture = 0;
    Program!(VertexShader, FragmentShader) shader = null;
    uint ntriangles = 0;

    // debug
    auto fullScreenQuad = new FullScreenTexturedQuad();
    static immutable bool RENDER_FULLSCREEN_QUAD = false;

    string lastText;
    vec2  currentScalingFactor;

    auto allocator = stbtt_createAllocator();

    public void setText (string text) {
        if (__ctfe) 
            return;

        void enterExit (string msg, lazy void expr) {
            //writeln("entering ", msg);
            expr();
            //writeln("exiting ", msg);
        }
        void debugCall (string fcn, Args...)(Args args) if (__traits(compiles, (mixin(fcn))(args))) {
            mixin(fcn)(args);
            ////debug
            //enterExit(fcn, mixin(fcn)(args));
            ////else
            ////    mixin(fcn)(args);
        }

        lastText = text;
        currentScalingFactor = g_mainWindow.screenScale;
        auto scaleFactor = currentScalingFactor.y;
        log.write("Starting StbTextRenderTest");

        // Load font
        if (!exists(fontPath) || (!attrIsFile(getAttributes(fontPath))))
            throw new ResourceError("Cannot load font file '%s'", fontPath);

        auto fontData = cast(ubyte[])read(fontPath);
        if (fontData.length == 0)
            throw new ResourceError("Failed to load font file '%s'", fontPath);

        //writeln("loading font");

        stbtt_fontinfo fontInfo;
        int offs = stbtt_GetFontOffsetForIndex(fontData.ptr, 0);
        if (offs == -1)
            throw new ResourceError("stb_truetype: Failed to get font index for '%s'", fontPath);

        {
            int i = 0;
            while (stbtt_GetFontOffsetForIndex(fontData.ptr, i) != -1) ++i;
            log.write("Font '%s' contains %d fonts (font indices)", fontPath, i);
        }


        if (!stbtt_InitFont(&fontInfo, fontData.ptr, offs))
            throw new ResourceError("stb_trutype: Failed to load font '%s'", fontPath);

        //writeln("font loaded");

        fontScale = stbtt_ScaleForPixelHeight(&fontInfo, fontSize * scaleFactor);
        stbtt_GetFontVMetrics(&fontInfo, &ascent, &descent, &lineGap);

        //writeln("getting charset");

        // Determine charset
        auto rbcharset = new RedBlackTree!dchar();
        foreach (chr; byDchar(text))
            rbcharset.insert(chr);

        

        {
            dchar[] missingChrs;
            foreach (chr; rbcharset) {
                if (chr >= 0x20 && !stbtt_FindGlyphIndex(&fontInfo, chr))
                    missingChrs ~= chr;
            }
            if (missingChrs.length != 0)
                log.write("%d unsupported character(s): %s", missingChrs.length, missingChrs);
        }
        // Convert charset to an array and create lookup table
        dchar[] charset;
        int[dchar] chrLookup;
        {
            string escaped (dchar chr) {
                switch (chr) {
                    case '\0': return "\\0";
                    case '\n': return "\\n";
                    case '\t': return "\\t";
                    case '\r': return "\\r";
                    default: return format("%c", chr);
                }
            }

            int i = 0;
            string pretty_charset = "charset: ";
            foreach (chr; rbcharset) {
                charset ~= chr;
                chrLookup[chr] = i++;
                pretty_charset ~= escaped(chr);
            }
            log.write(pretty_charset);
        }
        //writeln("got charset");

        // Create bitmap + pack chars
        ubyte[] bitmapData = new ubyte[BITMAP_WIDTH * BITMAP_HEIGHT * 1];

        //writeln("packing charset");

        stbtt_pack_context pck;
        //stbtt_PackBegin(&pck, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, cast(void*)&allocator);
        debugCall!"stbtt_PackBegin"(&pck, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, cast(void*)&allocator);
        //enterExit("stbtt_PackBegin", stbtt_PackBegin(&pck, bitmapData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, 0, 1, cast(void*)&allocator));

        //if (pck.user_allocator_context != cast(void*)&allocator) {
        //    throw new Exception("allocator context != our allocator");
        //} else {
        //    writeln("our allocator = ", cast(void*)&allocator);
        //    writeln("stored alloctor = ", pck.user_allocator_context);
        //}


        auto packedChrData = new stbtt_packedchar[ charset.length ];

        // Pack charset
        stbtt_pack_range r;
        r.font_size = fontSize * scaleFactor;
        r.first_unicode_codepoint_in_range = 0;
        r.array_of_unicode_codepoints = cast(int*)charset.ptr;
        r.num_chars = cast(int)charset.length;
        r.chardata_for_range = packedChrData.ptr;

        debugCall!"stbtt_PackSetOversampling"(&pck, 1, 1);
        debugCall!"stbtt_PackFontRanges"(&pck, fontData.ptr, 0, &r, 1);
        debugCall!"stbtt_PackEnd"(&pck);

        //writeln("done packing charset");

        // Render to quads
        float[] quads;

        // UVs are flipped since stb_truetype uses flipped y-coords
        float[] uvs;

        //writeln("getting quads");

        float x = 0, y = (ascent - descent + lineGap) * fontScale;
        bool align_to_integer = true;
        foreach (chr; text.byDchar()) {
            if (chr == '\n') {
                x = 0;
                //writefln("ascent = %d, descent = %d, lineGap = %d, total = %d, scaled = %0.2f",
                //    ascent, descent, lineGap, (ascent - descent + lineGap), (ascent - descent + lineGap) * fontScale);

                y += (ascent - descent + lineGap) * fontScale;
            } else {
                stbtt_aligned_quad q;
                stbtt_GetPackedQuad(packedChrData.ptr, BITMAP_WIDTH, BITMAP_HEIGHT, chrLookup[chr], &x, &y, &q, align_to_integer);
                //writefln("Encoding %c (%d) => quad (%0.2f,%0.2f),(%0.2f,%0.2f) at (%0.2f,%0.2f)", chr, chrLookup[chr], q.x0, q.y0, q.x1, q.y1, x, y);

                // Push geometry
                quads ~= [
                    q.x0, -q.y1, 0.0,   // flip y-axis
                    q.x1, -q.y0, 0.0,
                    q.x1, -q.y1, 0.0,

                    q.x0, -q.y1, 0.0,
                    q.x0, -q.y0, 0.0,
                    q.x1, -q.y0, 0.0,
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

        //writeln("creating gl resources");

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
            //glUseProgram(shader.id); CHECK_CALL("glUseProgram");
            checked_glUseProgram(shader.id);
            shader.textureSampler = 0; CHECK_CALL("shader.textureSampler = 0");
            //shader.textureSampler = 0; CHECK_CALL("shader.textureSampler = 0");
            //auto loc = glGetUniformLocation(shader.id, "textureSampler"); CHECK_CALL("glGetUniformLocation");
            //glUniform1i(loc, 0); CHECK_CALL("glUniform1i (setting texture sampler = 0)");
        }

        //writeln("writing data to gpu");

        // Upload bitmap to gpu
        glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
        glBindTexture(GL_TEXTURE_2D, gl_texture); CHECK_CALL("glBindTexture");
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, BITMAP_WIDTH, BITMAP_HEIGHT, 0, GL_RED, GL_UNSIGNED_BYTE, bitmapData.ptr); CHECK_CALL("glTexImage2D");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); CHECK_CALL("glTexParameteri(MIN_FILTER = LINEAR)");
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR); CHECK_CALL("glTexParameteri(MAG_FILTER = LINEAR)");
        glBindTexture(GL_TEXTURE_2D, 0); CHECK_CALL("glBindTexture(0)");

        // Upload geometry to gpu
        glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[0]); CHECK_CALL("glBindBuffer");
        glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData");
        glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[1]); CHECK_CALL("glBindBuffer");
        glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBindBuffer(0)");
        glBindBuffer(GL_ARRAY_BUFFER, 0); CHECK_CALL("glBindBuffer(0)");

        ntriangles = cast(uint)quads.length / 3;

        //writeln("finished updating text");
        //assert(quads.length / 3 == uvs.length / 2);

        //writefln("Setup utf text render test");
        //writefln("text = %s", text);
        //writefln("tris = %d", ntriangles);
        //writefln("expected: %d", text.length * 2);
    }

    public void render () {
        if (gl_vao && gl_texture && shader) {
            glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
            glBindTexture(GL_TEXTURE_2D, gl_texture); CHECK_CALL("glBindTexture");
            glUseProgram(shader.id); CHECK_CALL("glUseProgram");
            
            shader.transform = mat4.identity();
            fullScreenQuad.draw();

            auto inv_scale_x = 1.0 / g_mainWindow.pixelDimensions.x;
            auto inv_scale_y = 1.0 / g_mainWindow.pixelDimensions.y;

            shader.transform = mat4.identity().scale(inv_scale_x, inv_scale_y, 1.0);
            glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray");
            glDrawArrays(GL_TRIANGLES, 0, ntriangles); CHECK_CALL("glDrawArrays");

            glUseProgram(0); CHECK_CALL("glUseProgram(0)");
            glBindVertexArray(0); CHECK_CALL("glBindVertexArray(0)");

            if (currentScalingFactor != g_mainWindow.screenScale) {
                //log.write("Rescaling text: %0.2f -> %0.2f, %0.2f -> %0.2f",
                //    currentScalingFactor.x, g_mainWindow.screenScale.x,
                //    currentScalingFactor.y, g_mainWindow.screenScale.y);
                setText(lastText);
            }
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

    void draw () {
        if (!gl_vao) {
            glGenVertexArrays(1, &gl_vao); CHECK_CALL("glGenVertexArrays");
            glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray");

            float[] quads = [ 
                0, 0, 0, 
                1, 1, 0,
                1, 0, 0,

                0, 0, 0,
                0, 1, 0,
                1, 1, 0,
            ];
            // Note: UVs are flipped for stb_truetype
            float[] uvs   = [ 
                0, 1,
                1, 0,
                1, 1,

                0, 1,
                0, 0,
                1, 0
            ];

            glGenBuffers(2, gl_vbos.ptr); CHECK_CALL("glGenBuffers");

            glEnableVertexAttribArray(0); CHECK_CALL("glEnableVertexAttribArray");
            glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[0]); CHECK_CALL("glBindBuffer");
            glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");
            glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData");

            glEnableVertexAttribArray(1); CHECK_CALL("glEnableVertexAttribArray");
            glBindBuffer(GL_ARRAY_BUFFER, gl_vbos[1]); CHECK_CALL("glBindBuffer");
            glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");
            glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData");

            glBindVertexArray(0); CHECK_CALL("glBindVertexArray(0)");
        }

        glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray");
        glDrawArrays(GL_TRIANGLES, 0, 6); CHECK_CALL("glDrawArrays");
    }
    ~this () {
        if (gl_vao) {
            glDeleteVertexArrays(1, &gl_vao);
            glDeleteBuffers(2, gl_vbos.ptr);
        }
    }
}













