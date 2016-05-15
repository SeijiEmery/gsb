
module gsb.components.terraintest;
import gsb.core.ui.uielements;
import gsb.gl.debugrenderer;
import gsb.gl.graphicsmodule;

import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.input.gamepad;
import gsb.core.window;
import gsb.utils.color;
import gsb.text.font;
import gsb.core.log;
import gl3n.linalg;
import std.array;

import gsb.gl.algorithms;
import gsb.gl.state;
import gsb.glutils;
import derelict.opengl3.gl3;

private immutable string MT_MODULE = "terrain-test";
private immutable string GT_MODULE = "terrain-renderer";

private immutable auto TEXT_COLOR_WHITE = Color(1,1,1, 0.85);
private immutable auto FONT = "menlo";

auto SLIDER_FOREGROUND_COLOR = Color(0.85, 0.85, 0.85, 0.85);
auto SLIDER_BACKGROUND_COLOR = Color(0.35, 0.35, 0.35, 0.65);

shared static this () {
    //UIComponentManager.runAtInit({
    //    auto m = new ProceduralTerrainModule();
    //    GraphicsComponentManager.registerComponent(m.renderer, GT_MODULE, false);
    //    UIComponentManager.registerComponent(m, MT_MODULE, true);
    //});
}

private struct Camera {
    vec3 pos = vec3(0,0,0);
    vec3 localVelocity = vec3(0,0,0);
    vec3 angles = vec3(0,0,0);

    @property quat rot () {
        return quat.identity
            .rotatey(angles.x)
            .rotatex(angles.y);
    }

    void update (float dt) {
        pos += quat.identity.rotatey(angles.x) * localVelocity;
    }
}


private class ProceduralTerrainModule : UIComponent {
    Camera camera;
    GUI gui = null;
    bool flipMatrix = false;
    bool doTranspose = true;

    @property auto renderer () {
        log.write("probably creating renderer... (from %x)", cast(void*)this);
        if (!_renderer) _renderer = new TerrainRenderer(this);
        return _renderer;
    }
    TerrainRenderer _renderer = null;

    override void onComponentInit () {
        log.write("Initializing...");
        GraphicsComponentManager.activateComponent(GT_MODULE);
        if (!gui) gui = new GUI();
    }
    override void onComponentShutdown () {
        GraphicsComponentManager.deactivateComponent(GT_MODULE);
        if (gui) { gui.release(); gui = null; }
    }
    override void handleEvent (UIEvent event) {
        event.handle!(
            (GamepadAxisEvent ev) {
                camera.localVelocity = vec3(ev.AXIS_LX, (ev.AXIS_RT - ev.AXIS_LT), ev.AXIS_LY) * gui.camSpeedSlider.value;
                if (ev.AXIS_RX) camera.angles.x += (ev.AXIS_RX / 60f);
                if (ev.AXIS_RY) camera.angles.y += (ev.AXIS_RY / 60f);
            },
            (GamepadButtonEvent ev) {
                if (ev.pressed && ev.button == BUTTON_LSTICK) camera.pos = vec3(0,1,0);
                if (ev.pressed && ev.button == BUTTON_RSTICK) camera.angles = vec3(0,0,0);
                if (ev.pressed && ev.button == BUTTON_RBUMPER) flipMatrix = !flipMatrix;
                if (ev.pressed && ev.button == BUTTON_LBUMPER) doTranspose = !doTranspose;
            },
            (FrameUpdateEvent ev) {
                camera.update(ev.dt);
                gui.update();
            },
            () {
                gui.handleEvents(event);
            }
        );
    }

    private class GUI {
        UIElement root;
        alias root this;

        UITextElement status;
        UITextElement camSpeedText;
        UISlider      camSpeedSlider;
        UISlider      drawSlider;
        float fontSize = 18.0;

        this () {
            root = new UIDecorators.Draggable!UILayoutContainer(LayoutDir.VERTICAL, Layout.CENTER, vec2(0,0), 5, [
                status = new UITextElement(vec2(5,5), "", new Font(FONT, fontSize), TEXT_COLOR_WHITE),
                new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.CENTER, vec2(0,0), 10, [
                    camSpeedText = new UITextElement(vec2(5,5), "", new Font(FONT, fontSize), TEXT_COLOR_WHITE),
                    camSpeedSlider = new UISlider(vec2(0,0), vec2(250,30), vec2(5,5), vec2(30,18), 1.0, 0.2, 20.0, SLIDER_BACKGROUND_COLOR, SLIDER_FOREGROUND_COLOR),
                    drawSlider = new UISlider(vec2(0,0), vec2(250,30), vec2(5,5), vec2(30,18), 1.0, 0.0, 1.0, SLIDER_BACKGROUND_COLOR, SLIDER_FOREGROUND_COLOR),
                ]),
            ]);
        }
        void update () {
            auto l = 0;
            //auto l = _renderer && _renderer.chunk && _renderer.chunk.geometry ?
            //    _renderer.chunk.geometry.length : 0;

            status.text = format("camera.position: %s\ncamera.angles: %s\ncamera.rotation: %s\nflip matrix: %s, do transpose: %s\ngeometry: %d (%d)", 
                camera.pos, camera.angles * 180 / PI, camera.rot, flipMatrix, doTranspose, l, l / 8);
            camSpeedText.text = format("%0.2f", camSpeedSlider.value);
            root.recalcDimensions();
            root.doLayout();
            root.render();
        }
    }
}

