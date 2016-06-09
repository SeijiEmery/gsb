module gsb.utils.sampler;


struct FramerateSampler (uint N = 128) {
    double[N] samples = 0;
    uint      next = 0;
    double    current = 0;

    double addSample (double dt) {
        auto sample = dt ? 1 / dt : 0;
        current += (sample - samples[next]) * (1 / N);
        samples[next] = sample;
        next = (next + 1) % N;
        return current;
    }

    // get framerate over a given duration
    double getFramerate (double t = 1.0) const {
        double total = 0, n = 0;
        for (uint i = next; t > 0 && i --> 0; ) {
            if (samples[i]) {
                total += samples[i];
                t -= samples[i];
                ++n;
            }
        }
        for (auto i = samples.length; t > 0 && i --> next; ) {
            if (samples[i]) {
                total += samples[i];
                t -= samples[i];
                ++n;    
            }
        }
        return n ? total / n : 0;
    }
}

unittest {
    FramerateSampler s;

    void assertEq (double a, double b, double epsilon = 1e-3, 
        string file = __FILE__, size_t line = __LINE__)
    {
        import std.exception: AssertError;
        import std.math: abs;

        if (abs(a - b) > epsilon)
            throw new AssertError(format("%s != %s!", a, b), file, line);
    }

    s.addSample( 1 / 60 );
    assertEq( s.getFramerate, 60 );

    s.addSample( 1 / 40 );
    assertEq( s.getFramerate, 50 );

    for (auto i = 48; i --> 0; )
        s.addSample( 1 / 50 );
    assertEq( s.getFramerate, 50 );

    s.addSample( 1 / 20 );
    assertEq( s.getFramerate, 49.4117, 1e-4 );

    s.addSample( 1 / 20 );
    s.addSample( 1 / 30 );
    assertEq( s.getFramerate, 48.269, 1e-3 );

    assertEq( s.getFramerate(1 / 10), 1 / 30 );      // last sample: 30 fps
    assertEq( s.getFramerate(1 / 40), 1 / 25 );      // last 2 samples: avg(30, 20)
    assertEq( s.getFramerate(1 / 60), 23.333, 1e-3); // avg(30, 20, 20)
    assertEq( s.getFramerate(1 / 80), 1 / 30 );      // avg(30, 20, 20, 50)

    auto f0 = s.getFramerate, f = f0;
    for (auto i = 0; i < 127; ++i) {
        s.addSample(1e-3);
        assert( s.getFramerate < fr );
        fr = s.getFramerate;
    }
    s.addSample(1e-3);
    assert(s.framerate == 1e3);
}







