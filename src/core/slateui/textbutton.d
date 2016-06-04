module gsb.core.slateui.textbutton;
import gsb.core.slateui.base_element;
import gsb.utils.signals;


alias TextButtonRenderer = void delegate(UITextButton, GlBatch);
private auto DEFAULT_RENDERER (UITextButton btn, GlBatch batch) {

}

enum TextButtonState {
    INACTIVE, MOUSEOVER, PRESSED
}

class UITextButton : UIElement {
private:
    TextButtonRenderer m_renderer;

    // provides public property `string text()`, and private setters
    // `setTextSrc( string text )`, `setTextSrc( string delegate() getText )`.
    mixin UITextProperty;

    Signal!() m_pressAction;
    Signal!() m_mouseEnterAction;
    Signal!() m_mouseExitAction;

    bool m_pressed = false;
    bool m_mouseover = false;
    double m_timeSinceLastState; // time since last state transition

public:
    this (TextButtonRenderer renderer) {
        m_renderer = renderer;
    }

    @property auto state () { 
        return m_pressed ? TextButtonState.PRESSED :
            m_mouseover ? TextButtonState.MOUSEOVER :
                TextButtonState.INACTIVE;
    }
    @property auto timeSinceLastState () { return m_timeSinceLastState; }

    bool onEvent (UIEvent event) {
        return super.onEvent(event) || event.handle!(
            (MouseEvent ev) {
                bool mouseover = withinBounds(ev.pos);
                bool pressed   = ev.pressed;

                if (mouseover != m_mouseover) {
                    m_mouseover = mouseover;
                    m_timeSinceLastState = 0;

                    if (mouseover)
                        m_mouseEnterAction.emit();
                    else
                        m_mouseExitAction.emit();
                }
                if (pressed != m_pressed) {
                    m_pressed = pressed;
                    m_timeSinceLastState = 0;

                    // Should we emit on press begin or end?
                    // on begin is simpler + more immediate, but native buttons
                    // seem to _usually_ fire on press _exit_, and cancel action if 
                    // mouse moves outside button bounds...
                    immutable auto FIRE_ON_ENTER = true;

                    static if (FIRE_ON_ENTER) {
                        if (pressed)               // button pressed
                            m_pressAction.emit();
                    } else {
                        if (!pressed && mouseover) // button released + mouse still over button
                            m_pressAction.emit();
                    }
                }
            },  
            () { return false; }
        );
    }

    override void render (GlBatch batch, ref FrameInfo frame) {
        m_renderer(this, batch);
        m_timeSinceLastState += frame.dt;
    }
}


mixin template UITextButtonFactory () {
    TextButtonRenderer textbutton_defaultRenderer = &DEFAULT_RENDERER;

    auto textbutton () {
        class PropertyWrapper : UIElementWrapper!(TextButton, PropertyWrapper) {
            this (TextButton target) { super(target); }

            auto renderer (TextButtonRenderer v) {
                return target.m_renderer = v, this;
            }
            auto text ( string v ) {
                return target.setTextSrc(v), this;
            }
            auto text ( string delegate() v ) {
                return target.setTextSrc(v), this;
            }
            auto onPressed ( void delegate() v ) {
                return target.m_pressAction.connect(v), this;
            }
            auto onMouseEnter ( void delegate() v ) {
                return target.m_pressAction.connect(v), this;
            }
            auto onMouseExit ( void delegate() v ) {
                return target.m_mouseExitAction.connect(v), this;
            }
        }
        return new PropertyWrapper(new UITextButton( 
            textbutton_defaultRenderer 
        ));
    }
}

