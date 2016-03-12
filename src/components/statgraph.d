module gsb.components.statgraph;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.stats;
import gsb.core.window;

import gl3n.linalg;
import gsb.core.color;
import core.time;

shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new StatGraphModule(), "statgraph", true);
    });
}

private immutable string MAIN_THREAD = "main-thread";
private immutable string GTHREAD     = "graphics-thread";
private immutable string FRAME_STATS_CAT = "frame";
private immutable int NUM_SAMPLES = 100;

private bool inBounds (vec2 pos, vec2 p1, vec2 p2) {
    return !(pos.x < p1.x || pos.x > p2.x || pos.y < p1.y || pos.y > p2.y);
}


class Graph {
    vec2 pos;
    vec2 dim;
    string statsCategory = FRAME_STATS_CAT;
    vec2[] points;

    this (vec2 pos, vec2 dim) {
        this.pos = pos;
        this.dim = dim;
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
            return max(0.0, min(1.0, 
                collection.samples[i].to!TickDuration.to!("msecs", float) * 1e-3 / maxSample));
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

        DebugRenderer.drawLines(points, color, 1.0, 4);
    }

    void render () {
        float maxSample = 1 / 60.0;

        void drawLine (vec2 p1, vec2 p2, Color color) {
            DebugRenderer.drawLines([ p1, p2 ], color, 1.0, 4);
        }

        float y = dim.y * 0.5;
        drawLine(pos + vec2(0, y), pos + vec2(dim.x, y), Color("#f0f000"));

        drawGraph(perThreadStats[MAIN_THREAD], Color("#fe5050"), 1 / 30.0);
        drawGraph(perThreadStats[GTHREAD], Color("#00f020"), 1 / 30.0);

        auto color = Color("#0050f0");

        DebugRenderer.drawLines([ 
            pos,
            vec2(pos.x + dim.x, pos.y),
            vec2(pos.x + dim.x, pos.y),
            pos + dim, 
            pos + dim, 
            pos + vec2(0, dim.y), 
            pos + vec2(0, dim.y), 
            pos 
        ], color, 1, 1);


        //drawLine(pos, pos + vec2(dim.x, 0), color);  color.g += 0.2;
        //drawLine(pos + vec2(dim.x, 0), pos + vec2(dim.x, dim.y), color); color.g += 0.2;
        //drawLine(pos + dim, pos + vec2(0, dim.y), color); color.g += 0.2;
        //drawLine(pos + vec2(0, dim.y), pos, color);
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

    float baseResizeWidth = 5.0;
    @property auto resizeWidth () {
        return g_mainWindow.screenScale.y * baseResizeWidth;
    }

    override void onComponentInit () {
        graph = new Graph(vec2(100, 100), vec2(400, 200));
    }   
    override void onComponentShutdown () {

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
            },
            (MouseButtonEvent ev) {
                if (ev.pressed && mouseover) {
                    dragging = true;
                } else if (ev.released) {
                    dragging = false;
                }
            },
            (FrameUpdateEvent frame) {
                graph.render();
            },
            () {}
        );
    }
}

