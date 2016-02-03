
module gsb.triangles_test;

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



class VertexShader : Shader!Vertex {
    @layout(location=0)
    @input vec3 position;

    @layout(location=1)
    @input vec3 color;

    @output vec3 vertColor;
    @uniform mat4 projectionMatrix;

    void main () {
        vertColor = color;
        gl_Position = projectionMatrix * vec4(position, 1.0);
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
        fs.compile();
        vs.compile();
        program = makeProgram(vs, fs);

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

        glGenBuffers(1, &vao);
        glBindVertexArray(vao);
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);

        glGenBuffers(1, &positionBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, positionBuffer);
        glBufferData(GL_ARRAY_BUFFER, 9 * 4, &positions[0], GL_STATIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);

        glGenBuffers(1, &colorBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glBufferData(GL_ARRAY_BUFFER, 9 * 4, &colors[0], GL_STATIC_DRAW);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, null);

        glBindVertexArray(0);
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
    }

    void render (Camera cam) {
        glUseProgram(program.id);
        program.projectionMatrix = cam.projectionMatrix();

        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);
    }
}










