import sb.sbmodule;

void __sbEnterModule ( ISandboxedApp app ) {
    app.createModule!MyModule("gl_test_01");
}
void __sbExitModule ( ISandboxedApp app ) {}

class MyModule : ISandboxedModule {
    mixin SbBaseModule!(MyModule,
        SbService.log | SbService.gl | SbService.events
    );

    // mixin handles event method wiring (w/ static checking
    // at compile time, and dynamic checks), ctor + service
    // setup, which includes automatic memory/resource cleanup
    // and dtors, etc., 

    void onInit () {
        assert(this.name == "gl_test_01");
        log.write("Hello world!");

        static assert(is(gl == ISandboxedGraphicsBatch));
        static assert(is(log == ISandboxedLogger));
        static assert(is(events == ISandboxedEventManager));

        myShader = gl.createShader()
            .vsFile("triangleShader.vs")
            .fsFile("triangleShader.fs");

        float[] geometry = {
            // ...
        };
        myBuffer = gl.createBuffer()
            .bufferData(geometry);
        myInstanceBuffer = gl.createBuffer();

        myCmd = gl.createCmd()
            .shader(myShader)
            .vertexBuffer( myInstanceBuffer, 0, 12, GL_FLOAT );
            // ...
    }
    void onTeardown () {}
    void onUpdate (SbFrame frame) {
        gl.setUniform(myShader, "mvp", frame.activeCamera.mvp);
        gl.drawInstanced( myCmd, myInstanceBuffer );

        auto dv = CAM_SPEED * dt (
            events.kb_input.wasd_axes +   // sum of wasd + arrow key axes. User definable in via kb-event impl.
            events.gamepad_input.all.left_xy_axes   // sum of left stick inputs for all connnected gamepads
        );
        auto rot = CAM_MOUSE_SENSITIVITY * events.kb_input.mouse_delta_xy * dt +
            CAM_GAMEPAD_SENSITIVITY * events.gamepad_input.all.right_xy_axes;

        // Need some async event API for objects like the camera -- NO DIRECT STATE MANIPULATION!
        // (though ofc we could fake it w/ wrappers)
        events.send(activeCamera, MoveEvent(dv));
        events.send(activeCamera, RotateEvent(rot.eulerToQuat));

        // Also: we'd ideally want to set a camera controller object (and have that represented as
        // another service or something), rather than doing direct state changes in a running module...

        // ofc we could implement camera controller _as_ a running module; it would have exclusive(ish)
        // control of camera state (service), and modules like this one would just make sure that it's running

        // Though in that case, we _absolutely_ need either:
        // – camera state set using async events run before module updates
        // - or camera module is flagged to run before everything else (or at least consistently;
        //   camera updates must happen synchonously BEFORE other updates referencing state, or
        //   we'll have issues w/ jerky camera movement...)
    }

    DrawCmd         myCmd;
    IShader         myShader;
    IGeometryBuffer myBuffer;
    IGeometryBuffer myInstanceBuffer;
}







































