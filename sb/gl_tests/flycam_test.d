import sb.platform;
import sb.gl;
import sb.events;

import std.stdio;
import std.datetime: StopWatch;
import core.time;
import std.conv;
import gl3n.linalg;
import gl3n.math;

enum Renderer {
    SbRenderer,
    Rev3Renderer,
}
auto activeRenderer = Renderer.SbRenderer;

immutable auto GRID_DIM   = vec3i( 100, 50, 100 );
immutable auto GRID_SCALE =  vec3( 100, 50, 100 );

immutable float[] triangleData = [
    -0.8f, -0.8f, 0.0f,  1.0f, 0.0f, 0.0f,
     0.8f, -0.8f, 0.0f,  0.0f, 1.0f, 0.0f,
     0.0f,  0.8f, 0.0f,  0.0f, 0.0f, 1.0f
];
immutable vertexShader = q{
    #version 410
    layout(location=0) in vec3 vertPosition;
    layout(location=1) in vec3 vertColor;
    layout(location=2) in vec3 instancePosition;
    out vec3 color;

    uniform mat4 vp;
    uniform mat4 model;

    void main () {
        color = vertColor;
        gl_Position = vp * (
            vec4(instancePosition, 0) +
            model * vec4(vertPosition, 1.0));
    }
};
immutable fragmentShader = q{
    #version 410
    in vec3 color;
    out vec4 fragColor;

    void main () {
        fragColor = vec4( color, 1.0 );
    }
};
vec3[] generateGrid (vec3i dimensions, vec3 scale) {
    vec3[] grid;
    foreach (x; 0f .. dimensions.x) {
        foreach (y; 0f .. dimensions.y) {
            foreach (z; 0f .. dimensions.z) {
                grid ~= vec3(
                    (x - scale.x * 0.5) * scale.x / dimensions.x * 2.0,
                    (y - scale.y * 0.5) * scale.y / dimensions.y * 2.0,
                    (z - scale.z * 0.5) * scale.z / dimensions.z * 2.0,
                );
           }
        }
    }
    return grid;
}

struct SbRenderer {
    IGraphicsContext  context;
    GLResourcePoolRef resourcePool;
    GLShaderRef       shader;
    GLVaoRef          vao;
    GLVboRef          triangleVbo;
    GLVboRef          gridVbo;

    this (IGraphicsContext context, const vec3[] gridData) {
        this.context = context;
        this.resourcePool = context.createResourcePrefix("flycam-test");

        this.shader = resourcePool.createShader();
        shader.rawSource(GLShaderType.VERTEX, vertexShader);
        shader.rawSource(GLShaderType.FRAGMENT, fragmentShader);
        
        this.vao         = resourcePool.createVAO();
        this.triangleVbo = resourcePool.createVBO();
        this.gridVbo     = resourcePool.createVBO();

        context.getLocalBatch.execGL({
            bufferData(triangleVbo, triangleData, GLBufferUsage.GL_STATIC_DRAW);
            vao.bindVertexAttrib(0, triangleVbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, float.sizeof * 6, 0);
            vao.bindVertexAttrib(1, triangleVbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, float.sizeof * 6, float.sizeof * 3);

            bufferData(gridVbo, gridData, GLBufferUsage.GL_STATIC_DRAW);
            vao.bindVertexAttrib(2, gridVbo, 3, GLType.GL_FLOAT, GLNormalized.FALSE, 0, 0);
            vao.setVertexAttribDivisor(2, 1);

            vao.bindShader(shader);
        });
    }
    void draw (mat4 model, mat4 view, mat4 proj) {
        auto mvp = proj * view * model;
        context.getLocalBatch.execGL({
            shader.setv("vp", proj * view);
            shader.setv("model", model);

            //vao.drawArrays( GLPrimitive.TRIANGLES, 0, 3 );
            vao.drawArraysInstanced(GLPrimitive.GL_TRIANGLES, 0, 3, GRID_DIM.x * GRID_DIM.y * GRID_DIM.z);
        });
    }
}

