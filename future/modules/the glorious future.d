module mymodule.statgraph2;
import sandbox.sbmodule;
import sandbox.gl;
import sandbox.slateui;

version (gsb_static) {
    shared static this () { sbInstance.registerCtor(sbInit); }
} else {
    void gsb_init (SbgContext ctx) { sbInit(ctx.module_); }
}

private void sbInit (SbModule sb) {
    sb.name = "statgraph2";
    auto slate = sb.slate;

    // create a panel to hold our ui controls
    auto panel = slate.create!Panel
                    .resizable(true)
                    .border(rgba!"#fa9f3f80", pixels!4)
                    .background(rgba!"ff4f5f20")
                    .font("menlo");

    // set module action focus to panel (keyboard focus, mouse events, etc)
    sb.setEventFocus(panel);

    panel.closeAction((p) => p.hide);
    sb.registerHotkey("t", {
        panel.toggleHidden;
    });

    // Define a subregion for our graph, and a 2d canvas.
    auto inner = slate.region.scaled(0.9, 0.9);
    auto canvas = slate.canvas(inner);
    canvas.onRedraw((FrameContext frame) {

        auto stats = frame.engine.getStats;

        // and redraw...
    });

    // If we want to do 3d stuff:
    auto glRegion = slate.glRegion(inner);
    glRegion.setCamera( sb.getMainCamera );

    glRegion.onRedraw((FrameContext frame, GlContext gl) {
        auto shader = gl.create!Shader
            .glversion_410
            .fragment(`
                ...
            `)
            .vertex(`
                ...
            `);
        shader.uniforms.mvp = glRegion.camera.mvp;
        auto model = gl.model.fromFile("monkey.obj");
        gl.draw(shader, model, glOpts.transparent(false) | glOpts.msaa(true));
    });


    // Called when module terminates: do cleanup, etc.
    sb.dtor!({
        // slate should be capable of cleaning up after itself though, so we shouldn't
        // need to do anything.
    });

    // Serialize / deserialize module state
    sb.serialize_save!((Serializer s) {
        panel.serialize(s);
    });
    sb.serialize_load!((Serializer s) {
        panel.deserialize(s);
    });

    // Won't be needed, but events would probably work like this
    sb.onEvent!(EvFocus.Any, (MouseMoveEvent ev) {
        // ...
    });
    sb.onEvent!(EvFocus.Any, (MouseButtonEvent ev) {

    });
    sb.onUpdate!((FrameUpdate frame) {
        // frame.dt, ...
    });
}
