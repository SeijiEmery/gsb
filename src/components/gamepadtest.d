
module gsb.components.gamepadtest;
import gsb.core.ui.uielements;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.gamepad;
import gsb.core.window;
import gsb.core.color;
import gsb.text.font;
import gsb.core.log;
import gl3n.linalg;
import std.array;

private immutable string FONT = "menlo";
private immutable string MODULE_NAME = "gamepad-test";

private immutable auto TEXT_COLOR_WHITE = Color(1,1,1, 0.85);
private immutable auto TEXT_COLOR_GRAY  = Color(0.65,0.65,0.65, 0.85);
private immutable auto BACKGROUND_BORDER_COLOR = Color(1,0.08,0.08, 0.5);
private immutable auto BACKGROUND_PANEL_COLOR  = Color(0.38,0.38,0.38, 0.08);

private immutable bool LOG_BUTTON_PRESSES = false;

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new GamepadTestModule(), MODULE_NAME, true);
    });
}

private class GamepadTestModule : UIComponent {
    UIElement root;
    UIDecorators.Draggable!UILayoutContainer container;
    UITextElement headerText;
    UITextElement infoLog;
    string infoLogText = "";

    GamepadState[uint] gamepadStates;
    GamepadStatusPanel[uint] gamepadUI;
    bool dirtyGamepadConnections = true;
    float textSize = 18.0;

    int curFrame = 0;

    static struct GamepadState {
        int id;
        GamepadProfile profile;
        string deviceName;
        uint naxes, nbuttons;
        bool  [NUM_GAMEPAD_BUTTONS] buttons = 0;
        float [NUM_GAMEPAD_AXES]    axes = 0;
    }
    class GamepadStatusPanel {
        UILayoutContainer container;
        UITextElement     info;
        UITextElement[NUM_GAMEPAD_BUTTONS] buttons;
        UITextElement[NUM_GAMEPAD_AXES]    axes;

