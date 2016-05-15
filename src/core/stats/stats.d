
module gsb.core.stats;
import gsb.core.log;
import gsb.utils.signals;

import core.time;
import std.datetime;
import std.conv;

private immutable size_t NUM_SAMPLES = 256; // num frames retained

StatsCollector threadStats = null;
__gshared StatsCollector[string] perThreadStats;

void setupThreadStats (string name) {
    perThreadStats[name] = threadStats = new StatsCollector();
}

class StatsCollector {
    SampleCollection[string] collection;
    struct SampleCollection {
        Duration[NUM_SAMPLES] samples;
        size_t next = 0, count = 0;

        private void addSample (Duration sample) {
            samples[next] = sample;
            if (++next >= NUM_SAMPLES)
                next = 0;
            if (count < NUM_SAMPLES)
                ++count;
        }
    }
    Signal!(string) onCollectionRegistered;

    void logFrame (string name, Duration sample) {
        if (name !in collection)
            createCollection(name);
        collection[name].addSample(sample);
        //log.write("collection.length = %d", collection.length);
        //log.write("Set sample: %s, %s", name, sample);
    }
    private void createCollection (string name) {
        assert(name !in collection);
        collection[name] = SampleCollection();
        onCollectionRegistered.emit(name);
    }
 
    struct CallTime {
        string name;
        Duration time;
    }
    private CallTime[] getAvgCallTime (uint samples) {
        CallTime[] times;
        foreach (k, v; collection) {
            Duration total;
            foreach (i; 0 .. v.next)
                total += v.samples[i];
            if (v.count > v.next)
                foreach (i; (NUM_SAMPLES - (v.count - v.next)) .. NUM_SAMPLES)
                    total += v.samples[i];
            times ~= CallTime(k, total / v.count);
        }
        import std.algorithm.sorting;
        times.sort!"a.time > b.time"();

        return times;
    }
}

void timedCall (StatsCollector collector, string name, void delegate() expr) {
    StopWatch sw;
    sw.start(); 
    expr();
    sw.stop();
    collector.logFrame(name, to!Duration(sw.peek()));
}

void dumpStats (StatsCollector collector, uint samples = 100) {
    foreach (t; collector.getAvgCallTime(100)) {
        log.write("%0.2f ms %s", t.time.to!TickDuration.to!("msecs", float), t.name);
    }
}

private uint framesSinceUpdate = 0;
void dumpAllStats (uint samples = 100) {
    if (framesSinceUpdate > samples)
        framesSinceUpdate = 0;

    if (framesSinceUpdate++ == 0) {
        foreach (k, v; perThreadStats) {
            log.write("%s stats:", k);
            dumpStats(v, samples);
        }
    }
}
