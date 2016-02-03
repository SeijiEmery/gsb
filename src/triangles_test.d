
module gsb.triangles_test;

import std.stdio;

import dglsl;
import derelict.opengl3.gl3;

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




class VertexShader : Shader!Vertex {
    @layout(location=0)
    @input vec3 position;

    @layout(location=1)
    @input vec3 color;

    @output vec3 vertColor;
    
    @uniform mat4 projectionMatrix;

    void main () {
        vertColor = color;
        gl_Position = vec4(position, 1.0);
        //gl_Position = projectionMatrix * vec4(position, 1.0);
    }
}

class FragmentShader : Shader!Fragment {
    @input vec3 vertColor;
    @output vec3 fragColor;

    void main () {
        fragColor = vec3(vertColor);
    }
}

class TriangleRenderer {
    auto fs = new FragmentShader();
    auto vs = new VertexShader();
    Program!(VertexShader, FragmentShader) program;

    uint positionBuffer;
    uint colorBuffer;
    uint vao;

    this () {
        CHECK_CALL("dirty state before entering TriangleRenderer ctor");

        fs.compile(); CHECK_CALL("fs.compile()");
        vs.compile(); CHECK_CALL("vs.compile()");
        program = makeProgram(vs, fs); CHECK_CALL("makeProgram(fs, vs)");
        //program.projectionMatrix = new Camera().projectionMatrix(); CHECK_CALL("program.setUniform(projectionMatrix, ...)");

        auto proj = mat4.perspective(800, 600, 60.0, 0.1, 1000.0);

        //program.projectionMatrix = mat4.identity; CHECK_CALL("program.setUniform(projectionMatrix, ...)");

        const float[] positions = [
            -0.8f, -0.8f, 0.0f,
            0.8f, -0.8f, 0.0f,
            0.0f, 0.8f, 0.0f
        ];
        const float[] colors = [
            1.0f, 0.0f, 0.0f,
            0.0f, 1.0f, 0.0f,
            0.0f, 0.0f, 1.0f
        ];

        glGenVertexArrays(1, &vao); CHECK_CALL("glGenVertexArrays (triangles vao)");
        glBindVertexArray(vao); CHECK_CALL("glBindVertexArray (triangles vao)");
        glEnableVertexAttribArray(0); CHECK_CALL("glEnableVertexAttribArray (triangles)");
        glEnableVertexAttribArray(1); CHECK_CALL("glEnableVertexAttribArray (triangles)");

        glGenBuffers(1, &positionBuffer); CHECK_CALL("glGenBuffers (triangles posbuffer)");
        glBindBuffer(GL_ARRAY_BUFFER, positionBuffer); CHECK_CALL("glBindBuffer (triangles posbuffer)");
        glBufferData(GL_ARRAY_BUFFER, 9 * 4, &positions[0], GL_STATIC_DRAW); CHECK_CALL("glBufferData (triangles posbuffer)");
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer (triangles posbuffer)");

        glGenBuffers(1, &colorBuffer); CHECK_CALL("glGenBuffers (triangles colbuffer)");
        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer); CHECK_CALL("glBindBuffer (triangles colbuffer)");
        glBufferData(GL_ARRAY_BUFFER, 9 * 4, &colors[0], GL_STATIC_DRAW); CHECK_CALL("glBufferData (triangles colbuffer)");
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer (triangles colbuffer)");

        glBindVertexArray(0); CHECK_CALL("glBindVertexArray (unbinding triangles vao)");
        //glDisableVertexAttribArray(0); CHECK_CALL("glDisableVertexAttribArray (triangles)");
        //glDisableVertexAttribArray(1); CHECK_CALL("glDisableVertexAttribArray (triangles)");
    }

    void render (Camera cam) {
        glUseProgram(program.id); CHECK_CALL("glUseProgram");
        program.projectionMatrix = cam.projectionMatrix(); CHECK_CALL("setUniform");

        glBindVertexArray(vao); CHECK_CALL("glBindVertexArray");
        glDrawArrays(GL_TRIANGLES, 0, 3); CHECK_CALL("glDrawArrays");
    }
}










