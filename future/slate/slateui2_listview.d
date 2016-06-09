module gsb.core.slate.slateui_listview;


class ListView (S, T, K) : UIObj {
    // adaptors
    S sref;
    T[] delegate(S) getList;
    K   delegate(T) getIndex;
    UIObj delegate(T) mapEach;
    void delegate(ref T, ref UIObj) doSync;

    UIObj[K]         shadowObjs;
    //Tuple!(T, UIObj)[] shadows;
    UIObj[]          shadows;

    void delegate (ListView) renderer;
    ListViewPalette          colors;

    void update (double dt) {
        // update shadows
        shadows.length = 0;
        foreach (v; getList) {
            auto k = getIndex(v);
            if (k !in shadowObjs)
                shadowObjs[k] = mapEach(v);
            
            doSync(v, shadowObjs[k]);
            shadows ~= shadowObjs[k];
            //shadows ~= tuple(v, shadowObjs[k]);
        }
        // Now we can render, handle events, etc., using shadows as a zipped
        // proxy for the contents of list.
    }

    bool handleEvent (UIEvent event) {
        foreach (kv; shadows) {
            if (kv[1].handleEvent(event))
                return true;
        }
    }
    vec2 recalcDimensions () {
        dim.x = dim.y = 0;
        foreach (kv; shadows) {
            auto ldim = kv[1].recalcDimensions();
            dim.x = max(dim.x, ldim.x);
            dim.y += ldim.y;
        }
    }
    vec2 doLayout (Layouter l) {
        l.beginRegion(this);
        foreach (kv; shadows) {
            l.advanceLayout(kv[1]);
            //if (kv[1].visible)
            //    kv[1].doLayout(l);
        }
        l.endRegion();
    }
    void render (double dt) {
        foreach (kv; shadows) {
            kv[1].render(dt);
        }
    }
}




class ListViewFactory {
    auto wrap (S, T)(S x, T v) {
        return mgr.register(new Wrapper!(S, T)(x));
    }
    class Wrapper (S, T) {
        S a;
        this (S a) {
            this.a = a;
        }

        auto get (string dg)() {
            return v.getList = (){ return mixin(dg); }, this;
        }
        auto index (string dg)() {
            return v.getIndex = (T a){ return mixin(dg); }, this;
        }
        auto each (alias dg)() {
            return v.mapEach  = dg, this;
        }
    }
}




















