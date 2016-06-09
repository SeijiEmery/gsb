module gsb.core.slateui.imui;
public import gsb.core.slateui.imui_skin;
public import gsb.core.slateui.canvas;
public import gsb.core.slateui.glcanvas;
public import gsb.core.slateui.color;
public import gl3n.linalg;
public import gl3n.math;
public import gl3n.aabb;

alias Imui = ImuiContext;
interface ImuiContext {
    //
    // Controls
    //

    // sliders:  id,    value,      min,    max
    void slider (uint*, ref double, double, double);
    void slider (uint*, ref int,    int,    int   );

    // label
    void label  (uint*, string);
    void button (uint*, string, void delegate());

    // Textfield + text area controls
    void textfield (uint*, ref string);
    void textfield (uint*, ref double);
    void textfield (uint*, ref float);
    void textfield (uint*, ref uint);
    void textfield (uint*, ref int);
    void textarea  (uint*, ref string);

    // List / enum selection
    void dropdown (Enum)(uint*, ref Enum);
    //auto dropdown (K,V,R)(uint*, R) -> K if (isRangeOf!(R,Tuple!(K,V)));

    // Spacing
    void spacer (double);

    //
    // Layout
    //

    // Basic vertical / horizontal layout
    void vertical   (void delegate());
    void horizontal (void delegate());
    void flip       (void delegate());

    // and manual setters
    bool setVertical   ();
    bool setHorizontal ();
    void setFlipped    ();

    // Creates a frame (freestanding window), or panel (frame/panel subdivision)
    // with a title, and which can be moved/resized (frame), or minimized (all).
    void frame (uint*, string, void delegate());
    void panel (uint*, string, void delegate());

    // Create a 2d / opengl canvas. Canvas includes drawing operations, information
    // about frame time + resolution, etc
    void canvas   (uint*, vec2i, void delegate(SCanvas));
    void glcanvas (uint*, vec2i, void delegate(GlCanvas));


    //
    // Skinning
    //

    // Set skin for a single control, or as a default skin within a block
    void setSkin (uint*, ImSkin);
    void setSkin (ImSkin, void delegate());

    //
    // Callbacks, etc
    //
    void onHoverEnter (uint*, void delegate());
    void onHoverExit  (uint*, void delegate());
}





