
module gsb.glutils;

import std.stdio;
import std.format;
import std.traits;
import std.conv;

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

void CHECK_CALL (lazy void expr) {
    auto err = glGetError();
    while (err != GL_NO_ERROR) {
        throw new Exception(format("%s while calling %s", glErrors[err]));
    }
}

void CHECK_CALL (string msg) {
    auto err = glGetError();
    if (err != GL_NO_ERROR) {
        throw new Exception(format("%s (%s)", glErrors[err], msg));
    }
}

void CHECK_CALL (F,Args...) (F f, Args args) {
    if (!__ctfe) {
        f(args);
        //CHECK_CALL(f.stringof);
        CHECK_CALL(fullyQualifiedName!(f));
    }   
}

void checked (string fname, Args...)(Args args) {
    auto f = mixin(fname);
    if (!__ctfe) {
        f(args);
        auto err = glGetError();
        if (err != GL_NO_ERROR) {
            string msg = fname ~ "(", sep = "";
            foreach (arg; args) {
                msg ~= sep ~ to!string(arg);
                sep = ", ";
            }
            msg ~= ")";
            throw new Exception(msg);
        }
    }
}

alias checked_glUseProgram = checked!("glUseProgram", uint);


//auto checked_glUseProgram = checked!"glUseProgram";

//alias checked_glUseProgram = checked!"glUseProgram";




//auto makeChecked (string fname) {
//    auto f = mixin(fname);
//    void impl (Args...)(Args args) {
//        if (!__ctfe) {
//             f(args);
//            CHECK_CALL(fname);
//        }
//    }
//    return impl;
//}

//auto checked_glUseProgram = makeChecked!("glUseProgram");





//void CHECK_CALL(F)(F fcn) {
//    auto err = glGetError();
//    while (err != GL_NO_ERROR) {
//        writefln("%s while calling %s", glErrors[err], F.stringof);
//        err = glGetError();
//    }
//}
//void CHECK_CALL(string context) {
//    auto err = glGetError();
//    while (err != GL_NO_ERROR) {
//        writefln("%s while calling %s", glErrors[err], context);
//        err = glGetError();
//    }
//}

