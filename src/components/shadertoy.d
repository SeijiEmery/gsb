module gsb.components.shadertoy;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;




shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(
            new ShaderToyUI(), "shadertoy", true);
    });
}

private struct ShaderFileScanner {

}

interface Shape2d {
    vec4 getRect ();
    bool containsPoint (vec2 pt);
    bool containsShape (Shape2d shape);

    vec2 center ();
    mat3 matrix_transform ();
}

interface ShapePhysics {
    vec3 center_position ();
    mat3 matrix_transform ();

    void applyMotion (
        double dt,
        vec3 velocity,
        vec3 angular_velocity );
}

interface GraphImpl {
    void addChild (UIObj);
    void setParent (UIObj);

    UIObj getParent ();
    void  visitChildren (void delegate(UIObj));
    void  visitChildren (
        bool delegate (UIObj) pred,
        void delegate (UIObj) visitor
    );
}
struct UIState {
    bool mouseover = false;
    bool clicked   = false;


}




class UIObj {




}























interface slateui_shape {
    rect4f aabbRect ();
    bool   containsPoint ()




}



class slateui_objmodel {
    vec2 pos () {}
    vec2 dim () {}



}




class slateui_baseobj {





}













class UIClickable (T) : T {
    // private bool mouseover = false; -- inherited from UIElement
    private bool pressed = false;

    override bool handleEvents (UIEvent event) {
        return event.handle!(
            (MouseMoveEvent ev) {
                auto prevMouseover = mouseover;

            }



        );
    }



}



class UIButton (T) : T {
    //private bool mouseover = false; -- inherited from UIElement
    private bool pressed   = false;









    private enum ButtonState { Mouseover }
}






struct UIButton {

}
private struct ShaderFileUI {
    UIElement root;
    UILayoutContainer fileList;
    UITextElement[]   fileButtons;

    void createUI () {
        if (root) teardownUI();

        root = new UIContainer(vec2(), vec2(), cast(UIElement[])[
            new UITextElement()


        ]);

    }
    void teardownUI () {
        if (root) {
            root.release();
            root = null;
        }
    }
}

private class ShaderToyUI : UIComponent {
    ShaderFileScanner fs;
    ShaderFileUI      ssui;

    override void onComponentInit () {
        fs.doScan();
        ssui.createUI();
    }
    override void onComponentShutdown () {
        ssui.teardownUI();
    }
    override void handleEvent (UIEvent event) {
        event.handle!(
            (MouseMoveEvent ev) {

            },
            (MouseButtonEvent ev) {

            },
            (KeyboardEvent ev) {

            },
            (FrameUpdateEvent ev) {

            },
            () {}
        );
    }
}


