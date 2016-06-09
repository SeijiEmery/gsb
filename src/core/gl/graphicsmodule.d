
module gsb.gl.graphicsmodule;
import gsb.core.log;
import gsb.utils.signals;
import gsb.core.singleton;
import gsb.core.stats;
import gsb.engine.engine_interface: FrameTime;
import std.format;
import std.algorithm.sorting;


class GraphicsComponent {
    abstract void onLoad ();
    abstract void onUnload ();
    abstract void render ();

    @property auto name () { return _name; }
    @property auto id () { return _id; }
    @property auto active () { return _active; }
    @property auto priority () { return _priority; }

    private string _name;
    private ulong  _id = 0;
    private uint   _priority = 0;
    private bool   _active = false;
    private bool   _needsInit = false;
    private bool   _needsDeinit = false;
}

public @property auto GraphicsComponentManager () {
    return GraphicsComponentManagerInstance.instance;
}

private class GraphicsComponentManagerInstance {
    mixin LowLockSingleton;

    // attach to on main thread
    public Signal!(string, GraphicsComponent) onComponentLoaded;
    public Signal!(string, GraphicsComponent) onComponentUnloaded;
    public Signal!(string, GraphicsComponent) onComponentRegistered;

    private GraphicsComponent[] components;
    //private GraphicsComponent[] pendingComponents;
    private ulong nextComponentId = 1;

    // temp shared lists -- gt writes, mt reads + clears
    private GraphicsComponent[] pendingComponentLoadSignals;
    private GraphicsComponent[] pendingComponentUnloadSignals;

    // temp lists used only on graphics thread
    private GraphicsComponent[] tmp_queuedInit;
    private GraphicsComponent[] tmp_queuedDeinit;

    void updateFromGraphicsThread () {
        synchronized {
            //components ~= pendingComponents;
            //pendingComponents.length = 0;

            tmp_queuedInit.length = 0;
            tmp_queuedDeinit.length = 0;
            for (auto i = components.length; i --> 0; ) {
                auto component = components[i];
                if (component._needsInit && !component._active) {
                    component._needsInit = false;
                    component._active = true;
                    tmp_queuedInit ~= component;
                    pendingComponentLoadSignals ~= component;
                } else if (component._needsDeinit && component._active) {
                    component._needsDeinit = false;
                    component._active = false;
                    tmp_queuedDeinit ~= component;
                    pendingComponentUnloadSignals ~= component;
                }
            }
        }
        if (tmp_queuedInit.length) {
            foreach (component; tmp_queuedInit) {
                component.onLoad();
            }
        }
        if (tmp_queuedDeinit.length) {
            foreach (component; tmp_queuedDeinit) {
                component.onUnload();
            }
        }
        if (tmp_queuedInit.length || tmp_queuedDeinit.length)
            components.sort!"a.active && !b.active || a.id < b.id"();

        foreach (component; components) {
            if (component.active) {
                component.render();
            }
        }
    }

    void updateFromMainThread ( FrameTime ft ) {
        if (pendingComponentLoadSignals.length || pendingComponentUnloadSignals.length) {
            GraphicsComponent[] recentlyLoaded, recentlyUnloaded;
            synchronized {
                recentlyLoaded = pendingComponentLoadSignals;
                recentlyUnloaded = pendingComponentUnloadSignals;
                pendingComponentLoadSignals.length = 0;
                pendingComponentUnloadSignals.length = 0;
            }
            foreach (component; recentlyLoaded)
                onComponentLoaded.emit(component.name, component);
            foreach (component; recentlyUnloaded)
                onComponentUnloaded.emit(component.name, component);
        }
    }

    void registerComponent (GraphicsComponent component, string name, bool active = true) {
        synchronized {
            foreach (component_; components) {
                if (component_.name == name) {
                    throw new Exception(format("Already registered component '%s'", name));
                }
            }

            component._id = nextComponentId++;
            component._name = name;
            component._needsInit = active;
            components ~= component;
        }
    }

    void activateComponent (string name) {
        synchronized {
            foreach (component; components) {
                if (component.name == name) {
                    component._needsInit = true;
                    return;
                }
            }
            throw new Exception(format("No registered component '%s'", name));
        }
    }
    void deactivateComponent (string name) {
        synchronized {
            foreach (component; components) {
                if (component.name == name) {
                    component._needsDeinit = true;
                    return;
                }
            }
            throw new Exception(format("No registered component '%s'", name));
        }
    }
}



