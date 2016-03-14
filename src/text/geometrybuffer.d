
module gsb.text.geometrybuffer;
import gsb.gl.state;
import gsb.gl.algorithms;
import gsb.gl.drawcalls;

import gsb.core.log;
import stb.truetype;
import gsb.glutils;
import derelict.opengl3.gl3;
import core.sync.rwmutex;

private void DEBUG_LOG (lazy void expr) {
    static if (TEXTRENDERER_DEBUG_LOGGING_ENABLED) expr();
}

interface IGraphicsComponent {
    public void update ();
    public void draw ();
    public void releaseResources ();
}

class TextGeometryBuffer {
    float[] packedData, nextData;

    //float[] positionData;
    //float[] uvData;
    //float[] colorData;
    private bool needsUpdate = false;
    private bool shouldRelease = false;

    ReadWriteMutex mutex;

    this () {
        mutex = new ReadWriteMutex();
    }
    auto @property read  () { return mutex.reader(); }
    auto @property write () { return mutex.writer(); }

    private GraphicsBackend _backend = null;
    @property auto backend () {
        if (!_backend)
            _backend = new GraphicsBackend();
        return _backend;
    }

    void pushQuad (ref stbtt_aligned_quad q) {
        synchronized (read) {
            packedData ~= [
                q.x0, -q.y1, 0.0, 0.0, q.s0, q.t1,   // flip y-axis
                q.x1, -q.y0, 0.0, 0.0, q.s1, q.t0,
                q.x1, -q.y1, 0.0, 0.0, q.s1, q.t1,

                q.x0, -q.y1, 0.0, 0.0, q.s0, q.t1,
                q.x0, -q.y0, 0.0, 0.0, q.s0, q.t0,
                q.x1, -q.y0, 0.0, 0.0, q.s1, q.t0,
            ];
        }
        //positionData ~= [
        //    q.x0, -q.y1, 0.0,   // flip y-axis
        //    q.x1, -q.y0, 0.0,
        //    q.x1, -q.y1, 0.0,

        //    q.x0, -q.y1, 0.0,
        //    q.x0, -q.y0, 0.0,
        //    q.x1, -q.y0, 0.0,
        //];
        //uvData ~= [
        //    q.s0, q.t1,
        //    q.s1, q.t0,
        //    q.s1, q.t1,

        //    q.s0, q.t1,
        //    q.s0, q.t0,
        //    q.s1, q.t0
        //];
        needsUpdate = true;
    }
    void clear () {
        synchronized (write) {
            //import std.algorithm.mutation: swap;
            //swap(packedData, nextData);
            //nextData.length = 0;
            packedData.length = 0;
        }
        //packedData.length = 0;
        //nextData.length = 0;
        //positionData.length = 0;
        //uvData.length = 0;
        //needsUpdate = true;
    }
    void releaseResources () {
        shouldRelease = true;
        needsUpdate = true;
    }

    class GraphicsBackend : IGraphicsComponent {
        //GLuint vao = 0;
        //GLuint[3] buffers;
        int numTriangles = 0;
        VAO vao;

        override void update () {
            //if (needsUpdate) {
            //    synchronized (read) {
            //        auto numQuadTriangles = cast(int)(positionData.length / 9);
            //        auto numUvTriangles = cast(int)(uvData.length / 6);
            //        if (numQuadTriangles != numUvTriangles)
            //            log.write("WARNING: TextGeometryBuffer has mismatching triangle count: %s, %s", numQuadTriangles, numUvTriangles);
            //        numTriangles = numQuadTriangles;
            //        log.write("TextGeometryBuffer.GraphicsBackend: set triangles = %d", numTriangles);
            //    }
            //}
        }

        override void draw () {
            if (!packedData.length)
                return;
            if (!vao) vao = new VAO();
            //synchronized (read) {
                DynamicRenderer.drawArrays(vao, GL_TRIANGLES, 0, cast(int)(packedData.length / 6) * 3, [
                    VertexData(packedData.ptr, packedData.length * float.sizeof, [
                        VertexAttrib(0, 3, GL_FLOAT, GL_FALSE, float.sizeof * 6, cast(void*)(0)),
                        VertexAttrib(1, 2, GL_FLOAT, GL_FALSE, float.sizeof * 6, cast(void*)(float.sizeof * 4)),
                    ])
                ]);
            //}
            //DynamicRenderer.drawArrays(vao, GL_TRIANGLES, 0, numTriangles * 3, [
            //    VertexData(positionData.ptr, positionData.length * float.sizeof, [
            //        VertexAttrib(0, 3, GL_FLOAT, GL_FALSE, 0, null)
            //    ]),
            //    VertexData(uvData.ptr, uvData.length * float.sizeof, [
            //        VertexAttrib(1, 2, GL_FLOAT, GL_FALSE, 0, null)
            //    ])
            //]);
        }

        override void releaseResources () {
            vao.release();
        }

        /+
        override void update () {
            if (needsUpdate) {
                synchronized (read) {
                    needsUpdate = false;
                    if (shouldRelease) {
                        shouldRelease = false;
                        releaseResources();
                    }
                    auto numQuadTriangles = cast(int)(positionData.length / 9);
                    auto numUvTriangles = cast(int)(uvData.length / 6);
                    if (numQuadTriangles != numUvTriangles)
                        DEBUG_LOG(log.write("WARNING: TextGeometryBuffer has mismatching triangle count: %s, %s", numQuadTriangles, numUvTriangles));
                    numTriangles = numQuadTriangles;
                    DEBUG_LOG(log.write("TextGeometryBuffer.GraphicsBackend: set triangles = %d", numTriangles));
                    if (numTriangles > 0) {
                        rebufferData();
                    }
                }
            }
        }
        private void rebufferData () {
            if (!vao) {
                DEBUG_LOG(log.write("TextGeometryBuffer.GraphicsBackend: creating buffers"));
                DEBUG_LOG(log.write("TextGeometryBuffer.GraphicsBackend: buffering data"));
                checked_glGenVertexArrays(1, &vao);
                checked_glGenBuffers(3, buffers.ptr);

                checked_glBindVertexArray(vao);

                checked_glEnableVertexAttribArray(0);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, positionData.length * 4, positionData.ptr, GL_DYNAMIC_DRAW);
                checked_glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);

                checked_glEnableVertexAttribArray(1);
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
                checked_glBufferData(GL_ARRAY_BUFFER, uvData.length * 4, uvData.ptr, GL_DYNAMIC_DRAW);
                checked_glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

                checked_glBindVertexArray(0);
            } else {
                DEBUG_LOG(log.write("TextGeometryBuffer.GraphicsBackend: rebuffering data"));
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, positionData.length * 4, positionData.ptr, GL_DYNAMIC_DRAW);

                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
                checked_glBufferData(GL_ARRAY_BUFFER, uvData.length * 4, uvData.ptr, GL_DYNAMIC_DRAW);
            }
        }

        override void draw () {
            if (vao && numTriangles > 0) {
                //DEBUG_LOG(log.write("TextGeometryBuffer.GraphicsBackend: drawing %d triangles", numTriangles));
                checked_glBindVertexArray(vao);
                checked_glDrawArrays(GL_TRIANGLES, 0, numTriangles * 3);
            }
        }
        override void releaseResources () {
            if (vao) {
                DEBUG_LOG(log.write("TextGeometryBuffer.GraphicsBackend: releasing resources (had %d triangles)", numTriangles));
                checked_glDeleteVertexArrays(1, &vao);
                checked_glDeleteBuffers(3, buffers.ptr);
                vao = 0;
            }
        }+/
    }
}

