
module gsb.components.terraintest;
import gsb.core.ui.uielements;
import gsb.gl.debugrenderer;
import gsb.gl.graphicsmodule;

import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.gamepad;
import gsb.core.window;
import gsb.core.color;
import gsb.text.font;
import gsb.core.log;
import gl3n.linalg;
import std.array;

private immutable string MT_MODULE = "terrain-test";
private immutable string GT_MODULE = "terrain-renderer";

shared static this () {
    UIComponentManager.runAtInit({
        auto m = new ProceduralTerrainModule();
        GraphicsComponentManager.registerComponent(m.renderer, GT_MODULE, false);
        UIComponentManager.registerComponent(m, MT_MODULE, true);
    });
}

private class ProceduralTerrainModule : UIComponent {

    @property auto renderer () {
        log.write("probably creating renderer... (from %x)", cast(void*)this);
        if (!_renderer) _renderer = new TerrainRenderer(this);
        return _renderer;
    }
    TerrainRenderer _renderer = null;

    override void onComponentInit () {
        log.write("Initializing...");
        GraphicsComponentManager.activateComponent(GT_MODULE);
    }
    override void onComponentShutdown () {
        GraphicsComponentManager.deactivateComponent(GT_MODULE);

    }
    override void handleEvent (UIEvent event) {

    }
}

private class TerrainRenderer : GraphicsComponent {
    ProceduralTerrainModule target;

    this (ProceduralTerrainModule target) {
        log.write("Creating renderer referencing %x", cast(void*)target);
        this.target = target;
    }

    override void onLoad () {
        log.write("loaded!");
    }
    override void onUnload () {
        log.write("unload!");
    }

    uint fc = 100;
    override void render () {
        if (++fc > 60) {
            fc = 0;
            log.write("render!");
        }
    }
}






