struct Rev3Renderer {
    import rev3.core.opengl;
    import rev3.core.resource;

    GLContext    gl;
    Ref!GLShader shader;
    Ref!GLVao    vao;
    Ref!GLVbo    triangleVbo;
    Ref!GLVbo    gridVbo;

    this (const vec3[] gridData) {
        this.gl = new GLContext();
        
        this.shader = gl.create!GLShader();
        shader.source(GL_VERTEX_SHADER,   vertexShader);
        shader.source(GL_FRAGMENT_SHADER, fragmentShader);
        shader.bind();

        this.vao         = gl.create!GLVao();
        this.triangleVbo = gl.create!GLVbo();
        this.gridVbo     = gl.create!GLVbo();

        triangleVbo.bufferData(triangleData, GLBufferUsage.GL_STATIC_DRAW);
        vao.bindVertexAttrib(triangleVbo.get, 0, 3, GL_FLOAT, false, float.sizeof * 6, 0);
        vao.bindVertexAttrib(triangleVbo.get, 1, 3, GL_FLOAT, false, float.sizeof * 6, float.sizeof * 3);

        gridVbo.bufferData(gridData, GLBufferUsage.GL_STATIC_DRAW);
        vao.bindVertexAttrib(gridVbo.get, 2, 3, GL_FLOAT, false, 0, 0);
        vao.setVertexAttribDivisor(2, 1);
    }
    void draw (mat4 model, mat4 view, mat4 proj) {
        auto mvp = proj * view * model;

        if (vao.bind() && shader.bind()) {
            shader.setUniform("vp", proj * view);
            shader.setUniform("model", model);
            gl.DrawArraysInstanced(GLPrimitive.GL_TRIANGLES, 0, 3, GRID_DIM.x * GRID_DIM.y * GRID_DIM.z);
        }
    }
    ~this () {
        gl.gcResources();
    }
}

