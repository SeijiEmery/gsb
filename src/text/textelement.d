
module gsb.text.textelement;
import gsb.text.textrenderer;
import gsb.text.font;
import gsb.core.color;
import gl3n.linalg;

import std.container.rbtree;

class TextFragment {
    // Double buffered so we can operate on (frontend ui code) and render
    // (backend text renderer) simultaneously
    struct State {
        string text;
        Font   font;
        Color  color;
        vec2   position;
    }
    private   State fstate; // frontend state
    protected State bstate; // backend / renderer state
    protected bool  dirtyState = true;
    private bool dirtyBounds = true;
    vec2   cachedBounds;

    this (string text, Font font, Color color, vec2 position) {
        fstate.text = text;
        fstate.font = font;
        fstate.color = color;
        fstate.position = position;
        /*TextRenderer.addFragment(this);*/
    }
    void attach () { /*TextRenderer.addFragment(this);*/ }
    void detatch () { /*TextRenderer.removeFragment(this);*/ }
    ~this () { detatch(); }

    protected bool updateBackendState () {
        if (dirtyState) {
            synchronized { bstate = fstate; dirtyState = false; }
            return true;
        }
        return false;
    }
    public void forceUpdate () {
        synchronized { dirtyState = true; }
    }

    @property auto text () { return fstate.text; }
    @property void text (string v) { 
        synchronized { fstate.text = v; dirtyState = true; dirtyBounds = true; }
    }
    @property auto font () { return fstate.font; }
    @property void font (Font v) {
        synchronized { fstate.font = v; dirtyState = true; dirtyBounds = true; }
    }
    @property auto color () { return fstate.color; }
    @property void color (Color v) {
        synchronized { fstate.color = v; dirtyState = true; }
    }
    @property auto position () { return fstate.position; }
    @property void position (vec2 v) {
        synchronized { fstate.position = v; dirtyState = true; }
    }
    @property auto bounds () {
        synchronized { return dirtyBounds ? cachedBounds : calcBounds(); }
    }
    private auto calcBounds () {
        dirtyBounds = false;
        return cachedBounds = fstate.font.calcPixelBounds(fstate.text);
    }
}

//struct TextRenderer {
//    public static __gshared TextRenderer.Instance instance;

//    struct Instance {
//        auto fragments = new RedBlackTree!TextFragment();
//        auto drawnFragments = new RedBlackTree!TextFragment();

//        void updateFromMainThread () {
//            foreach (fragment; fragments) {
//                if (fragment.updateBackendState()) {
//                    // needs update
//                }
//            }

//        }
//    }
//}

















































