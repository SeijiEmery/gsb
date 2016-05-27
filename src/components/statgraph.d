module gsb.components.statgraph;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.stats;
import gsb.core.window;
import gsb.text.textrenderer;
import gsb.text.font;
import gsb.core.ui.uielements;
import gsb.gl.algorithms: DynamicRenderer;
import gl3n.linalg;
import gsb.utils.color;
import core.time;
import std.conv;
import std.algorithm: max, min, map, reduce;
import std.format;

shared static this () {
    UIComponentManager.runAtInit({
        //UIComponentManager.registerComponent(new StatGraphModule(), "statgraph", true);
        UIComponentManager.registerComponent(new WidgetStatGraphModule(), "statgraph2", true);
    });
}

private immutable string MAIN_THREAD = "main-thread";
private immutable string GTHREAD     = "graphics-thread";
private immutable string FRAME_STATS_CAT = "frame";
private immutable int NUM_SAMPLES = 100;
private immutable string FONT = "menlo";

private bool inBounds (vec2 pos, vec2 p1, vec2 p2) {
    return !(pos.x < p1.x || pos.x > p2.x || pos.y < p1.y || pos.y > p2.y);
}

class Graph {
    vec2 pos;
    vec2 dim;
    string statsCategory = FRAME_STATS_CAT;
    vec2[] points;
    TextFragment[string] labels;

    float fontSize = 12.0;
    Color fontColor;

    this (vec2 pos, vec2 dim) {
        this.pos = pos;
        this.dim = dim;

        fontColor = Color("#fe0020");
        labels[MAIN_THREAD] = new TextFragment(MAIN_THREAD ~ "\n stuff", new Font(FONT, fontSize), fontColor, this.pos);
        labels[GTHREAD]     = new TextFragment(GTHREAD ~ "\nmore stuff", new Font(FONT, fontSize), fontColor, this.pos);
    }

    private void drawGraph (StatsCollector stats, Color color, float maxSample) {
        if (statsCategory !in stats.collection)
            return;
        auto collection = stats.collection[statsCategory];

        int s = cast(int)collection.next - NUM_SAMPLES;
        int e = cast(int)collection.next;
        int c = 256;
        //int c = cast(int)collection.count;

        //log.write("s, e, c = %d, %d, %d", s, e, c);

        auto getVal (int i) {
            if (i < 0 || i >= c)
                throw new Exception(format("Range error: %d (0, %d)", i, c));
            return max(0.0,
                collection.samples[i].to!TickDuration.to!("msecs", float) * 1e-3 / maxSample);
        }

        float[] values;
        if (s >= 0) {
            if (e <= c) {
                foreach (i; s .. e)
                    values ~= getVal(i);
            } else {
                foreach (i; s .. c)
                    values ~= getVal(i);
                foreach (i; 0 .. (c - e))
                    values ~= getVal(i);
            }
        } else {
            //log.write("[%d, %d) [%d, %d)", s + c, c, 0, e - s - c);
            foreach (i; (s + c) .. c)
                values ~= getVal(i);
            foreach (i; 0 .. e)
                values ~= getVal(i);
        }

        vec2[] points;
        foreach (i; 0 .. values.length) {
            points ~= vec2(
                pos.x + dim.x - dim.x * cast(float)i / cast(float)NUM_SAMPLES, 
                pos.y + dim.y * (-0.1 + 1.0 - 0.8 * values[i]));
            //points ~= vec2(pos.x + dim.x * cast(float)i / cast(float)NUM_SAMPLES,
            //    0);
        }

        DebugRenderer.drawLines(points, color, 0, 1);
    }

    private void drawLine (vec2 p1, vec2 p2, Color color) {
        DebugRenderer.drawLines([ p1, p2 ], color, 0, 1);
    }