void main (string[] args) {
    SbPlatformConfig platformConfig = {
        backend: SbPlatform_Backend.GLFW3,
        glVersion: SbPlatform_GLVersion.GL_410,
    };
    auto platform = sbCreatePlatformContext(
        sbCreateGraphicsLib(GraphicsLibVersion.GL_410),
        platformConfig);
    try {
        platform.init();
        SbWindowConfig windowConfig = {
            title: "flycam test",
            size_x: 1200, size_y: 780,
            showFps: true,
        };
        auto window = platform.createWindow("main-window", windowConfig);
        platform.initGL();

        auto instanceGridData = generateGrid(GRID_DIM, GRID_SCALE);
        
        // Old renderer
        auto sbRenderer   = SbRenderer(platform.getGraphicsContext, instanceGridData);
        
        // New renderer
        auto rev3Renderer = Rev3Renderer(instanceGridData);

        auto cam_pos    = vec3( 0, 0, -5 );
        auto cam_angles = vec3(0, 0, 0);
        auto CAM_LOOK_SPEED = 100.0.radians;
        auto CAM_MOVE_SPEED = 15.0;

        float MAX_FOV = 360.0, MIN_FOV = 0.5, FOV_CHANGE_SPEED = 120.0;
        float MIN_FAR = 10, MAX_FAR = 2e3, FAR_CHANGE_SPEED = 1e2;

        float fov = 60.0, near = 0.1, far = 1e3;

        StopWatch sw; sw.start();
        double prevTime = sw.peek.to!("seconds", double);
        while (!window.shouldClose) {
            auto time = sw.peek.to!("seconds", double);
            auto dt   = time - prevTime;
            prevTime  = time;
            window.setTitleFPS( 1.0 / dt );

            immutable auto PERIOD = 2.0;
            auto t = (time % PERIOD) / PERIOD * 2 * PI;

            platform.pollEvents();

            auto proj = mat4.perspective( 
                cast(float)window.windowSize.x, 
                cast(float)window.windowSize.y, 
                fov, near, far );

            import std.variant;

            auto fwd = vec3(
                cam_angles.x.cos * cam_angles.y.cos,
                cam_angles.x.sin,
                cam_angles.x.cos * cam_angles.y.sin
            );
            auto right = fwd.cross(vec3(0, 1, 0));
            auto up    = fwd.cross(right);

            auto input = platform.input;
            auto move_axes = vec3(0, 0, 0);
            bool reset_cam_pos = false, reset_cam_look = false;
            if (input.keys[SbKey.KEY_A].down || input.keys[SbKey.KEY_LEFT].down)  move_axes.x -= 1.0;
            if (input.keys[SbKey.KEY_D].down || input.keys[SbKey.KEY_RIGHT].down) move_axes.x += 1.0;
            if (input.keys[SbKey.KEY_S].down || input.keys[SbKey.KEY_DOWN].down)  move_axes.y -= 1.0;
            if (input.keys[SbKey.KEY_W].down || input.keys[SbKey.KEY_UP].down)    move_axes.y += 1.0;
            if (input.keys[SbKey.KEY_SPACE].down || input.keys[SbKey.KEY_Q].down) move_axes.z += 1.0;
            if (input.keys[SbKey.KEY_SHIFT].down || input.keys[SbKey.KEY_E].down) move_axes.z -= 1.0;

            if (input.keys[SbKey.KEY_R].pressed) {
                final switch (activeRenderer) {
                    case Renderer.SbRenderer: activeRenderer = Renderer.Rev3Renderer; break;
                    case Renderer.Rev3Renderer: activeRenderer = Renderer.SbRenderer; break;
                }
                writefln("Set Renderer: %s", activeRenderer);
            }

            auto look_axes = input.buttons[SbMouseButton.RMB].down ?
                input.cursorDelta * 0.25 :
                vec2(0, 0);
            auto fov_change = -input.scrollDelta.y * 0.25;
            auto far_change = 0.0;

            platform.events.onEvent!(
                (const SbGamepadAxisEvent ev) {
                    move_axes.x += ev.axes[AXIS_LX];
                    move_axes.y -= ev.axes[AXIS_LY];
                    move_axes.z += ev.axes[AXIS_BUMPERS];

                    look_axes.x += ev.axes[AXIS_RX];
                    look_axes.y += ev.axes[AXIS_RY];

                    fov_change += ev.axes[AXIS_TRIGGERS];
                    far_change += ev.axes[AXIS_DPAD_Y];
                },
                (const SbGamepadButtonEvent ev) {
                    reset_cam_pos  |= (ev.button == BUTTON_LSTICK && ev.pressed);
                    reset_cam_look |= (ev.button == BUTTON_RSTICK && ev.pressed);
                }
            );

            cam_pos -= right * move_axes.x * dt * CAM_MOVE_SPEED;
            cam_pos += fwd   * move_axes.y * dt * CAM_MOVE_SPEED;
            cam_pos -= up    * move_axes.z * dt * CAM_MOVE_SPEED;

            cam_angles.x += look_axes.y * dt * CAM_LOOK_SPEED;
            cam_angles.y -= look_axes.x * dt * CAM_LOOK_SPEED;

            fov = max(MIN_FOV, min(MAX_FOV, fov + fov_change * dt * FOV_CHANGE_SPEED));
            far = max(MIN_FAR, min(MAX_FAR, far + far_change * dt * FAR_CHANGE_SPEED));

            if (reset_cam_pos) cam_pos = vec3(0, 0, -5);
            if (reset_cam_look) cam_angles = vec3(0, 0, 0);

            auto view = mat4.look_at( cam_pos, cam_pos + fwd.normalized, up );

            // triangle rotates about y-axis @origin.
            auto model = mat4.yrotation(t).scale( 0.25, 0.25, 0.25 );

            final switch (activeRenderer) {
                case Renderer.SbRenderer: sbRenderer.draw(model, view, proj); break;
                case Renderer.Rev3Renderer: rev3Renderer.draw(model, view, proj); break;
            }            
            platform.swapFrame();
        }
    } catch (Throwable e) {
        writefln("%s", e);
    }
    platform.teardown();
}
