

class EventQueue {
public:
    struct Node {
        TypeInfo type;
        Node*    next;

        bool apply (T)(void delegate (ref T) visitor) {
            if (type == typeid(T)) {
                visitor(*cast(T*)(&(cast(Node*)(&this))[1]));
                return true;
            }
            return false;
        }
    }
private:
    import std.experimental.allocator.building_blocks.region;
    import std.experimental.allocator.building_blocks.allocator_list;
    import std.experimental.allocator.mallocator;
    import std.algorithm: max;

    static immutable size_t ALLOCATION_BLOCK_SIZE = 1024 * 1024;   // Default to 1MB

    alias PoolAllocator =  AllocatorList!(
        (size_t n) => Region!Mallocator(max(n, ALLOCATION_BLOCK_SIZE))
    );

    PoolAllocator pool;
    Node*       first = null;
    Node*       last  = null;
    size_t      count = 0;
public:
    this () {}
    
    void pushEvent (T, Args...) (Args args) if (!is(T == class)) {
        void[] mem = pool.allocate(Node.sizeof + T.sizeof);

        Node* node = cast(Node*)(&mem[0]);
        node.type = typeid(T);
        node.next = null;

        // Construct T in-place
        *cast(T*)(&node[1]) = T(args);

        // Setup linked-list stuff
        assert((first == null) == (last == null));
        assert((first == null) == (count == 0));

        if (!first) {
            first = node;
        } else {
            last.next = node;
        }
        last = node;
        ++count;
    }
private:
    //
    // Gotcha: MUST iterate using 
    //  for (ref elem; queue.range()) {
    //      ...
    //  }
    // NOT
    //  for (elem; queue.range()) {
    //      ...
    //  }
    //
    // The latter makes a copy, and the pointer-twiddling we're doing in Node.apply()
    // will not work. (will give a pointer to garbage / invalid memory instead).
    //
    struct Range {
        Node* node;

        this (Node* node) { 
            this.node = node; 
        }
        bool empty () { 
            return node == null; 
        }
        ref Node front () { 
            return *node; 
        }
        void popFront () { 
            node = node.next; 
        }
    }
public:
    Range range () { 
        return Range(first); 
    }
    bool  empty () { 
        return first == null; 
    }
    void clear () {
        first = last = null;
        count = 0;
        pool.deallocateAll();
    }
    unittest {
        import std.stdio;
        import std.format;

        struct Fubar { int bar; int baz; }
        struct BarBaz { string what; }
        struct Borg {}
        struct BarBar { int bar; int baz; }

        
        auto queue = new EventQueue();

        // Check empty
        assert(queue.empty());  
        assert(queue.range().empty());
        foreach (elem; queue.range()) {
            assert(0);
       }

        // Add 3 elements and test traversal
        queue.pushEvent!Fubar(10, 12);
        queue.pushEvent!BarBaz("hello");
        queue.pushEvent!BarBaz("world!");

        int vcount = 0;

        // 1st range test

        auto r1 = queue.range();
        assert(!r1.empty());
        assert(r1.front.apply((ref Fubar v) { assert(v.bar == 10 && v.baz == 12); ++vcount; }) == true);
        assert(r1.front.apply((ref BarBaz v) { assert(0); }) == false);
        assert(r1.front.apply((ref Borg v){ assert(0); }) == false);
        assert(r1.front.apply((ref BarBar v){ assert(0); }) == false);

        r1.popFront();
        assert(!r1.empty());
        assert(r1.front.apply((ref Fubar v) { assert(0); }) == false);
        assert(r1.front.apply((ref BarBaz v) { assert(v.what == "hello"); ++vcount; }) == true);

        r1.popFront();
        assert(!r1.empty());
        assert(r1.front.apply((ref Fubar v) { assert(0); }) == false);
        assert(r1.front.apply((ref BarBaz v) { assert(v.what == "world!"); ++vcount; }) == true);

        r1.popFront();
        assert(r1.empty());
        assert(vcount == 3);

        // 2nd range test

        auto r2 = queue.range();
        assert(!r2.empty());
        assert(r2.front.apply((ref Fubar v) { assert(v.bar == 10 && v.baz == 12); ++vcount; }) == true);
        assert(r2.front.apply((ref BarBaz v) { assert(0); }) == false);
        assert(r2.front.apply((ref Borg v){ assert(0); }) == false);
        assert(r2.front.apply((ref BarBar v){ assert(0); }) == false);

        r2.popFront();
        assert(!r2.empty());
        assert(r2.front.apply((ref Fubar v) { assert(0); }) == false);
        assert(r2.front.apply((ref BarBaz v) { assert(v.what == "hello"); ++vcount; }) == true);

        r2.popFront();
        assert(!r2.empty());
        assert(r2.front.apply((ref Fubar v) { assert(0); }) == false);
        assert(r2.front.apply((ref BarBaz v) { assert(v.what == "world!"); ++vcount; }) == true);

        r2.popFront();
        assert(r2.empty());
        assert(vcount == 6);

        // 1st range test, reapplied using for loop

        void reapplyTest1 () {
            vcount = 0;
            assert(queue.empty() == false);
            foreach (ref event; queue.range()) {
                switch (vcount++) {
                    case 0: 
                        assert(event.apply((ref Fubar v){ 
                            assert(v.bar == 10 && v.baz == 12, format("%s", v)); 
                        }) == true);
                        assert(event.apply((ref BarBaz v) { assert(0); }) == false);
                        break;
                    case 1:
                        assert(event.apply((ref Fubar v) { assert(0); }) == false);
                        assert(event.apply((ref BarBaz v) { 
                            assert(v.what == "hello", v.what); 
                        }) == true);
                        break;
                    case 2:
                        assert(event.apply((ref Fubar v) { assert(0); }) == false);
                        assert(event.apply((ref BarBaz v) { 
                            assert(v.what == "world!", v.what);
                        }) == true);
                        break;
                    default:
                        assert(0);
                }
            }
        }
        for (auto i = 0; i < 10; ++i) {
            reapplyTest1();
        }

        // Clear queue + test empty

        queue.clear();
        assert(queue.empty());
        foreach (elem; queue.range()) {
            assert(0);
        }
        // Re-add elements + re-test
        for (auto i = 0; i < 10; ++i) {
            queue.pushEvent!Fubar(10, 12);
            queue.pushEvent!BarBaz("hello");
            queue.pushEvent!BarBaz("world!");
            reapplyTest1();
            queue.clear();
        }

        // Test limits: insert + traverse 24M elements
        // Note: this is excessively large; on my machine, 1-8M is much more
        // reasonably and will run near-instantly; 24M takes several seconds.
        int n = 1024 * 1024 * 24;
        for (auto i = 0; i < n; ++i) {
            queue.pushEvent!int(i);
        }

        int outerSum = 0;
        int innerSum = 0;
        int[2] test1 = 0;
        int[2] test2 = 0;
        int[2] test3 = 0;

        int i = 0;
        foreach (ref elem; queue.range()) {
            outerSum += i;
            test1[elem.apply((ref int v){ 
                test2[i == v]++; 
                innerSum += v;
            })]++;
            test3[elem.apply((ref Fubar v) {})]++;
            ++i;
        }
        assert(test1[true] == i && test1[false] == 0, format("test1 = %s", test1));
        assert(test2[true] == i && test2[false] == 0, format("test2 = %s", test2));
        assert(test3[true] == 0 && test3[false] == i, format("test3 = %s", test3));
        assert(outerSum == innerSum, format("outer = %s, inner = %s", outerSum, innerSum));
    }
}

void main () { 
    import std.stdio;
    writefln("All tests passed."); 
}
