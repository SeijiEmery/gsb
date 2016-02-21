
module gsb.core.pseudosignals;

import gsb.core.log;

// Custom signals/slots, b/c std.signals sucks.
//
// Not a pure qt/boost implementation, but a reinterpretation of the signals/slots / observer
// pattern based around connecting function closures / variables instead of class methods
// (std.signals is class based, but it's ugly-as-fuck and has to be implemented as a template
//  mixin (wtf?!)).
//
// Usage is:
//   Signal!(types...) mySignal;                           // declare signal
//   auto conn = mySignal.connect(some-func-closure);      // connect function (returns a handle, so we can disconnect)
//   mySignal.emit(some-values);                           // emit signal
//   conn.disconnect();                                    // disconnect function
//
// This implementation is a bit unorthodox (sig.connect returns a handle object, which you
// then call disconnect() on), but it does have the following perks:
// – the implementation is dead-simple
// – it works with anonymous function closures (std.signals does not, assuming you want to connect an
//   anonymous function w/ no references and still be able to disconnect it later)
// - disconnect() is O(1), and does not involve list traversal; emit() uses one pass to both fire
//   connected slots and lazily remove disconnected slots.
// – performance at this point is completely unknown; it's probably worse than the boost/qt
//   implementations. There's some tricks I could do to improve theoretical cache performance
//   (store connectedSlots in a fixed size array at some cache-friendly size, and extend as a
//   linked list iff connections exceed bounds (edge case; very unlikely to be hit for our use case)).
//   However, this is probably irrelevant since signal performance will likely have next to no impact
//   on runtime performance:
//   – Signals don't have many connections (typically, like 4?)
//   – Events are mostly processed on the main / event thread, which underutilized anyways
//     (ie. divorced from both gl calls (graphics thread), and heavy workloads (worker thread(s)))
//
struct Signal(T...) {
    private Slot!T[] connectedSlots;

    auto connect (void delegate(T) cb) {
        auto slot = new Slot!T(cb);
        connectedSlots ~= slot;
        //log.write("Signal %s connecting slot: %s", cast(void*)&this, cast(void*)&(slot.cb));
        return slot;
    }
    void emit (T args) {
        // Iterate over connected slots, firing active slots and removing those that are inactive.
        for (auto i = connectedSlots.length; i --> 0; ) {
            if (!connectedSlots[i].active) {
                //log.write("Signal %s disconnecting slot: %s", cast(void*)&this, cast(void*)&(connectedSlots[i].cb));
                connectedSlots[i] = connectedSlots[$-1];
                connectedSlots.length--;
            } else {
                //log.write("Signal %s emitting signal to %s", cast(void*)&this, cast(void*)&(connectedSlots[i].cb));
                connectedSlots[i].cb(args);
            }
        }
    }
    void disconnectAll () {
        connectedSlots.length = 0;  // uh... I guess this should work? D's array semantics are wierd...
    }

    // Slot / connection handle, implemented as a class b/c we want reference semantics (alternative
    // would be a refcounted struct). Wraps a function callback and connection state; shared between
    // the signal's connectedSlots list, and the (maybe) stored return from connect() (and whatever
    // the user does with it)
    class Slot(T...) {
        void delegate (T) cb;
        bool active = true;

        this (typeof(cb) cb) {
            this.cb = cb;
        }
        void disconnect () {
            //log.write("Disconnecting %s", cast(void*)this);
            active = false;
        }
    }

    unittest {
        // Basic test: create signal, and test connect/disconnect/emit
        Signal!(int) someSignal;
        int foo = 0;
        int bar = 0;

        auto c1 = someSignal.connect((int x) {
            foo = x;
        });
        auto c2 = someSignal.connect((int y) {
            bar = y;
        });

        someSignal.emit(4);
        assert(foo == 4 && bar == 4);

        c2.disconnect();
        someSignal.emit(5);
        assert(foo == 5 && bar == 4);

        auto c3 = someSignal.connect((int y) {
            bar = -y;
        });
        someSignal.emit(8);
        assert(foo == 8 && bar == -8);

        c1.disconnect();
        someSignal.emit(9);
        assert(foo == 8 && bar == -9);

        c3.disconnect();
        someSignal.emit(10);
        assert(foo == 8 && bar == -9);

        auto c4 = someSignal.connect((int x) {
            foo = bar = x;
        });
        someSignal.emit(11);
        assert(foo == 11 && bar == 11);

        c4.disconnect();
        someSignal.emit(12);
        assert(foo == 11 && bar == 11);

        // Test 2: connect 100 signals, and test emit + disconnectAll()
        auto values = new int[100];
        auto createClosure = (int i) {           // necessary so closures don't all capture the same i variable
            return (int x) { values[i] = x; };
        };
        for (auto i = 0; i < 100; ++i) {
            someSignal.connect(createClosure(i));

            //someSignal.connect((int x) {       // this yields 'values[100] = x' 100 times
            //    log.write("Setting values[%d] = %d", k, x);
            //    values[k] = x;
            //});
        }
        someSignal.emit(1);
        foreach (v; values) {
            assert(v == 1);
        }
        someSignal.disconnectAll();
        someSignal.emit(4);
        foreach (v; values) {
            assert(v == 1);
        }

        // Test 3: reconnect 100 signals; test pseudo-random connection / disconnection
        auto createClosure2 = (int i) {
            return (int x) { values[i] = x + i * 2 + 3; };
        };
        auto createClosure3 = (int i) {
            return (int x) { values[i] = x * 3 + i / 2 + 7; };
        };

        typeof(someSignal.connect(createClosure(1)))[] connections;
        for (auto i = 0; i < 100; ++i) {
            connections ~= someSignal.connect(i % 3 == 0 ?
                createClosure2(i) :
                createClosure3(i));
        }

        someSignal.emit(1);
        for (auto i = 0; i < 100; ++i) {
            assert(values[i] == (i % 3 == 0 ?
                1 + i * 2 + 3 :
                1 * 3 + i / 2 + 7
            ));
        }

        for (auto i = 0; i < 100; ++i) {
            if ((i + 4) % 7 > 3) {
                connections[i].disconnect();
                connections[i] = someSignal.connect(createClosure(i));
            }
        }
        someSignal.emit(4);
        for (auto i = 0; i < 100; ++i) {
            assert((i + 4) % 7 > 3 ?
                values[i] == 4 :
                values[i] == (i % 3 == 0 ?
                    4 + i * 2 + 3 :
                    4 * 3 + i / 2 + 7));
        }
    }
}