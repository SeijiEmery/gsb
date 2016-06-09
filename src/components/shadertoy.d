module gsb.components.shadertoy;
import gsb.core.slate2d;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.ui.uielements;
import gsb.core.log;
import gl3n.linalg;

shared static this () {
    //UIComponentManager.runAtInit({
    //    UIComponentManager.registerComponent(
    //        new ShaderToyUI(), "shadertoy", true);
    //});
}

private struct ShaderFileScanner {
    void doScan () {}
}

private struct ShaderFileUI {
    UIElement root;
    UILayoutContainer fileList;
    UITextElement[]   fileButtons;

    void createUI () {
        if (root) teardownUI();
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