        this (ref GamepadState state) {
            auto font = new Font(FONT, textSize);

            auto buttonText (string text) {
                return new UITextElement(vec2(3,3), text, font, TEXT_COLOR_WHITE);
            }
            container = new UILayoutContainer(LayoutDir.VERTICAL, Layout.TOP_LEFT, vec2(0,0), vec2(0,0), vec2(5,5), 5, [
                info = new UITextElement(vec2(3,3), "", font, TEXT_COLOR_WHITE),
                new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.TOP_LEFT, vec2(0,0), vec2(0,0), vec2(0,0), 10, [
                    buttons[BUTTON_A] = buttonText("A"),
                    buttons[BUTTON_B] = buttonText("B"),
                    buttons[BUTTON_X] = buttonText("X"),
                    buttons[BUTTON_Y] = buttonText("Y"),
                    buttons[BUTTON_LBUMPER] = buttonText("LB"),
                    buttons[BUTTON_RBUMPER] = buttonText("RB"),
                    buttons[BUTTON_LTRIGGER] = buttonText("LT"),
                    buttons[BUTTON_RTRIGGER] = buttonText("RT"),
                    buttons[BUTTON_LSTICK] = buttonText("LS"),
                    buttons[BUTTON_RSTICK] = buttonText("RS"),
                ]),
                new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.TOP_LEFT, vec2(0,0), vec2(0,0), vec2(0,0), 10, [
                    buttons[BUTTON_DPAD_UP] = buttonText("DPAD_UP"),
                    buttons[BUTTON_DPAD_DOWN] = buttonText("DPAD_DOWN"),
                    buttons[BUTTON_DPAD_LEFT] = buttonText("DPAD_LEFT"),
                    buttons[BUTTON_DPAD_RIGHT] = buttonText("DPAD_RIGHT"),
                    buttons[BUTTON_START] = buttonText("START"),
                    buttons[BUTTON_SELECT] = buttonText("SELECT"),
                    buttons[BUTTON_HOME] = buttonText("HOME"),
                ]),
                new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.TOP_LEFT, vec2(0,0), vec2(0,0), vec2(0,0), 10, [
                    buttonText("left-stick:  "), axes[AXIS_LX] = buttonText(""), axes[AXIS_LY] = buttonText("")
                ]),
                new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.TOP_LEFT, vec2(0,0), vec2(0,0), vec2(0,0), 10, [
                    buttonText("right-stick: "), axes[AXIS_RX] = buttonText(""), axes[AXIS_RY] = buttonText("")
                ]),
                new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.TOP_LEFT, vec2(0,0), vec2(0,0), vec2(0,0), 10, [
                    buttonText("triggers:    "), axes[AXIS_LTRIGGER] = buttonText(""), axes[AXIS_RTRIGGER] = buttonText("")
                ]),
                new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.TOP_LEFT, vec2(0,0), vec2(0,0), vec2(0,0), 10, [
                    buttonText("dpad:        "), axes[AXIS_DPAD_X] = buttonText(""), axes[AXIS_DPAD_Y] = buttonText("")
                ]),
            ]);
            update(state);
        }
        void update (ref GamepadState state) {
            info.text = format("slot %d  %s  device name '%s' buttons: %d axes: %d", 
                state.id, state.profile, state.deviceName, state.nbuttons, state.naxes);
            foreach (i; 0 .. NUM_GAMEPAD_BUTTONS)
                buttons[i].color = state.buttons[i] ? TEXT_COLOR_WHITE : TEXT_COLOR_GRAY;
            foreach (i; 0 .. NUM_GAMEPAD_AXES) {
                axes[i].color = state.axes[i] ? TEXT_COLOR_WHITE : TEXT_COLOR_GRAY;
                axes[i].text  = format("%s %0.4f", cast(GamepadAxis)i, state.axes[i]);
            }
            container.dim = vec2(0,0);
        }
        void release () {
            container.release();
        }
    }

    override void onComponentInit () {
        root = container = new UIDecorators.Draggable!UILayoutContainer(
            LayoutDir.VERTICAL, Layout.TOP_LEFT, vec2(50,50), vec2(400,200), vec2(5,5), 5, [
                headerText = new UITextElement(vec2(10,10), "", new Font(FONT, textSize), TEXT_COLOR_WHITE),
                infoLog    = new UITextElement(vec2(10,10), "", new Font(FONT, textSize), TEXT_COLOR_WHITE),
            ]
        );
    }
    override void onComponentShutdown () {
        if (root) { 
            root.release(); 
            root = container = null;
            foreach (k, v; gamepadStates)
                gamepadStates.remove(k);
            foreach (k, v; gamepadUI)
                gamepadUI.remove(k); 
        }
    }
    void updateUI () {
        if (dirtyGamepadConnections) {
            dirtyGamepadConnections = false;
            foreach (k, v; gamepadUI) {
                if (k !in gamepadStates) {
                    v.release();
                    gamepadUI.remove(k);
                }
            }
            foreach (k, v; gamepadStates) {
                if (k !in gamepadUI) {
                    gamepadUI[k] = new GamepadStatusPanel(v);
                } else {
                    gamepadUI[k].update(v);
                }
            }

            headerText.text = format("%d gamepads connected", gamepadUI.length);
            container.elements.length = 1;
            container.elements ~= cast(UIElement[])( gamepadUI.values.map!"a.container".array );
            static if (LOG_BUTTON_PRESSES)
                container.elements ~= cast(UIElement) infoLog;
        } else {
            foreach (k, v; gamepadStates) {
                gamepadUI[k].update(v);
            }
        }
        root.recalcDimensions();
        root.doLayout();
        DebugRenderer.drawLineRect(root.pos, root.pos + root.dim, BACKGROUND_BORDER_COLOR, 1);
        DebugRenderer.drawRect(root.pos - vec2(1,1), root.pos + root.dim - vec2(1,1), BACKGROUND_PANEL_COLOR);
    }
    override void handleEvent (UIEvent event) {
        if (root) event.handle!(
            (GamepadConnectedEvent ev) {
                if (ev.id !in gamepadStates) {
                    gamepadStates[ev.id] = GamepadState(ev.id, ev.profile, ev.name, ev.numAxes, ev.numButtons);
                    dirtyGamepadConnections = true;
                }
            },
            (GamepadDisconnectedEvent ev) {
                if (ev.id in gamepadStates) {
                    gamepadStates.remove(ev.id);
                    dirtyGamepadConnections = true;
                }
            },
            (GamepadAxisEvent ev) {
                if (ev.id in gamepadStates) {
                    gamepadStates[ev.id].axes[0 .. NUM_GAMEPAD_AXES] = ev.axes[0 .. NUM_GAMEPAD_AXES];
                }
            },
            (GamepadButtonEvent ev) {
                if (ev.id in gamepadStates) {
                    gamepadStates[ev.id].buttons[ev.button] = ev.pressed;
                    static if (LOG_BUTTON_PRESSES) {
                        infoLogText ~= format("%d [%d]: %s %s\n",
                        curFrame, ev.id, ev.button, ev.pressed ? "pressed" : "released");
                        infoLog.text = infoLogText;
                    }
                }
            },
            (MouseButtonEvent ev) {
                static if (LOG_BUTTON_PRESSES) {
                    if (ev.pressed && ev.isRMB) {
                        infoLogText = "";
                        infoLog.text = infoLogText;
                    }
                }
                root.handleEvents(event);
            },
            (FrameUpdateEvent ev) {
                updateUI();
                ++curFrame;
            },
            () {
                root.handleEvents(event);
            }
        );
    }
}

