import rev3.core.opengl;
import rev3.core.glfw_app;
import rev3.core.resource;
import rev3.core.math;
import std.exception: enforce;
import std.string: toStringz;
import std.stdio;

public import derelict.opengl3.gl3;

/+
class Rev3GLRenderer {
    GLContext gl;

    public alias Shader = Ref!GLShader;
    public struct Mesh {
        Ref!GLVao vao;
        Ref!GLVbo vbo;
    }

    this (GLContext gl) { this.gl = gl; }
    Shader loadProgram (string vertex, string fragment) {
        auto shader = gl.create!GLShader();
        shader.source(GLShaderType.VERTEX, vertex);
        shader.source(GLShaderType.FRAGMENT, fragment);
        shader.bind();
        return shader;
    }
    auto deleteProgram (ref Shader shader) {
        shader.release();
    }
    Mesh loadMesh (float[] vertices, int[] indices = null) {
        auto vao = gl.create!GLVao();
        auto vbo = gl.create!GLVbo();

        vbo.bufferData(vertices, GLBufferUsage.GL_STATIC_DRAW);
        vao.bindVertexAttrib(0, vbo, 3, GLType.FLOAT, GLNormalized.FALSE, 3 * float.sizeof, 0);

        return Mesh(vao, vbo);
    }
    void deleteMesh (ref Mesh mesh) {
        mesh.vao.release();
        mesh.vbo.release();
    }
    void drawArrays (ref Shader shader, ref Mesh mesh, GLenum primitive, int start, int count) {
        assert(mesh.vao.bind());
        assert(shader.bind());
        gl.DrawArrays(primitive, start, count);
    }
}

class RawGLRenderer {
    alias Shader = uint;
    alias Mesh   = uint;

    static uint compileShader (GLenum type, string src) {
        assert(glGetError() == GL_NO_ERROR);
        auto s = src.toStringz;
        auto l = cast(int)src.length;

        uint shader = glCreateShader(type);
        glShaderSource(shader, 1, &s, &l);
        assert(glGetError() == GL_NO_ERROR);

        glCompileShader(shader);
        int status; glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
        assert(status == GL_TRUE);
        assert(glGetError() == GL_NO_ERROR);
        return shader;
    }
    Shader loadProgram (string vertex, string fragment) {
        uint program = glCreateProgram();
        glAttachShader(program, compileShader(GL_VERTEX_SHADER, vertex));
        glAttachShader(program, compileShader(GL_FRAGMENT_SHADER, fragment));
        assert(glGetError() == GL_NO_ERROR);

        glLinkProgram(program);
        int status; glGetProgramiv(program, GL_LINK_STATUS, &status);
        assert(status == GL_TRUE);
        assert(glGetError() == GL_NO_ERROR);
        return program;
    }
    void drawArrays (ref Shader shader, ref Mesh vao, GLenum primitive, int start, int count) {
        assert(glGetError() == GL_NO_ERROR);
        glUseProgram(shader);
        glBindVertexArray(vao);
        assert(glGetError() == GL_NO_ERROR);
        glDrawArrays(primitive, start, count);
        assert(glGetError() == GL_NO_ERROR);
    }
    Mesh loadMesh (float[] vertices, int[] indices = null) {
        assert(glGetError() == GL_NO_ERROR);

        uint vbo, vao;
        glGenBuffers(1, &vbo);
        glGenVertexArrays(1, &vao);

        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * vertices[0].sizeof, &vertices[0], GL_STATIC_DRAW);

        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * float.sizeof, cast(void*)0);
        glEnableVertexAttribArray(0);

        assert(glGetError() == GL_NO_ERROR);
        return vao;
    }
    void deleteProgram (ref Shader shader) {
        assert(glGetError() == GL_NO_ERROR);
        glDeleteProgram(shader);
        assert(glGetError() == GL_NO_ERROR);
    }
    void deleteMesh (ref Mesh vao) {
        assert(glGetError() == GL_NO_ERROR);
        glDeleteVertexArrays(1, &vao);
        assert(glGetError() == GL_NO_ERROR);
    }
}

class TriangleRenderer (Renderer) {
    Renderer        renderer;
    Renderer.Shader shader;
    Renderer.Mesh   mesh;

    this (Renderer renderer) {
        this.renderer = renderer;
        this.shader = renderer.loadProgram(`
            #version 410
            layout(location=0) in vec3 position;
            void main () {
                gl_Position = vec4(position, 0);
            }
        `, `
            #version 410
            out vec4 color;
            void main () {
                color = vec4(1.0, 0.0, 0.0, 0.0);
            }
        `);
        this.mesh = renderer.loadMesh([
            +0.0f, +0.5f, 0.0f,
            +0.5f, -0.5f, 0.0f,
            -0.5f, -0.5f, 0.0f,
        ], null);
    }
    void draw (mat4 m, mat4 v, mat4 p) {
        renderer.drawArrays(shader, mesh, GL_TRIANGLES, 0, 3);
    }
    void cleanup () {
        renderer.deleteProgram(shader);
        renderer.deleteMesh(mesh);
    }
}+/

class Application : GLFWApplication {
    //TriangleRenderer!RawGLRenderer  rawRenderer;
    //TriangleRenderer!Rev3GLRenderer rev3Renderer;

    GLShader shader;
    GLVao    vao;
    GLVbo    vbo;

    this (string[] args) {
        super(AppConfig("Opengl Triangle Test").applyArgs(args));
    }

    override void onInit () {
        writefln("==== Initializing ====");
        //rev3Renderer = new TriangleRenderer!Rev3GLRenderer(new Rev3GLRenderer(gl));
        //rawRenderer  = new TriangleRenderer!RawGLRenderer(new RawGLRenderer());

        shader = gl.create!(GLShader).get;
        shader.source(GLShaderType.VERTEX, q{
            #version 410
            layout(location=0) in vec3 position;
            void main () {
                gl_Position = vec4(position, 0);
            }
        });
        shader.source(GLShaderType.FRAGMENT, q{
            #version 410
            out vec4 color;
            void main () {
                color = vec4(1.0, 0.0, 0.5, 0.0);
            }
        });
        vbo = gl.create!GLVbo.get;
        vbo.bufferData!GL_STATIC_DRAW([
            -0.8f, -0.8f, 0.0f,
             0.0f, -0.8f, 0.0f,
             0.0f,  0.8f, 0.0f,
        ]);

        vao = gl.create!GLVao.get;
        vao.bind();
        vbo.bind();
        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, cast(int)(float.sizeof * 3), null);// cast(int)(3 * float.sizeof), cast(void*)0);
        gl.BindVertexArray(0);
    }
    int frame = 0;
    override void onFrame () {
        writefln("==== Frame %s ====", frame++);

        gl.ClearColor(0, 0, 0, 0);
        gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        import std.random;
        //gl.ClearColor(uniform(0.0, 1.0), uniform(0.0, 1.0), uniform(0.0, 1.0), 0.0);
        //gl.Clear(GL_COLOR_BUFFER_BIT);
        //rev3Renderer.draw(mat4.identity, mat4.identity, mat4.identity);

        assert(shader.bind() && vao.bind());
        gl.DrawArrays(GL_TRIANGLES, 0, 3);
    }
    override void onTeardown () {
        writefln("==== Teardown ====");

        shader.release();
        vao.release();
        vbo.release();
        //rev3Renderer.cleanup();
        //rawRenderer.cleanup();
        gl.gcResources();
    }
}

int main (string[] args) {
    try {
        new Application(args).run();
    } catch (Throwable e) {
        writefln("%s", e);
        return -1;
    }
    return 0;
}
