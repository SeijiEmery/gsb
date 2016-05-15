/+
module gsb.core.gl_commandbuffer;
import gsb.core.log;
import gsb.core.pseudosignals;
import gsb.core.singleton;

class GLCommandBuffer {

    // Producer / all non-graphics thread methods

    final void pushImmediate (void delegate() cmd) {
        synchronized (mutex) { cbuf[curFrame] ~= cmd; }
    }
    final void pushNextFrame (void delegate() cmd) {
        synchronized (mutex) { cbuf[nextFrame] ~= cmd; }
    }

    final void swapFrame () {
        synchronized (mutex) {
            curFrame  = (curFrame+1) % 4;
            nextFrame = (nextFrame+1) % 4;
            assert(curFrame != execFrame);
        }
    }
    final void shutdown () {
        synchronized (mutex) {
            gthreadAlive = false;
        }
    }

    // Graphics thread

    final void runGraphicsThread () {
        synchronized (mutex) {
            gthreadAlive = true;
            auto localCurrentFrame = curFrame;
            execFrame = (curFrame-1) % 4;
        }
        do {
            synchronized (mutex) {
                if (localCurrentFrame == curFrame && cbuf[curFrame].length) {
                    swap(cbuf[curFrame], cbuf[execFrame]);
                } else if (localCurrentFrame != curFrame) {
                    localCurrentFrame = curFrame;
                    execFrame = (curFrame-1) % 4;

                    swapBuffers();
                }
            }
            if (cbuf[execFrame].length) {
                foreach (cmd; cbuf[execFrame])
                    cmd();
                cbuf[execFrame].length = 0;
            } else if (gthreadAlive) {
                gthreadWaiting = true;
                gthreadCv.wait();
            }
        } while (gthreadAlive);
    }
    private final void swapBuffers () {
        // log frame stats...

        glfwSwapBuffer(g_mainWindow.handle);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // restart stats...
    }

private:
    Mutex mutex;
    void delegate()[][4] cbuf;
    uint execFrame = 0;
    uint curFrame  = 1;
    uint nextFrame = 2;
    bool gthreadAlive = false;
    bool gthreadWaiting = false;

    this () { mutex = new Mutex(); }
}
+/
