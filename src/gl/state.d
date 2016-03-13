
module gsb.gl.state;

import gsb.core.log;

import gsb.glutils;
import derelict.opengl3.gl3;
import gl3n.linalg;

public __gshared GLState glState;
struct GLState {
    private bool depthTestEnabled = false;
    private bool transparencyEnabled = false;

    void enableDepthTest (bool enabled) {
        if (depthTestEnabled != enabled) {
            if ((depthTestEnabled = enabled) == true) {
                log.write("Enabling glDepthTest (GL_LESS)");
                glEnable(GL_DEPTH_TEST);
                glDepthFunc(GL_LESS);
            } else {
                log.write("Disabling glDepthTest");
                glDisable(GL_DEPTH_TEST);
            }
        }
    }
    void enableTransparency (bool enabled) {
        if (transparencyEnabled != enabled) {
            if ((transparencyEnabled = enabled) == true) {
                log.write("Enabling alpha transparency blending");
                glEnable(GL_BLEND);
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            } else {
                log.write("Disabling alpha transparency");
                glDisable(GL_BLEND);
            }
        }
    }
}

class VertexArray {
    private GLuint handle = 0;
    auto get () {
        if (!handle) {
            log.write("creating vertex array");
            checked_glGenVertexArrays(1, &handle);
        }
        return handle;
    }
    void release () {
        if (handle) {
            checked_glDeleteVertexArrays(1, &handle);
            handle = 0;
        }
    }
}












