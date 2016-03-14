
module gsb.core.ui.uilayout;

import gl3n.linalg;
import std.variant;

interface ILayoutable {
    //@property vec2 dim ();
    //@property vec2 pos ();
    //void doLayout ();
}

interface IRenderable {
    void render ();
}
interface IResource {
    void release ();
}

enum RelLayoutDirection : ubyte { HORIZONTAL, VERTICAL };
enum RelLayoutPosition  : ubyte {
    CENTER, CENTER_LEFT, CENTER_RIGHT, CENTER_TOP, CENTER_BTM,
    TOP_LEFT, TOP_RIGHT, BTM_LEFT, BTM_RIGHT
}








































