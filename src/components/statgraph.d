module gsb.components.statgraph;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.stats;

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




    void render (StatsCollector stats) {
        if (statsCategory !in stats.collection)
            return;
            //throw new Exception("Null category");
        auto samples = stats.collection[statsCategory].samples;
        auto collection = stats.collection[statsCategory];
        auto n = collection.samples.length;

        float getSample (size_t i) {
            auto sample = collection.samples[i].to!TickDuration.to!("msecs", float);
            return sample.isNaN || sample < 0 ? 0.0 : sample;
        }

        //float maxSample = float.max;
        //foreach (i; 0 .. collection.count)
        //    maxSample = min(maxSample, getSample(i));

        float maxSample = 1 / 30.0;
        points.length = 0;
        foreach (i; 0 .. collection.count) {
            points ~= vec2(
                pos.x + dim.x * (cast(float)i / cast(float)n),
                pos.y + 0.1 * dim.y + 0.8 * dim.y* maxSample / getSample(i));
        }
        //DebugRenderer.drawLines(points, Color("#ff2090"), 1.0, 2);

        DebugRenderer.drawLines([
            vec2(100, 100), vec2(500, 300), vec2(100, 100), vec2(20, 30)
        ], Color("#00ff00"), 20.0, 2);


        void drawLine (vec2 p1, vec2 p2, Color color) {
            DebugRenderer.drawLines([ p1, p2 ], color, 1.0, 2);
        }

        auto color = Color("#f00020");
        drawLine(pos, pos + vec2(dim.x, 0), color);  color.g += 0.2;
        drawLine(pos + vec2(dim.x, 0), pos + vec2(dim.x, dim.y), color); color.g += 0.2;
        drawLine(pos + dim, pos + vec2(0, dim.y), color); color.g += 0.2;
        drawLine(pos + vec2(0, dim.y), pos, color);

        //vec2[] box = [ pos, pos + vec2(dim.x, 0), pos + vec2(dim.x, dim.y) ];
        //DebugRenderer.drawLines(box, Color("#f00020"), 1.0, 2);

        log.write("pos = %s, dim = %s", pos, dim);


        //DebugRenderer.drawLines([
        //    vec2(pos.x, pos.y),
        //    vec2(pos.x + dim.x, pos.y),
        //    vec2(pos.x + dim.x, pos.y + dim.y),
        //    vec2(pos.x, pos.y + dim.y),
        //    //vec2(pos.x, pos.y)
        //], Color("#ff9090"), 1.0, 2);
        DebugRenderer.drawLines(points, Color("#00f020"), 1.0, 2);

        DebugRenderer.drawTri(pos, Color("#909090"), 30.0, 2.0);
        DebugRenderer.drawTri(pos + dim, Color("#909090"), 30.0, 2.0);



        //DebugRenderer.drawLines([ 
        //    vec2(pos.x,         pos.y + dim.y * (1 / 60.0) / maxSample),
        //    vec2(pos.x + dim.x, pos.y + dim.y * (1 / 60.0) / maxSample)
        //], Color("#ff9090"), 1.0, 2);
        
    }
}



class StatGraphModule : UIComponent {
    Graph graph = null;
    override void onComponentInit () {
        graph = new Graph(vec2(100, 100), vec2(400, 200));
    }   
    override void onComponentShutdown () {

    } 
    override void handleEvent (UIEvent event) {
        event.handle!(
            (FrameUpdateEvent frame) {
                graph.render();
                //graph.render(threadStats);
                //graph.render(perThreadStats["main-thread"]);
                //DebugRenderer.drawLines([ vec2(200, 200), vec2(400, 400)], Color("#ffaaaa1f"), 50.0, 1);
            },
            () {}
        );
    }
}

