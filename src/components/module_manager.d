
module gsb.components.module_manager;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.utils.signals;
import gsb.core.log;
import gsb.core.window;
import gsb.utils.color;
import gsb.text.textrenderer;
import gsb.text.font;
import gsb.core.ui.uielements;
import gl3n.linalg;
import std.array;
import std.algorithm.iteration;
import std.format;

private immutable string FONT = "menlo";
private immutable string MODULE_NAME = "module-manager";

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new ModuleController(), MODULE_NAME, true);
    });
}

private class ModuleController : UIComponent {
    UIElement root;
    UILayoutContainer container;

    string[] activeComponents;

    auto ACTIVE_COLOR   = Color(0.94, 0.87, 0.40, 0.97);
    auto INACTIVE_COLOR = Color(0.44, 0.87, 0.90, 0.95);
    auto BACKGROUND_COLOR = Color(0.9, 0.9, 0.9, 0.4);

    float fontSize = 18.0;

    UIElement createUIForModule (UIComponent component_) {

        auto font = new Font(FONT, fontSize);
        class Foo : UITextElement {
            this (UIComponent component) {
                super(vec2(0,0), vec2(0,0), vec2(5,5), "", font, INACTIVE_COLOR, BACKGROUND_COLOR);
                this.component = component;
                updateStuff();
                recalcDimensions();
                doLayout();
            }
            UIComponent component;
            void updateStuff () {
                text = format("%s(%s)", component.name, component.active ? "active" : "inactive");
                color = component.active ? ACTIVE_COLOR : INACTIVE_COLOR;
            }
            override bool handleEvents (UIEvent event) {
                return event.handle!(
                    (MouseButtonEvent evt) {
                        if (mouseover && evt.pressed && evt.isLMB) {
                            if (component.active && component.name != MODULE_NAME) UIComponentManager.deleteComponent(component.name);
                            else if (!component.active) UIComponentManager.createComponent(component.name);
                            updateStuff();
                            return true;
                        }
                        return false;
                    },
                    () { return false; }
                ) || super.handleEvents(event);
            }
        }
        return new Foo(component_);
        // Yay for shitty java-style inheritance + ad-hoc class extensions /s
    }

    ISlot[] slots;

    override void onComponentInit () {
        auto SLIDER_COLOR     = Color(0.8, 0.6, 0.6, 0.5);
        auto BACKGROUND_COLOR = Color(0.5, 0.7, 0.5, 0.5);

        auto components = UIComponentManager.getComponentList().values;
        slots ~= UIComponentManager.onComponentRegistered.connect((UIComponent component, string name) {
            container.elements ~= createUIForModule(component);
        });

        UIElement[] labels;
        labels ~= new UITextElement(vec2(),vec2(),vec2(5,5), format("%d components", components.length),
                    new Font(FONT, fontSize), INACTIVE_COLOR, BACKGROUND_COLOR);
        foreach (component; components)
            labels ~= createUIForModule(component);

        foreach (label; labels)
            label.recalcDimensions();

        root = container = new UIDecorators.Draggable!UILayoutContainer(
            LayoutDir.VERTICAL, Layout.TOP_LEFT,
            vec2(5, 700), vec2(0,0), vec2(10,10), 0.0, labels
        );
    }
    override void onComponentShutdown () {
        if (root) {
            // Clean up like we're supposed to
            root.release();
            root = null;

            foreach (slot; slots)
                slot.disconnect();
            slots.length = 0;
        }
    }

    override void handleEvent (UIEvent event) {
        if (!root)
            return;
        event.handle!(
            (FrameUpdateEvent ev) {
                root.recalcDimensions();
                root.doLayout();
                root.render();
            },
            () {
                root.handleEvents(event);
            }
        )();
    }
}











