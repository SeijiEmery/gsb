module gsb.utils.sampler;


struct FramerateSampler (uint N = 128) {
    double[N] samples = 0;
    uint      next = 0;
    double    current = 0;

    double addSample (double dt) {
        auto sample = dt != 0 ? 1 / dt : 0;
        current += (sample - samples[next]) * (1 / cast(double)N);
        samples[next] = sample;
        next = (next + 1) % N;
        return current;
    }

    // get framerate over a given duration
    double getFramerate (double t = 1.0) const {
        double total = 0, n = 0;
        for (uint i = next; t > 0 && i --> 0; ) {
            if (samples[i] != 0) {
                total += samples[i];
                t     -= 1 / samples[i];
                ++n;
            }
        }
        for (auto i = N; t > 0 && i --> next; ) {
            if (samples[i] != 0) {
                total += samples[i];
                t     -= 1 / samples[i];
                ++n;    
            }
        }
        return n ? total / n : 0;
    }
}

unittest {
    import std.format;

    void assertEq (double a, double b, double epsilon = 1e-3, 
        string file = __FILE__, size_t line = __LINE__)
    {
        import core.exception: AssertError;
        import std.math: abs;

        if (abs(a - b) > epsilon)
            throw new AssertError(format("%s != %s!", a, b), file, line);
    }
    FramerateSampler!128 s;
    assert( s.next == 0 && s.samples[0] == 0 );

    s.addSample( 1.0 / 60 );
    assert( s.next == 1 );
    assertEq( s.current, 60.0 / 128.0 );
    assertEq( s.samples[0], 60 );
    assertEq( s.getFramerate, 60 );

    s.addSample( 1.0 / 40 );
    assertEq( s.getFramerate, 50 );

    for (auto i = 48; i --> 0; )
        s.addSample( 1.0 / 50 );
    assertEq( s.getFramerate, 50 );

    s.addSample( 1.0 / 20 );
    assertEq( s.getFramerate, 49.3878, 1e-4 );

    s.addSample( 1.0 / 20 );
    s.addSample( 1.0 / 30 );
    assertEq( s.getFramerate, 48.2979, 1e-4 );

    assertEq( s.getFramerate(1.0 / 10), 23.3333 );      // last sample: 30 fps
    assertEq( s.getFramerate(1.0 / 40), 30 );      // last 2 samples: avg(30, 20)
    assertEq( s.getFramerate(1.0 / 60), 30, 1e-3); // avg(30, 20, 20)
    assertEq( s.getFramerate(1.0 / 80), 30 );      // avg(30, 20, 20, 50)

    auto fr = s.getFramerate;
    for (auto i = 0; i < 127; ++i) {
        s.addSample(4e2);
        assert( s.getFramerate(1e5) < fr, format("%s: %s >= %s", i, s.getFramerate, fr) );
        fr = s.getFramerate(1e5);
    }
}