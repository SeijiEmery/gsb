module gsb.core.slate.slateui2;

//
// 3 kinds of ui:
// - views / adaptors (sliders, checkboxes, adaptive labels, text fields, lists/graphs of any sort)
// - stateful ui (text buttons)
// - hybrids     (dropdowns / selection menus: listview and stateful w/ actions + state transitions)
//



enum BtnState { Out = 0, Mouseover, Pressed }

mixin template slateui_buttonstate {
    Signal!() onClick;
    string delegate() getText = null;
    IButtonRenderer[BtnState.max] btnRenderers;

    bool st_mouseover = false;
    bool st_pressed   = false;
    double timeSinceLastAction = 0;
    uint mouseButtonBitmap = 0xff;
}
private mixin template slateui_buttoncomponent {
    bool handleEvent (UIEvent event) {
        void notifyStateChanged () {
            timeSinceLastAction = 0;
        }
        bool handled = false;
        return event.handle!(
            (MouseMoveEvent ev) {
                auto mouseover = hasMouseover(ev.pos);
                if (mouseover != st_mouseover) {
                    st_mouseover = mouseover;
                    notifyStateChanged();
                }
            },
            (MouseButtonEvent ev) {
                if ((mouseButtonBitmap & ev.buttonBitmap) != 0) {
                    st_pressed = ev.pressed;
                    notifyStateChanged();
                    handled = true;
                    if (ev.pressed) {
                        onClick.emitAsync();
                    }
                }
            }
            () {}
        ), handled;
    }
    void render (double dt) {
        auto state = st_pressed ? BtnState.Pressed : 
            st_mouseover ? BtnState.Mouseover : BtnState.Inactive;

        assert(btnRenderers[state] !is null, format("No renderer for %s! (%s)", state, this));

        btnRenderers[state].render( this, dt, timeSinceLastAction );
        timeSinceLastAction -= dt;
    }
}

public __gshared @property auto TextButton () {
    return g_slateUIMgr.instance.textButtonFactory;
}

class TextButtonFactory {
    auto wrap (T)(T x) if (isButtonLike!T) {
        return uimgr.register(new Wrapped!T( x ));
    }
    class Wrapped (T) {
        T a;

        this (T x) {
            a = x;
        }

        auto text (string dg)() {
            return a.getText = (){ return mixin(dg); }, this;
        }
        auto style (string s) {
            return a.style = s, this;
        }
        auto onClick (alias dg)() {
            return a.onClick.connect({ dg(a); }), this;
        }
        auto onClick (string dg)() {
            return a.onClick.connect({ mixin(dg); }), this;
        }
        auto get () { return a; }
    }
}


















































