//module gsb.core.slateui.listview;

//class UIListView (S,T) : UIElement {
//    S outer;

//    this (S outer) {
//        this.outer = outer;
//    }



//}

//mixin template UIListViewFactory {
//    void listview (S,T)(S outer) {
//        class Wrapper {
//            mixin UIElementWrapper!(UIListView!(S,T));
//        }
//        return new Wrapper(new UIListView!(S,T)(outer));
//    }
//}

//private void example () {
//    struct Foo {
//        string name;
//        uint[string] ht;
//        string[] stuff;
//    }
//    class Bar {
//        Foo[] foos;
//    }

//    auto bar = new Bar();
//    bar.foos ~= Foo("blarg", {
//            "foob": 10, "barb": 12
//        }, ["foob", "barb"]);

//    import gsb.core.slateui.slider;
//    import gsb.core.slateui.list;
//    import gsb.core.slateui.slatemgr;
//    struct Slate {
//        mixin UIListViewFactory;
//        mixin UISliderFactory;
//        mixin UIListFactory;

//        mixin UIManager;
//    }
//    Slate slate;

//    auto view = slate.listview!(Foo,string)(bar) .horizontal
//        .getList!`a.foos`  // list accessor
//        .key!`a.name`      // list element key (should be unique; cannot be list index)
//        .each!((ref Foo foo){  // we call this to construct each persistent element view

//            auto label = slate.label .text(foo.name) .unwrap;
//            auto content = slate.listview!(uint,string)(foo) .vertical .border!("#4f4f4fef", "4px")
//                .getList!`a.stuff` 
//                .key!`a`
//                .each!((ref string k){
//                    return slate.slider .width!("80px")
//                        .get( ()         => foo.ht[k] )
//                        .set( (double v) => foo.ht[k] = to!int(v) )
//                        .minmax( 0, 20 ) .snap( 1.0, iota(1, 1).take(19) )
//                        .label( k )
//                        .unwrap;
//                })
//                .unwrap;

//            return slate.list.vertical
//                .children( label, content )
//                .unwrap;
//        }).unwrap;
//    //slate.relayout.render;

//    // UI should dynamically respond to the following additions/changes:
//    bar.foos ~= Foo("borg", {
//        "femme": 12, "fatale": 30
//    }, [ "fatale" ]);
//    //slate.relayout.render;

//    bar.foos[1].stuff ~= [ "femme", "femme" ];
//    //slate.relayout.render;

//    bar.foos[0].stuff = [ "barb" ];
//    //slate.relayout.render;

//    // And any/all changes are, ofc, two-way.
//    bar.foos[0].ht["barb"] = 23;
//    //slate.relayout.render;


//    //////////////////////////////
//    /// imgui
//    //////////////////////////////

//    auto view = slate.imgui.pane
//        .render((Imgui im) {
//            im.begin.horizontal;
//            foreach (foo; bar.foos) {
//                im.begin.vertical;

//                im.label(foo.name);
//                foreach (k; foo.stuff) {
//                    im.begin.horizontal;

//                    im.label(k);

//                    if (im.button("+") && foo.ht[k] < 20) ++foo.ht[k];
//                    if (im.button("-") && foo.ht[k] > 0 ) --foo.ht[k];

//                    im.slider!uint( foo.ht[k], 0, 20 )
//                        .width!"pixels"(80)
//                        .snap(2.5, [ 0, 5, 10, 15, 20 ]);

//                    im.end;
//                }

//                im.end;
//            }
//            im.end;
//        });
//}











