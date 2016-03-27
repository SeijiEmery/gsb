
module gsb.gl.algorithms;

import gsb.coregl;
public import gsb.gl.drawcalls;

import gsb.core.mathutils;
import gsb.core.log;
import gsb.core.color;
import gsb.core.singleton;
import gsb.core.window;
import derelict.opengl3.gl3;
import dglsl;
import gl3n.linalg;
import std.traits;



interface IDynamicRenderer {
    void drawArrays   (VADrawCall batch);
    void drawElements (VADrawCall batch, ElementData elements);
    void release ();
    void onFrameEnd ();
}

// Dynamic, one-shot renderer that uses one vbo and unsynchronized glMapBuffer
// Impl of https://www.opengl.org/discussion_boards/showthread.php/170118-VBOs-strangely-slow?p=1197780#post1197780
private class UMapBatchedDynamicRenderer : IDynamicRenderer {
    mixin LowLockSingleton;

    VBO vbo = null;
    size_t bufferSize    = 1 << 20; //64;  // 1 mb
    size_t bufferOffset  = 0;

    final void onFrameEnd () {
        if (vbo) {
            //log.write("Clearing vbo; reserving size %d", bufferSize);
            //vbo.bind(GL_ARRAY_BUFFER);
            glBindBuffer(GL_ARRAY_BUFFER, vbo.get()); // need to force this, since not everything else uses glState.bindVbo yet...
            glchecked!glBufferData(GL_ARRAY_BUFFER, bufferSize, null, GL_STREAM_DRAW);
            bufferOffset = 0;
        }
    }

    final void drawArrays (VADrawCall batch) {
        //log.write("drawArrays: %s", batch);

        size_t neededLength = 0;
        foreach (component; batch.components)
            neededLength += nextPow2(component.length);

        if (!vbo) {
            vbo = new VBO();

            log.write("Creating vbo; reserving size %d", bufferSize);

            vbo.bind(GL_ARRAY_BUFFER);
            glchecked!glBufferData(GL_ARRAY_BUFFER, bufferSize, null, GL_STREAM_DRAW);
            //vbo.bufferData!(GL_ARRAY_BUFFER, GL_STREAM_DRAW)(bufferSize, null);
            bufferOffset = 0;
        }
        if (neededLength + bufferOffset >= bufferSize) {
            // Check that our entire data set will fit within the buffer (if not, we need a bigger buffer)
            if (neededLength >= bufferSize) {
                log.write("Large data store requested -- UMapRenderer resizing vbo from %d to %d",
                    bufferSize, nextPow2(neededLength));
                bufferSize = nextPow2(neededLength);
            }


            //log.write("Orphaning vbo (%d + %d > %d); reserving size %d", neededLength, bufferOffset, bufferSize, bufferSize);
            // Orphan buffer, reset cursor
            vbo.bind(GL_ARRAY_BUFFER);
            glchecked!glBufferData(GL_ARRAY_BUFFER, bufferSize, null, GL_STREAM_DRAW);
            bufferOffset = 0;
        } else {
            vbo.bind(GL_ARRAY_BUFFER);
        }

        glBindBuffer(GL_ARRAY_BUFFER, vbo.get());

        // map vao + process components
        glState.bindVao(batch.vao);

        import core.stdc.string: memcpy;
        foreach (component; batch.components) {
            //auto size = nextPow2(component.length);
            //auto ptr  = vbo.mapRange(bufferOffset, size, GL_MAP_WRITE_BIT | GL_MAP_UNSYNCHRONIZED_BIT);
            //memcpy(ptr, component.data, component.length);
            //bufferOffset += size;

            auto size = nextPow2(component.length);

            log.write("writing (length = %d, size = %d, offset = %d | %d / %d (%0.2f))", component.length, size, bufferOffset, 
                size + bufferOffset, bufferSize, cast(float)(size + bufferOffset) / cast(float)bufferSize);

            //void* ptr = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY) + bufferOffset;
            //void* ptr = glMapBufferRange(GL_ARRAY_BUFFER, bufferOffset, size, GL_MAP_WRITE_BIT | GL_MAP_UNSYNCHRONIZED_BIT);
            //CHECK_CALL("glMapBufferRange");
            //import core.stdc.string: memcpy;
            //memcpy(ptr, component.data, component.length);
            //glUnmapBuffer(GL_ARRAY_BUFFER);
            //CHECK_CALL("glUnmapBuffer");

            vbo.writeMappedRange!(GL_ARRAY_BUFFER)(bufferOffset, size, component.data, GL_MAP_WRITE_BIT);
            bufferOffset += size;

            foreach (attrib; component.attribs) {
                glchecked!glEnableVertexAttribArray(attrib.index);
                glchecked!glVertexAttribPointer(attrib.index, attrib.count, attrib.type, attrib.normalized, attrib.stride, attrib.pointerOffset);
            }
        }
        glchecked!glDrawArrays(batch.type, batch.offset, batch.count);
        glState.bindVao(0);
    }

