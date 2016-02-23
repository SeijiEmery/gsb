
module gsb.text.geometrybuffer;
import gsb.core.log;
import stb.truetype;
import gsb.glutils;
import derelict.opengl3.gl3;
import core.sync.rwmutex;

interface IGraphicsComponent {
    public void update ();
    public void draw ();
    public void releaseResources ();
}

class TextGeometryBuffer {
    float[] positionData;
    float[] uvData;
    float[] colorData;
    private bool needsUpdate = false;
    private bool shouldRelease = false;
    ReadWriteMutex mutex;

    this () {
        mutex = new ReadWriteMutex();
    }
    auto @property read  () { return mutex.reader(); }
    auto @property write () { return mutex.writer(); }

    void pushQuad (ref stbtt_aligned_quad q) {
        positionData ~= [
            q.x0, -q.y1, 0.0,   // flip y-axis
            q.x1, -q.y0, 0.0,
            q.x1, -q.y1, 0.0,

            q.x0, -q.y1, 0.0,
            q.x0, -q.y0, 0.0,
            q.x1, -q.y0, 0.0,
        ];
        uvData ~= [
            q.s0, q.t1,
            q.s1, q.t0,
            q.s1, q.t1,

            q.s0, q.t1,
            q.s0, q.t0,
            q.s1, q.t0
        ];
        needsUpdate = true;
    }
    void clear () {
        positionData.length = 0;
        uvData.length = 0;
        needsUpdate = true;
    }
    void releaseResources () {
        shouldRelease = true;
        needsUpdate = true;
    }

    class GraphicsBackend : IGraphicsComponent {
        GLuint vao = 0;
        GLuint[3] buffers;
        int numTriangles = 0;

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
                        log.write("WARNING: TextGeometryBuffer has mismatching triangle count: %s, %s", numQuadTriangles, numUvTriangles);
                    numTriangles = numQuadTriangles;
                    if (numTriangles > 0) {
                        rebufferData();
                    }
                }
            }
        }
        private void rebufferData () {
            if (!vao) {
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
                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
                checked_glBufferData(GL_ARRAY_BUFFER, positionData.length * 4, positionData.ptr, GL_DYNAMIC_DRAW);

                checked_glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
                checked_glBufferData(GL_ARRAY_BUFFER, uvData.length * 4, uvData.ptr, GL_DYNAMIC_DRAW);
            }
        }

        override void draw () {
            if (vao && numTriangles > 0) {
                checked_glBindVertexArray(vao);
                checked_glDrawArrays(GL_TRIANGLES, 0, numTriangles * 3);
            }
        }
        override void releaseResources () {
            if (vao) {
                checked_glDeleteVertexArrays(1, &vao);
                checked_glDeleteBuffers(3, buffers.ptr);
                vao = 0;
            }
        }
    }
}