    void render () {
        float maxSample = 1 / 60.0;

        float y = dim.y * 0.5;
        //drawLine(pos + vec2(0, y), pos + vec2(dim.x, y), Color("#f0f000"));

        drawGraph(perThreadStats[MAIN_THREAD], Color("#fe5050"), 1 / 30.0);
        //drawGraph(perThreadStats[GTHREAD], Color("#00f020"), 1 / 30.0);

        auto color = Color("#0050f0");

        DebugRenderer.drawLines([ 
            pos,
            vec2(pos.x + dim.x, pos.y),
            pos + dim, 
            pos + vec2(0, dim.y), 
            pos 
        ], color, 0, 1);

        updateLabels();
    }

    auto getCallStats (string cat) {
        if (cat !in perThreadStats)
            return "<None>";
        auto stats = perThreadStats[cat];

        struct CallStat { string name; float avg, max_; }
        CallStat[] callstats;

        foreach (k, v; stats.collection) {
            float total = 0.0, max_ = 0.0;
            foreach (x; v.samples) {
                float t = x.to!TickDuration.to!("msecs", float);
                total += t;
                max_  = max(max_, t);
            }
            callstats ~= CallStat(k, total / v.count, max_);
        }

        import std.algorithm.sorting;
        callstats.sort!"a.max_ > b.max_"();

        string label = cat;
        foreach (s; callstats) {
            label ~= format("\n%0.2f %0.2f %s", s.avg, s.max_, s.name);
        }
        return label;
    }

    void updateLabels () {
        auto nextPos = pos;
        immutable float LABEL_SPACING = 10.0;

        foreach (k, v; labels) {
            v.position = nextPos; nextPos.x += v.bounds.x * 1.08;
            v.text = getCallStats(k);

            // Debug lines to draw text bounds
            //auto pos = v.position / 2.0, bounds = v.bounds / 2.0;
            //drawLine(pos, pos + bounds, Color("#fe0000"));
            //drawLine(pos, pos + vec2(0, bounds.y), Color("#00fe00"));
        }
    }

    void teardown () {
        foreach (k, v; labels) {
            v.detatch();
            labels.remove(k);
        }
    }

    void setFontSize (float size) {
        auto font = new Font(FONT, fontSize = size);
        foreach (k, v; labels) {
            v.font = font;
        }
    }
}

class StatGraphModule : UIComponent {
    Graph graph = null;
    vec2 dragOffset, lastClickPosition, lastDim, dimOffset;
    bool dragging = false;
    bool mouseover = false;

    bool resizeLeft = false;
    bool resizeRight = false;
    bool resizeTop   = false;
    bool resizeBtm   = false;

    float fontSize = 32.0;

    float baseResizeWidth = 5.0;
    @property auto resizeWidth () {
        return g_mainWindow.screenScale.y * baseResizeWidth;
    }

    private bool initialized = false;

    override void onComponentInit () {
        log.write("intitializing");
        graph = new Graph(vec2(100, 100), vec2(400, 200));
    }   
    override void onComponentShutdown () {
        log.write("shutdown!");
        graph.teardown(); graph = null;
    } 


