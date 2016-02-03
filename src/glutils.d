
module gsb.glutils;

import std.stdio;
import derelict.opengl3.gl3;
import dglsl;

class Camera {
    float viewportWidth = 800, viewportHeight = 600;
    float aspectRatio;
    float fov = 60;
    float near = 0.1, far = 1e3;

    mat4 projection;
    mat4 view;

    mat4 projectionMatrix () {
        return projection = mat4.perspective(viewportWidth, viewportHeight, fov, near, far);
    }
}


static string[GLenum] glErrors;
static this () {
    glErrors = [
                GL_INVALID_OPERATION: "INVALID OPERATION",
                GL_INVALID_ENUM: "INVALID ENUM",
                GL_INVALID_VALUE: "INVALID VALUE",
                GL_INVALID_FRAMEBUFFER_OPERATION: "INVALID FRAMEBUFFER OPERATION",
                GL_OUT_OF_MEMORY: "GL OUT OF MEMORY"
            ];
}

void CHECK_CALL(F)(F fcn) {
    auto err = glGetError();
    while (err != GL_NO_ERROR) {
        writefln("%s while calling %s", glErrors[err], F.stringof);
        err = glGetError();
    }
}
void CHECK_CALL(string context) {
    auto err = glGetError();
    while (err != GL_NO_ERROR) {
        writefln("%s while calling %s", glErrors[err], context);
        err = glGetError();
    }
}

