
struct ShaderEntry {
    mixin slateui_listelem!string;   // declares that ListView index type is string and injects ListView state
    mixin slateui_buttonstate;       // injects TextButton state
    string name, path;
}
private ShaderEntry[] scanFiles () {}


class ShadertoyUI {
    ShaderEntry[] files;

    void setupUI () {
        auto stStyle = Slate.style();

        auto listView = ListView.wrap(this).get!"a.files"
            .index!"a.name"
            .each!((ShaderEntry entry) {
                return TextButton.wrap(entry)
                    .text!"a.name"
                    .style("button")
                    .onClick!((ShaderEntry self) {
                        loadShader(self.path);
                    });
            });

        auto pane = new Panel()
            .slateid("shadertoy-rootpane")
            .stylesheet(stStyle) .draggable(true) .serialize(true)
            .children([
                new TextLabel("-- shadertoy --").style("T1"),
                listView
            ]);


        auto moreComplex = TreeView.wrap(someDataStructure)
            .index!"a.index_value"
            .
    }
}


class ColorTestUI {
    vec4 color_rgba;

    static auto rgba_to_husl () {}

    interface IColorAdaptor {
        void   setComponent (string c)(double v);
        double getComponent (string c)();
    }
    class ColorAdaptor (alias toRgba, alias fromRgba) : IColorAdaptor {
        void setComponent (string c)(double v) {
            auto a = fromRgba(color_rgba);
            mixin(`a.`~c~` = v`);
            color_rgba = toRgba(a);
        }
        double getComponent (string c)() {
            auto a = fromRgba(color_rgba);
            return mixin(`a.`~c);
        }
    }

    //class ColorAdaptor {
    //    //vec4 inComponents, outComponents, lastColor;
    //    vec4 function(vec4) toRgba, fromRgba;

    //    this (vec4 function(vec4) toRgba, vec4 function(vec4) fromRgba) {
    //        this.toRgba = toRgba;
    //        this.fromRgba = fromRgba;
    //        //inComponents = outComponents = fromRgba(color_rgba);
    //    }
    //    //void presync () {
    //    //    if (outComponents != inComponents)
    //    //        color_rgba = lastColor = toRgba(outComponents);
    //    //}
    //    //void postsync () {
    //    //    if (lastColor != color_rgba) {
    //    //        inComponents = outComponents = fromRgba(
    //    //            lastColor = color_rgba );
    //    //    }
    //    //}
    //    void setComponent (string c)(double v) {
    //        auto a = fromRgba(color_rgba);
    //        mixin(`a.`~c~` = v`);
    //        color_rgba = toRgba(a);
    //    }
    //    void getComponent (string c)(double v) {
    //        auto a = fromRgba(color_rgba);
    //        return mixin(`a.`~c);
    //    }
    //}
    //IColorAdaptor[] adaptors;

    double getComponent (string c, alias fromRgba)() {
        auto a = fromRgba(color_rgba);
        return mixin(`a.`~c);
    }
    double setComponent (string c, alias fromRgba, alias toRgba)(double v) {
        auto a = fromRgba(color_rgba);
        mixin(`a.`~c~` = v`);
        color_rgba = toRgba(a);
        return v;
    }

    void setupUI () {
        auto createSliders (alias fromRgba, alias toRgba)( UISliderRenderer renderer
            //IColorAdaptor adaptor
        ) {
            //adaptors ~= adaptor;
            //auto createSlider (string component)(double minv, double maxv) {
            //    return UISlider.wrapped!double()
            //        .minval(minv) .maxval(maxv)
            //        .get(()         => adaptor.getComponent!component())
            //        .set((double v) => adaptor.setComponent!component());
            //}

            auto createSlider (string c)(double minv, double maxv) {
                return UISlider.wrapped!double()
                    .minval(minv) .maxval(maxv) .renderer(renderer)
                    .get(()         => getComponent!(c, fromRgba))
                    .set((double v) => setComponent!(c, fromRgba, toRgba));
            }
            return [
                createSlider!"x"(0, 1),
                createSlider!"y"(0, 1),
                createSlider!"z"(0, 1),
                createSlider!"w"(0, 1),
            ];
        }

        //auto rgb_sliders  = createSliders(new ColorAdaptor!( (a) => a, (a) => a ));
        //auto husl_sliders = createSliders(new ColorAdaptor!( rgb_to_husl, husl_to_rgb ));
        //auto hsl_sliders  = createSliders(new ColorAdaptor!( rgb_to_hsl,  hsl_to_rgb ));
        auto rgb_sliders  = createSliders!( (a) => a, (a) => a );
        auto husl_sliders = createSliders!( rgb_to_husl, husl_to_rgb );
        auto hsl_sliders  = createSliders!( rgb_to_hsl,  hsl_to_rgb  );
    }
}




























































