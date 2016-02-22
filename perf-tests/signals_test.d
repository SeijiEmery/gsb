
module gsb.perftests.signals_test;

import gsb.core.log;
import std.datetime;
import std.algorithm.iteration: map, reduce;
import std.conv;

struct BenchmarkResults {
    double connect, disconnect, emit0, emit1, emit2, emit3;
}

auto runBenchmark (int NumSamples, int NumConnections)(void delegate(int,int) expr) {
    StopWatch sw;
    sw.start();
    for (auto i = 0; i < NumSamples; ++i) {
        for (auto j = 0; j < NumConnections; ++j) {
            expr(i, j);
        }
    }
    sw.stop();
    return cast(double)sw.peek().usecs * 1e-6 / NumSamples;
}

BenchmarkResults benchmarkPseudosignals (int NumConnections, int NumSamples) () {
    import gsb.core.pseudosignals;

    BenchmarkResults results;
    StopWatch sw;

    Signal!(int)[NumSamples] signals;
    int[NumConnections]  values;
    void delegate(int)[] callbacks;

    auto createCallback = (int i) {
        return (int x) { values[i] = i * x; };
    };
    foreach (i; 0..NumConnections) {
        callbacks ~= createCallback(i);
    }
    assert(callbacks.length == NumConnections);
    typeof(signals[0].connect(callbacks[0]))[NumConnections][NumSamples] connections;

    //log.write("NumSamples = %d, NumConnections = %d", NumSamples, NumConnections);
    //log.write("signals: %d, values: %d, callbacks: %d, connections: %d,%d",
    //    signals.length, values.length, callbacks.length,
    //    connections.length, connections[0].length);

    // emit0: 0 connections
    results.emit0 = runBenchmark!(NumSamples,NumConnections)((i, j) {
        signals[i].emit(j * 3);
    }) / NumConnections;

    results.connect = runBenchmark!(NumSamples,NumConnections)((i, j) {
        //log.write("%d, %d", i, j);
        connections[i][j] = signals[i].connect(callbacks[j]);     
    });

    // emit1: N connections
    results.emit1 = runBenchmark!(NumSamples,NumConnections)((i, j) {
        signals[i].emit(j * 3);
    }) / NumConnections;
    results.disconnect = runBenchmark!(NumSamples,NumConnections)((i, j) {
        if (j % 2 == 0)
            connections[i][j].disconnect();
    });

    // emit2: after half of all connections have been removed
    results.emit2 = runBenchmark!(NumSamples,NumConnections)((i, j) {
        signals[i].emit(j * 3);
    }) / NumConnections;

    // Clear all connections
    foreach (i; 0..NumSamples) {
        foreach (j; 0..NumConnections)
            connections[i][j].disconnect();
        signals[i].emit(0);
    }

    // emit3: no connections
    results.emit3 = runBenchmark!(NumSamples,NumConnections)((i, j) {
        signals[i].emit(j * 3);
    }) / NumConnections;
    return results;
}

BenchmarkResults benchmarkStdSignals (int NumConnections, int NumSamples) () {
    import std.signals;
    BenchmarkResults results;
    StopWatch sw;

    class Sender {
        mixin Signal!(int);
    }
    class Reciever {
        int v = 0;
        void bar (int x) { v = x; }
    }

    Sender[NumSamples] signals;
    foreach (i; 0..NumSamples)
        signals[i] = new Sender();

    Reciever[NumConnections][NumSamples] slots;
    foreach (i; 0..NumSamples)
        foreach (j; 0..NumConnections)
            slots[i][j] = new Reciever();

    // Empty signal list (no connections)
    results.emit0 = runBenchmark!(NumSamples,NumConnections)((i,j) {
        signals[i].emit(j * 3);
    }) / NumConnections;
    // Connect all slots
    results.connect = runBenchmark!(NumSamples,NumConnections)((i, j) {
        signals[i].connect(&slots[i][j].bar);
    });

    results.emit1 = runBenchmark!(NumSamples,NumConnections)((i,j) {
        signals[i].emit(j * 3);
    }) / NumConnections;
    // Disconnect half the slots
    results.disconnect = runBenchmark!(NumSamples,NumConnections)((i,j) {
        if (j % 2 == 0)
            signals[i].disconnect(&slots[i][j].bar);
    });
    results.emit2 = runBenchmark!(NumSamples,NumConnections)((i,j) {
        signals[i].emit(j * 3);
    }) / NumConnections;

    return results;
}

BenchmarkResults benchmarkPlainFuncCall (int NumConnections, int NumSamples) () {
    BenchmarkResults results;

    return results;
}


BenchmarkResults benchmarkStdSignals (size_t N) {
    BenchmarkResults results;
    StopWatch sw;
    return results;
}

void printResults (int NumConnections, int NumSamples) (BenchmarkResults r) {
    //log.write("pseudosignals -- with samples=%d, connections=%d", NumSamples, NumConnections);
    log.write("%d, %d connect:    %s", NumConnections, NumSamples, r.connect / NumSamples * 1e6 / NumConnections);
    log.write("%d, %d disconnect: %s", NumConnections, NumSamples, r.disconnect / NumSamples * 1e6 / NumConnections);
    log.write("%d, %d emit (%d):  %s", NumConnections, NumSamples, NumConnections, r.emit / NumSamples * 1e6 / 10);
    log.write("%d, %d emptyEmit:  %s", NumConnections, NumSamples, r.emptyEmit / NumSamples * 1e6 / 10);
}

void main () {
    void runBenchmark (string fcn, int n, int max_iters = 100000)() {
        BenchmarkResults[] results;
        void runWithSamples (int s)() { 
            static if (n * s < max_iters) {
                mixin("results ~= "~fcn~"!(n,s);");
                //results ~= benchmarkPseudosignals!(n,s);
            }
        }
        runWithSamples!(10);
        runWithSamples!(100);
        runWithSamples!(1000);
        runWithSamples!(10000);

        void writeResults(string field)() {
            // translation:
            // write("-- <field>: %s", results
            //   .map(format("%s (%s)", a.<field> * 1e6, a.<field> * 1e6 / n))
            //   .join(", "));

            log.write("-- %-20s %s", field~":", results
                .map!("format(\"%s (%s) µs%-10s\", a."~field~" * 1e6, a."~field~" * 1e6 / "~to!string(n)~",\"\")")
                .reduce!("a~b"));
        }
        log.write("%s %d", fcn, n);
        //log.write("-- connect: %s", results.map!("to!string(a.connect)").reduce!((a,b) => a ~ ", " ~ b));
        //log.write("-- connect: %s", joinResults!("connect"));
        writeResults!("connect");
        writeResults!("disconnect");
        writeResults!("emit0");
        writeResults!("emit1");
        writeResults!("emit2");
        writeResults!("emit3");
    }

    runBenchmark!("benchmarkStdSignals", 4);
    runBenchmark!("benchmarkStdSignals", 10);
    runBenchmark!("benchmarkStdSignals", 100);
    runBenchmark!("benchmarkStdSignals", 1000);

    runBenchmark!("benchmarkPseudosignals", 4);
    runBenchmark!("benchmarkPseudosignals", 10);
    runBenchmark!("benchmarkPseudosignals", 100);
    runBenchmark!("benchmarkPseudosignals", 1000);

    runBenchmark!("benchmarkPlainFuncCall", 4);
    runBenchmark!("benchmarkPlainFuncCall", 10);
    runBenchmark!("benchmarkPlainFuncCall", 100);
    runBenchmark!("benchmarkPlainFuncCall", 1000);
}






























