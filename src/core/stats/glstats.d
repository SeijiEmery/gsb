
module gsb.glstats;
import gsb.core.singleton;
import gsb.core.engineutils;
import gsb.utils.signals;
import gsb.utils.logging.tags;   // we're reusing the new logger tagging subsystem here for nested stat categories
import gsb.core.log;
import std.range;
import std.container.rbtree;
import std.array;

private ThreadLocalTagTracker stats_localTags;
private immutable size_t NUM_SAMPLES = 256;

@property auto allStats () {
    return GlobalStatsCollector.instance;
}
ThreadLocalStatsCollector threadStats = null;

void setupThreadStats (string name) {
    assert(!threadStats);
    GlobalStatsCollector.instance.registerCollector(name, 
        threadStats = new ThreadLocalStatsCollector());
}

//
// Main logging api
//

void timedCall (ThreadLocalStatsCollector collector, string name, void delegate() expr) {
    import std.datetime;
    import std.conv;

    stats_localTags.push(name);
    StopWatch sw; sw.start(); expr(); sw.stop();
    stats_localTags.pop(name);

    collector.logFrame(stats_localTags.getTags() ~ name, sw.peek().to!("msecs", float));
}

void logStat (ThreadLocalStatsCollector collector, string name, float value) {
    collector.logFrame(stats_localTags.getTags() ~ name, value);
}

//
// Global read-only api
//

private class GlobalStatsCollector {
    mixin LowLockSingleton;

    private ThreadLocalStatsCollector[string] registeredCollectors;

    protected void registerCollector (string name, ThreadLocalStatsCollector collector) {
        registeredCollectors[name] = collector;
    }

    string[] getSampleKeys () {
        RedBlackTree!string keys;
        foreach (k, v; registeredCollectors) {
            foreach (key; v.getKeys())
                keys.insert(key);
        }
        return keys.array();
    }

    float[] getSamples (string threadKey, string key, uint n) {
        if (threadKey !in registeredCollectors)
            throw new Exception(format("No matching thread / collector for '%s'", threadKey));
        return registeredCollectors[threadKey].getSamples(key, n);
    }

    void iterSamples (string threadKey, uint n, 
        bool delegate(string, string[]) filter, 
        void delegate(string, string[], float[]) visit
    ) {
        if (threadKey !in registeredCollectors)
            throw new Exception(format("No matching thread / collector for '%s'", threadKey));
        registeredCollectors[threadKey].iterSamples(n, filter, visit);
    }
}

//
// Stats implementation
//

private class ThreadLocalStatsCollector {
    StatsCollection collection;
    uint currentFrame = 0;
    ISlot slot;

    this () {
        collection.onFrameBegin(currentFrame);
        slot = gsb_onFrameBegin.connect({
            collection.onFrameBegin(++currentFrame);
        });
    }
    ~this () {
        slot.disconnect();
    }

    protected void logFrame (string[] context, float value) {
        collection.addStat(currentFrame, context, value);
    }
    auto getSamples (string key, uint n) {
        return collection.getSamples(key, currentFrame, n);
    }
    auto getKeys () { return collection.getKeys(); }
    void iterSamples (uint n, bool delegate(string, string[]) filter, void delegate(string, string[], float[]) visit) {
        return collection.iterSamples(currentFrame, n, filter, visit);
    }
}


private struct StatsCollection {
    struct SC {
        float[NUM_SAMPLES] _backingArray;
        typeof(cycle(_backingArray)) samples;
    
        this (this) {
            samples = cycle(_backingArray);
        }

        void add (uint frame, float value) {
            samples[frame] += value;
        }
        void resetFrame (uint frame) {
            samples[frame] = 0;
        }
    }
    private SC[string] stats;

    void addStat (uint frame, string key, float value) {
        if (key !in stats) {
            stats[key] = SC();
            stats[key].resetFrame(frame);
            //onStatsCategoryCreated.emit(key, this);
        }
        stats[key].add(frame, value);
    }
    void addStat (uint frame, string[] context, float value) {
        for (auto i = 1; i < context.length; ++i) {
            addStat(frame, context[0..i].join("."), value);
        }
    }
    float[] getSamples (string key, uint frame, uint n) {
        if (key !in stats) {
            throw new Exception("Invalid stats category: %s", key);
        }
        return stats[key].samples[ frame - n .. frame ].array();
    }
    void onFrameBegin (uint frame) {
        foreach (k, v; stats) {
            stats[k].resetFrame(frame);
        }
    }
    protected string[] getKeys () {
        return stats.keys();
    }

    void iterSamples (uint n, uint frame, 
        bool delegate(string, string[]) filter, 
        void delegate(string, string[], float[]) visit
    ) {
        foreach (k; stats.keys()) {
            auto parts = k.split(".");
            auto name = parts[$-1], cat = parts[0..$-1];
            if (filter(name, cat)) {
                visit(name, cat, getSamples(k, frame, n));
            }
        }
    }
}

