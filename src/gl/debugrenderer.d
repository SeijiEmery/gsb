
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


class ColoredVertexShader: Shader!Vertex {
    @layout(location=0)
    @input vec2 inPos;

    @layout(location=1)
    @input vec4 inColor;

    @uniform mat4 transform;

    @output vec4 color;

    void main () {
        gl_Position = transform * vec4(inPos, 0.0, 1.0);
        color       = inColor;
    }
}

class ColoredFragmentShader: Shader!Fragment {
    @input vec4 color;
    @output vec4 fragColor;

    void main () {
        fragColor = color;
    }
}


@property auto DebugRenderer () { return DebugLineRenderer2D.instance; }
class DebugLineRenderer2D {
    mixin LowLockSingleton;

    protected struct State {
        GLuint vao = 0;
        GLuint[2] buffers;
        float[]   cbuffer;
        float[]   vbuffer;

        protected void render (ref mat4 transform) {
            if (!vbuffer.length)
                return;

            if (!vao) {
                checked_glGenVertexArrays(1, &vao);
                checked_glGenBuffers(2, buffers.ptr);
                checked_glBindVertexArray(vao);

                checked_glEnableVertexAttribArray(0);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, vbuffer.length * 4, vbuffer.ptr, GL_STREAM_DRAW);
                checked_glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

                checked_glEnableVertexAttribArray(1);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, cbuffer.length * 4, cbuffer.ptr, GL_STREAM_DRAW);
                checked_glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, null);
            } else {
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, vbuffer.length * 4, vbuffer.ptr, GL_STREAM_DRAW);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
                checked_glBufferData(GL_ARRAY_BUFFER, cbuffer.length * 4, cbuffer.ptr, GL_STREAM_DRAW);
            }

            checked_glBindVertexArray(vao);
            checked_glDrawArrays(GL_TRIANGLES, 0, cast(int)vbuffer.length / 2);

            string s = "";
            for (uint i = 0; i < vbuffer.length; i += 2) {
                auto v = vec4(vbuffer[i],vbuffer[i+1],0.0,1.0) * transform;
                s ~= format("(%0.2f, %0.2f, %0.2f), ", v.x, v.y, v.z);
            }
            log.write("Drawing stuff: %s", s);

        }
        protected void releaseResources () {
            if (vao) {
                checked_glDeleteVertexArrays(1, &vao);
                checked_glDeleteBuffers(2, buffers.ptr);
                vao = 0;
            }
        }
    }
    private State[2] states;
    private int fstate = 0, gstate = 1;
    //private auto fmutex = new Mutex();
    //private auto gmutex = new Mutex();

    void drawLines (vec2[] points, Color color, float width) {
        synchronized {
            
        }
    }
    void drawTri (vec2 pt, Color color, float size) {
        import std.math: sqrt;
        immutable float k = 1 / sqrt(3.0);
        synchronized {
            states[fstate].vbuffer ~= [
                pt.x,              pt.y + k * size,      
                pt.x + 0.5 * size, pt.y - k * size * 0.5,
                pt.x - 0.5 * size, pt.y - k * size * 0.5,
            ];
            states[fstate].cbuffer ~= [
                color.r, color.g, color.b, color.a,
                color.r, color.g, color.b, color.a,
                color.r, color.g, color.b, color.a,
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
            states[fstate].cbuffer.length = 0;
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



                //.translate(
                //    -g_mainWindow.screenDimensions.x * 0.5,
                //    g_mainWindow.screenDimensions.y * 0.5,
                //    0.0)
                //.translate(-1.0, 1.0, 0.0);
            transform.transpose();
            program.transform = transform;

            states[gstate].render(transform);
            checked_glUseProgram(0);
        }
    }
}






































