    final void drawElements (VADrawCall batch, ElementData elementData) {
        throw new Exception("Unimplemented!");
    }

    final void release () {
        vbo.release();
    }
}

private class BasicDynamicRenderer : IDynamicRenderer {
    mixin LowLockSingleton;

    private GLuint[] vbos;

    final void onFrameEnd () {}

    private final void genVbos (size_t count) {
        int toCreate = cast(int)count - cast(int)vbos.length;
        if (toCreate > 0) {
            auto first = vbos.length;
            foreach (i; 0..toCreate)
                vbos ~= [ 0 ];
            glchecked!glGenBuffers(toCreate, vbos.ptr + first);
            log.write("BDR genereated %d vbos", toCreate);
        }
    }

    final void drawArrays (VADrawCall batch) {
        // create new vbos as necessary
        genVbos(batch.components.length);
        
        // buffer data + draw
        glState.bindVao(batch.vao);
        foreach (i; 0..batch.components.length) {
            glchecked!glBindBuffer(GL_ARRAY_BUFFER, vbos[i]);
            glchecked!glBufferData(GL_ARRAY_BUFFER, batch.components[i].length, batch.components[i].data, GL_STREAM_DRAW);
            foreach (attrib; batch.components[i].attribs) {
                glchecked!glEnableVertexAttribArray(attrib.index);
                glchecked!glVertexAttribPointer(
                    attrib.index, attrib.count, attrib.type, attrib.normalized, 
                    attrib.stride, attrib.pointerOffset);
            }
        }
        glchecked!glDrawArrays(batch.type, batch.offset, batch.count);

        // orphan buffers so we can reuse them for the next drawcall (note: we're _not_ trying to be fast/efficient here; this is just a minimalistic
        // implementation that we can test against the others)
        foreach (i; 0..batch.components.length) {
            glchecked!glBufferData(GL_ARRAY_BUFFER, batch.components[i].length, null, GL_STREAM_DRAW);
        }
    }

    final void drawElements (VADrawCall batch, ElementData elementData) {
        // create new vbos as necessary
        genVbos(batch.components.length + 1);
        
        // buffer data + draw
        glchecked!glBindVertexArray(batch.vao);
        foreach (i; 0..batch.components.length) {
            glchecked!glBindBuffer(GL_ARRAY_BUFFER, vbos[i]);
            glchecked!glBufferData(GL_ARRAY_BUFFER, batch.components[i].length, batch.components[i].data, GL_STREAM_DRAW);
            foreach (attrib; batch.components[i].attribs) {
                glchecked!glVertexAttribPointer(attrib.index, attrib.count, attrib.type, attrib.normalized, attrib.stride, attrib.pointerOffset);
            }
        }
        glchecked!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbos[batch.components.length]);
        glchecked!glBufferData(GL_ELEMENT_ARRAY_BUFFER, elementData.length, elementData.data, GL_STREAM_DRAW);
        glchecked!glDrawElements(batch.type, batch.count, elementData.type, elementData.pointerOffset);

        glchecked!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbos[batch.components.length]);
        glchecked!glBufferData(GL_ELEMENT_ARRAY_BUFFER, elementData.length, null, GL_STREAM_DRAW);
    }

    final void release () {
        if (vbos.length) {
            glDeleteBuffers(cast(int)vbos.length, &vbos[0]);
            vbos.length = 0;
        }
    }
}

struct DynamicRenderer {
    enum {
        NO_RENDERER = 0,
        UMAP_BATCHED_DYNAMIC_RENDERER,
        BASIC_DYNAMIC_RENDERER,
    }

    public  static __gshared auto renderer = BASIC_DYNAMIC_RENDERER;
    private static auto lastRenderer = NO_RENDERER;
    private static IDynamicRenderer _currentRenderer;

    private static @property IDynamicRenderer currentRenderer () {
        if (renderer == lastRenderer && _currentRenderer) {
            return _currentRenderer;
        }

        lastRenderer = renderer;
        switch (renderer) {
            case UMAP_BATCHED_DYNAMIC_RENDERER:  
                return _currentRenderer = UMapBatchedDynamicRenderer.instance;
            case BASIC_DYNAMIC_RENDERER: 
                return _currentRenderer = BasicDynamicRenderer.instance;
            default:
                throw new Exception("Invalid renderer!");
        }
    }

    static void drawElements (VAO vao, GLenum type, GLsizei offset, GLsizei count,
        VertexData[] vertexData, ElementData elementData
    ) {
        currentRenderer.drawElements(
            VADrawCall(vao.get(), type, offset, count, vertexData), 
            elementData);
    }
    static void drawArrays (VAO vao, GLenum type, GLsizei offset, GLsizei count,
        VertexData[] vertexData)
    {
        if (!currentRenderer)
            throw new Exception("null renderer");
        if (!vao.get())
            throw new Exception("null vao");

        auto vao_id = vao.get();
        auto batch = VADrawCall(vao_id, type, offset, count, vertexData);
        currentRenderer.drawArrays(batch);
    }

    static void signalFrameEnd () { currentRenderer.onFrameEnd(); }
}