    override void handleEvent (UIEvent event) {
        event.handle!(
            (MouseMoveEvent ev) {
                if (!dragging) {
                    vec2 a = graph.pos, b = graph.pos + graph.dim;
                    auto k = resizeWidth;

                    // check graph mouseover
                    mouseover = inBounds(ev.position, a - vec2(k, k), b + vec2(k, k));
                    dragOffset = ev.position - graph.pos;
                    lastClickPosition = ev.position;
                    lastDim = graph.dim;
                    dimOffset  = ev.position + graph.dim;

                    // resize borders
                    resizeLeft  = mouseover && inBounds(ev.position, vec2(a.x - k, a.y - k), vec2(a.x + k, b.y + k));
                    resizeRight = mouseover && inBounds(ev.position, vec2(b.x - k, a.y - k), vec2(b.x + k, b.y + k));
                    resizeTop   = mouseover && inBounds(ev.position, vec2(a.x - k, a.y - k), vec2(b.x + k, a.y + k));
                    resizeBtm   = mouseover && inBounds(ev.position, vec2(a.x - k, b.y - k), vec2(b.x + k, b.y + k));

                    //if (resizeLeft) log.write("LEFT!");
                    //if (resizeRight) log.write("RIGHT!");
                    //if (resizeTop) log.write("TOP!");
                    //if (resizeBtm) log.write("BOTTOM!");
                } else {
                    if (resizeLeft) {
                        graph.dim.x = lastClickPosition.x - ev.position.x + lastDim.x;
                        graph.pos.x = ev.position.x - dragOffset.x;
                    } else if (resizeRight) {
                        graph.dim.x = ev.position.x - lastClickPosition.x + lastDim.x;
                    }
                    if (resizeTop) {
                        graph.dim.y = lastClickPosition.y - ev.position.y + lastDim.y;
                        graph.pos.y = ev.position.y - dragOffset.y;
                    } else if (resizeBtm) {
                        graph.dim.y = ev.position.y - lastClickPosition.y + lastDim.y;
                    }

                    if (!(resizeLeft || resizeRight || resizeTop || resizeBtm)) {
                        graph.pos = ev.position - dragOffset;
                    }
                }
                //label1.position = graph.pos * 2.0;
            },
            (MouseButtonEvent ev) {
                if (ev.pressed && mouseover) {
                    dragging = true;
                } else if (ev.released) {
                    dragging = false;
                }
            },
            (KeyboardEvent ev) {
                if (ev.keystr == "1" && ev.keyPressed) {
                    log.write("Setting DynamicRenderer to BASIC_DYNAMIC_BATCHED");
                    DynamicRenderer.renderer = DynamicRenderer.BASIC_DYNAMIC_RENDERER;
                } else if (ev.keystr == "2" && ev.keyPressed) {
                    log.write("setting DynamicRenderer to UMAP_DYNAMIC_BATCHED");
                    DynamicRenderer.renderer = DynamicRenderer.UMAP_BATCHED_DYNAMIC_RENDERER;
                }

                if (ev.keystr == "3" && ev.keyPressed) {
                    log.write("rebuilding graph");
                    graph.teardown();
                    graph = new Graph(graph.pos, graph.dim);
                }
            },
            (ScrollEvent ev) {
                if (mouseover)
                    graph.setFontSize(graph.fontSize + ev.dir.y);
            },
            (FrameUpdateEvent frame) {
                graph.render();
            },
            () {}
        );
    }
}



class WidgetStatGraphModule : UIComponent {
    alias GraphView = UIDecorators.Draggable!UIGraphView;

    UIElement root;    // container that holds everything else
    GraphView graph;   // direct reference to the graph element
    UILayoutContainer labels;  // container holding the graph labels (can be iterated over, etc)

    UITextElement mainThreadLabel;   // graph labels for main + graphics thread
    UITextElement graphicsThreadLabel;

    float fontSize = 18.0;

    //private float[2] RED_STATS    = [ 1 / 15.0f * 1e3, 1 / 15.0f * 1e3 ];
    private float[2] ORANGE_STATS = [ 1 / 40.0f * 1e3, 1 / 40.0f * 1e3 ];
    private float[2] YELLOW_STATS = [ 1 / 60.0f * 1e3, 1 / 60.0f * 1e3 ];
    private float[2] GREEN_STATS  = [ 1 / 120.0f * 1e3, 1 / 120.0f * 1e3 ];

