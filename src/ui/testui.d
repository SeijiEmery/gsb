
module gsb.ui.testui;

import gsb.gl.debugrenderer;
import gsb.core.window;
import gsb.core.pseudosignals;

import gl3n.linalg;
import gsb.glutils;
import gsb.core.color;
import Derelict.glfw3.glfw3;



class UITestModule {
    auto lastPos = vec2(0, 0);
    float size = 50.0;
    vec2[] points;

    ISlot[] slots;
    this () {
        slots ~= g_mainWindow.onMouseMoved.connect((vec2 pos) {
            lastPos = pos;
        });
        slots ~= g_mainWindow.onMouseButtonPressed.connect((Window.MouseButton evt) {
            points ~= lastPos;
        });
        slots ~= g_mainWindow.onGamepadAxesUpdate.connect((float[] axes) {

        });
        slots ~= g_mainWindow.onScrollInput.connect((vec2 scroll) {
            size += scroll.y;
        });
    }
    ~this () {
        foreach (slot; slots)
            slot.disconnect();
    }

    void update () {
        DebugRenderer.drawTri(lastPos, Color("#fadd4c"), size);

        if (points.length) {
                        foreach (point; points) {
                DebugRenderer.drawTri(point, Color(0.0, 1.0, 0.0), 10);
            }

            // vec2[2] nextSeg = [ points[$-1], lastPos ];
            //DebugRenderer.drawLines(nextSeg, Color("#90cc80"), 15);

            DebugRenderer.drawLines([ points[$-1], lastPos ], Color("#e80202"), 10);
            DebugRenderer.drawLines(points, Color("#e37f2d"), 10);
        }
    }
}







































