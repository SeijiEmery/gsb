module gsb.core.slateui.imui_impl;
import gsb.core.slateui.imui;
import std.typecons:  Tuple, tuple;
import std.exception: enforce;
import std.format;
import gl3n.math;
import gl3n.aabb;


class ImuiInstance : ImuiContext {
private:
    //
    // Internal state
    //
    uint m_nextId = 1;

    // panes + retained state
    ImPane[uint] m_panes;

    // ui skins
    ImSkin[] m_skinStack;  // default skins (pushed/popped by setSkin)
    ImSkin[uint] m_skins;

    // callbacks
    Tuple!(uint, void delegate())[] m_hoverEnterActions;
    Tuple!(uint, void delegate())[] m_hoverExitActions;

    // "allocates" an id for use within this imui instance. Returns 0 for null, or
    // [1,uint.max) otherwise. Assigns new id iff *id == 0 (uninitialized).
    auto allocId (uint* id) {
        assert(m_nextId != uint.max, format("id overflow (%s): %s", id, this));
        if (id is null)
            return 0;    // ignore null (ids are usually optional), and return 0

        // Otherwise, either just return the id (existing), or alloc a new one (was zero)
        return *id ? *id : *id = m_nextId++;
    }

public:
    //
    // Imui Private API (used by gsb internals)
    //

public:
    //
    // Imui Public API (used by client / frontend; matches everything declared in ImuiContext)
    //
    void slider (uint* id, ref double value, double minValue, double maxValue) {

    }
    void label  (uint* id, string slabel) {

    }
    void button (uint* id, string slabel, void delegate() onClick) {

    }
    void spacer (double pixels) {

    }
    void rect   (uint* id, vec2i dim, SColor color) {

    }

    bool setVertical   () { return false; }
    bool setHorizontal () { return false; }
    void setFlipped    () {}

    void vertical (void delegate() block) {
        auto changed = setVertical();
        block();
        if (changed) setHorizontal();
    }
    void horizontal (void delegate() block) {
        auto changed = setHorizontal();
        block();
        if (changed) setVertical();
    }
    void flip (void delegate() block) {

    }


    void pane (uint* id, string name, void delegate() inner) {
        enforce(allocId(id), format("null id (panel name '%s')", name));
        m_panes[*id] = ImPane(*id, name, inner, m_skinStack[$-1]);
    }

    void setSkin (uint* id, ImSkin skin) {
        enforce(id !is null, "null id");
        m_skins[allocId(id)] = skin;
    }
    void setSkin (ImSkin skin, void delegate() block) {
        m_skinStack ~= skin;
        block();
        m_skinStack.length--;
    }

    void onHoverEnter (uint* id, void delegate() cb) {
        if (allocId(id))
            m_hoverEnterActions ~= tuple(*id, cb);
    }   
    void onHoverExit  (uint* id, void delegate() cb) {
        if (allocId(id))
            m_hoverExitActions  ~= tuple(*id, cb);
    }


    // unimplemented
    void slider (uint*, ref int, int, int) {}
    void textfield (uint*, ref string) {}
    void textfield (uint*, ref double) {}
    void textfield (uint*, ref float) {}
    void textfield (uint*, ref uint) {}
    void textfield (uint*, ref int) {}
    void textarea (uint*, ref string) {}

    void dropdown (Enum)(uint*, ref Enum) {}
    void frame (uint*, string, void delegate()) {}
    void panel (uint*, string, void delegate()) {}
    void canvas (uint*, vec2i, void delegate(SCanvas)) {}
    void glcanvas (uint*, vec2i, void delegate(GlCanvas)) {}
}

struct ImPane {
    this (uint id, string name, void delegate() inner, ImSkin defaultSkin) {

    }
}