    override void onComponentInit () {
        import std.range;
        import std.algorithm.iteration;

        root = new UIContainer(vec2(), vec2(), cast(UIElement[])[
            graph = new GraphView(vec2(0, 400), vec2(400, 300), [
                //UIGraphView.DataSet(Color("#fe9e2040"), () { return ORANGE_STATS; }),
                UIGraphView.DataSet(Color("#dede2040"), () { return YELLOW_STATS; }),
                //UIGraphView.DataSet(Color("#7efe7e40"), () { return GREEN_STATS; }),
                UIGraphView.DataSet(Color("#a0a0a040"), () { return [ 0.0f, 0.0f ]; }),
                UIGraphView.DataSet(Color("#fe202040"), () { return getStats(MAIN_THREAD, cast(size_t)(30 / 100.0 * graph.dim.x)); }),
                UIGraphView.DataSet(Color("#20fe2040"), () { return getStats(GTHREAD,     cast(size_t)(30 / 100.0 * graph.dim.x)); }),
            ]),
            labels = new UIDecorators.ClampedRelativeTo!UILayoutContainer(graph,
                LayoutDir.HORIZONTAL, Layout.TOP_LEFT,
                vec2(0,0), vec2(0,0), vec2(10,10), 0.0, cast(UIElement[])[
                    mainThreadLabel     = new UITextElement(vec2(),vec2(), vec2(5,5), "", new Font(FONT, fontSize), Color("#fe7efe"), Color("#7e7efe70")), 
                    graphicsThreadLabel = new UITextElement(vec2(),vec2(), vec2(5,5), "", new Font(FONT, fontSize), Color("#fe7efe"), Color("#7e7efe70")), 
                ])
        ]);
    }
    override void onComponentShutdown () {
        if (root) {
            root.release();
            root = null;
            graph = null;
        }
    }
    float[] getStats (string cat, size_t count) {
        import std.range;
        import std.algorithm.iteration;

        if (cat !in perThreadStats || "frame" !in perThreadStats[cat].collection) 
            return [];

        auto collection = perThreadStats[cat].collection["frame"];
        if (collection.count < 2 || collection.samples.length < 2)
            return [];

        return collection.samples.cycle(collection.next).take(min(collection.count, count))
            .map!((a) => a.to!TickDuration.to!("msecs", float)).array;
    }
    string getLabelText (string label, string cat) {
        if (cat !in perThreadStats)
            return label ~ "\n<None>";
        auto stats = perThreadStats[cat];

        struct CallStat { string name; float avg, max_; }
        CallStat[] callstats;

        foreach (k, v; stats.collection) {
            float total = 0.0, max_ = 0.0;
            foreach (x; v.samples) {
                float t = x.to!TickDuration.to!("msecs", float);
                total += t;
                max_  = max(max_, t);
            }
            callstats ~= CallStat(k, total / v.count, max_);
        }

        import std.algorithm.sorting;
        callstats.sort!"a.max_ > b.max_"();

        foreach (s; callstats) {
            label ~= format("\n%0.2f %0.2f %s", s.avg, s.max_, s.name);
        }
        return label;
    }


    override void handleEvent (UIEvent event) {
        if (!root)
            return;
        event.handle!(
            (FrameUpdateEvent frame) {
                mainThreadLabel.text = getLabelText("main-thread", MAIN_THREAD);
                graphicsThreadLabel.text = getLabelText("graphics-thread", GTHREAD);
                root.recalcDimensions();
                root.doLayout();

                // automatically switch labels between vertical + horizontal layouts depending on graph size
                auto maxwidth = labels.elements.map!"a.dim.x".reduce!"a+b" + labels.padding.x;
                if (labels.direction == LayoutDir.HORIZONTAL && graph.dim.x < maxwidth) {
                    labels.direction = LayoutDir.VERTICAL;
                    labels.recalcDimensions();
                    labels.doLayout();
                } else if (labels.direction == LayoutDir.VERTICAL && graph.dim.x >= maxwidth) {
                    labels.direction = LayoutDir.HORIZONTAL;
                    labels.recalcDimensions();
                    labels.doLayout();
                }
                // Lock graph dimensions to final label dimensions
                graph.dim.x = max(graph.dim.x, labels.dim.x);
                graph.dim.y = max(graph.dim.y, labels.dim.y);

                root.render(); 
            },
            (ScrollEvent scroll) {
                if (labels.mouseover) {
                    fontSize += scroll.dir.y;
                    foreach (elem; labels.elements) {
                        (cast(UITextElement)elem).fontSize = fontSize;
                        elem.recalcDimensions();
                    }
                }
                root.handleEvents(event);
            },
            () {
                root.handleEvents(event);
            }
        );
    }



}