vec4[] pointGrid (uint N, uint M)() {
    vec4[] points;

    float ki = 1.0 / N, kj = 1.0 / M;
    foreach (float i; 0 .. (N-1)) {
        foreach (float j; 0 .. (M-1)) {
            points ~= [
                vec4(ki * i,   0, kj * j,   1),
                vec4(ki * i+1, 0, kj * j,   1),
                vec4(ki * i+1, 0, kj * j+1, 1),
                vec4(ki * i,   0, kj * j,   1),
                vec4(ki * i,   0, kj * j+1, 1),
            ];
        }
    }
    return points;
}

private class TerrainChunk {
    float[] geometry;
    VAO     vao;

    this (Color color, mat4 transform) {
        void pushPoint (vec4 p, Color c) {
            geometry ~= [ p.x, p.y, p.z, p.w, c.r, c.g, c.b, c.a ];
        }

        auto BLUE = Color(0, 0.5, 1, 0.85);
        pushPoint(vec4(0, 1e-3, 0, 1) * transform, BLUE);
        pushPoint(vec4(1, 1e-3, 0, 1) * transform, BLUE);
        pushPoint(vec4(1, 1e-3, 1, 1) * transform, BLUE);
        pushPoint(vec4(0, 1e-3, 1, 1) * transform, BLUE);
        pushPoint(vec4(0, 1e-3, 0, 1) * transform, BLUE);

        foreach (point; pointGrid!(100, 100)) {
            pushPoint(point * transform, color);
        }
    }
    void draw (float percent) {
        if (!vao) vao = new VAO();
        DynamicRenderer.drawArrays(vao, GL_LINE_STRIP, 0, cast(int)((cast(float)geometry.length) / 8 * percent), [
            VertexData( geometry.ptr, geometry.length * float.sizeof, [
                VertexAttrib( 0, 4, GL_FLOAT, GL_FALSE, float.sizeof * 8, cast(void*)( 0 )),
                VertexAttrib( 1, 4, GL_FLOAT, GL_FALSE, float.sizeof * 8, cast(void*)( float.sizeof * 4 )),
            ])
        ]);
    }
    void release () { if (vao) { vao.release(); vao = null; } }
}


private class TerrainRenderer : GraphicsComponent {
    ProceduralTerrainModule target;
    TerrainShader shader = null;
    TerrainChunk[] chunks;

    this (ProceduralTerrainModule target) {
        log.write("Creating renderer referencing %x", cast(void*)target);
        this.target = target;
    }

    override void onLoad () {
        log.write("loaded!");
        if (!shader)
            shader = new TerrainShader();

        uint W = 1, H = 1;
        float chunkSize = 100.0;

        foreach (i; 0 .. W) {
            foreach (j; 0 .. H) {
                chunks ~= new TerrainChunk(
                    Color(0.5, cast(float)i / cast(float)W, cast(float)j / cast(float)H, 0.85),
                    mat4.identity()
                        .translate(cast(float)(i - W / 2) - 0.5, 0, cast(float)(j - H / 2) - 0.5)
                        .scale(chunkSize, chunkSize, chunkSize)
                );
            }
        }
    }
    override void onUnload () {
        log.write("unload!");
        foreach (chunk; chunks)
            chunk.release();
        chunks.length = 0;
    }

    uint fc = 100;
    override void render () {
        if (++fc > 60) {
            fc = 0;
            log.write("render! (cam %s %s)", target.camera.pos, target.camera.rot);
        }

        float fov = 60;
        float near = 0.1, far = 1e3;

        auto projection = mat4.perspective(
            g_mainWindow.pixelDimensions.x, g_mainWindow.pixelDimensions.y,
            fov, near, far);

        auto view = target.camera.rot.to_matrix!(4,4) * (mat4.translation(target.camera.pos));
        //auto view = target.flipMatrix ?
        //     mat4.translation(target.camera.pos) * target.camera.rot.to_matrix!(4,4) :
        //     target.camera.rot.to_matrix!(4,4) * mat4.translation(target.camera.pos);

        //auto view = target.camera.rot.to_matrix!(4,4)
        //    .translate(target.camera.pos);

        auto matrix = projection * view;
        //auto matrix = target.flipMatrix ?
        //    view * projection :
        //    projection * view;
        //if (target.doTranspose)
        matrix.transpose();

        shader.bind();
        shader.mvp = matrix;
        foreach (chunk; chunks) {
            chunk.draw(target.gui.drawSlider.value);
        }
        //chunk.draw(vao,  target.gui.drawSlider.value / cast(float)(chunk.geometry.length));
    }

    private static class TerrainShader {
        import dglsl;

        static class VertexShader : Shader!Vertex {
            @layout(location=0)
            @input vec3 position;

            @layout(location=1)
            @input vec4 inColor;

            @uniform mat4 mvp;

            @output vec4 passThroughColor;

            void main () {
                gl_Position = mvp * vec4(position, 1.0);
                passThroughColor = inColor;
            }
        }
        static class FragmentShader : Shader!Fragment {
            @input vec4 passThroughColor;
            @output vec4 fragColor;
            void main () {
                fragColor = passThroughColor;
            }
        }

        Program!(VertexShader,FragmentShader) program;
        alias program this;

        this () {
            auto vs = new VertexShader();   vs.compile(); CHECK_CALL("Compiling vertex");
            auto fs = new FragmentShader(); fs.compile(); CHECK_CALL("Compiling fragment");
            program = makeProgram(vs, fs); CHECK_CALL("compiling/linking program");
        }
        void bind () {
            glState.bindShader(program.id);
        }
    }
}






























