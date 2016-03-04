
module gsb.ui.testui;

import gsb.gl.debugrenderer;
import gsb.core.window;
import gsb.core.pseudosignals;

import gl3n.linalg;
import gsb.glutils;
import gsb.core.color;



class UITestModule {
    auto lastPos = vec2(0, 0);

    Window.onMouseMoved.Connection onMouseMoved;

    this () {
        onMouseMoved = g_mainWindow.onMouseMoved.connect((vec2 pos) {
            lastPos = pos;
        });
    }

    void update () {
        DebugRenderer.drawTri(lastPos, Color("#fadd4c"), 50.0);
    }
}







































