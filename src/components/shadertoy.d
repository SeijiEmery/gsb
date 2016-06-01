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


class ShaderToyUI : UIComponent {

    override void onComponentInit () {

    }
    override void onComponentShutdown () {

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


