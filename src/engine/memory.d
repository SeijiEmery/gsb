//module gsb.engine.memory;
//import std.typecons;
//import core.stdc.stdlib: malloc, free;
//import std.container.array;
//import std.container.binaryheap;

////auto arrayHeap (T)() { return heapify(Array!T()); }
////alias ArrayHeap(T) = typeof(arrayHeap!T());

//struct ArrayHeap (T) {
//    typeof(heapify(Array!T()))) heap;
//    alias heap this;
//    this (this) {
//        heap = heapify(Array!T());
//    }
//}

//mixin template SimpleLinkedList(T) {
//    private T* m_next = null, m_end = null;
//    @property auto next () { return m_next; }
//    @property auto end  () { return m_end; }
//    @property auto next (T* v) {
//        return m_end ?
//            m_next = v :
//            m_end = m_next = v;
//    }
//}

//immutable size_t MEMPAGE_SIZE = 1 << 24; // 16 mb

//enum Memstate { ACTIVE, FREE, CACHED, INVALID };

//struct Mempage (size_t SIZE) {
//    void* data     = null;
//    Memstate state = Memstate.FREE;
//    uint remaining = SIZE;
//    Mempage* next;

//    ~this () { release(); }
//    void release () @nogc {
//        if (data) {
//            free(data);
//            data = null;
//        }
//        if (next) {
//            next.release();
//            next = null;
//        }
//        state = Memstate.INVALID;
//    }
//    static auto allocPage () @nogc {
//        return emplace!Mempage(malloc(Mempage.sizeof),
//            malloc(SIZE));
//    }
//}
//auto append (size_t SIZE)(Mempage!SIZE* head, Mempage!SIZE* next) @nogc {
//    auto end = head;
//    while (end.next)
//        end = end.next;
//    end.next = next;
//    return head;
//}
//void* allocFrom (size_t SIZE)(Mempage!SIZE* page, size_t sz) {
//    assert(page.remaining >= sz, format("%s > %s!", sz, page.remaining));
//    auto mem = page.data + SIZE - page.remaining;
//    page.remaining -= sz;
//    return mem;
//}


//class FixedMemPool (size_t SIZE = MEMPAGE_SIZE) {
//    alias Page = Mempage!SIZE;
//    Mutex mutex;
//    Page* freeList;

//    this () {
//        mutex = new Mutex();
//    }
//    ~this () {
//        if (freeList)
//            freeList.release();
//    }
//    auto fetch () @nogc {
//        synchronized (mutex) {
//            if (freeList) {
//                auto node = freeList.next;
//                freeList = node.next;
//                node.next = null;
//                return node;
//            } else {
//                return Page.allocPage();
//            }
//        }
//    }
//    auto release (Page* pageString) @nogc {
//        assert(pageString !is null);
//        Page* end = pageString;
//        while (end.next !is null)
//            end = end.next;

//        synchronized (mutex) {
//            end.next = freeList;
//            freeList = pageString;
//        }
//    }
//}

//class PooledAllocator (size_t SIZE = MEMPAGE_SIZE) {
//    shared FixedMemPool!SIZE pool;
//    Page* nextPage;

//    this (typeof(pool) pool) {
//        this.pool = pool;
//    }
//    void* malloc (size_t sz) {
//        if (sz > MEMPAGE_SIZE)   // handle large blocks of memory with gc
//            return core.memory.GC.malloc(sz, 0u, null);

//        // otherwise, alloc from current page (and fetch new page as necessary)
//        auto page = nextPage;
//        while (page && page.remaining && page.remaining < sz)
//            page = page.next;

//        if (!page || !page.remaining)
//            page = nextPage = pool.fetch().append(nextPage);
//        return page.allocFrom(sz);
//    }
//    auto alloc (T, Args...)(Args args) {
//        return emplace(malloc(T.sizeof), args);
//    }
//    Page* cycleNext () @nogc {
//        auto page = nextPage;
//        nextPage = null;
//        return page;
//    }
//}

//alias FrameDelegate = void delegate(ref FrameContext);

//struct FrameTask {
//    FrameDelegate dg;
//    FrameTask* next;

//    uint   ctxInfo__line;
//    string ctxInfo__file;
//}
//struct FrameTaskList {
//    private PooledAllocator!MEMPAGE_SIZE allocator;
//    private FrameTask* head = null, tail = null;

//    auto ref append (uint line = __LINE__, string file = __FILE__)(FrameDelegate dg) {
//        head = allocator.alloc!FrameTask(dg, head, line, file);
//        if (!tail) tail = head;
//        return this;
//    }
//    auto ref append (const ref FrameTaskList list) {
//        if (!head) {
//            head = list.head;
//            tail = list.tail;
//        } else if (list.head) {
//            assert(tail !is null);
//            tail.next = list.head;
//            tail = list.tail;
//        }
//    }

//    private void execute (void delegate(ref FrameTask) executor)() {
//        foreach (auto node = head; node; node = node.next) {
//            try {
//                executor( *node );
//            } catch (Throwable e) {
//                throw new Exception(format("Error executing task at '%s':%d: %s",
//                    task.ctxInfo__file, task.ctxInfo__line, e));
//            }
//        }
//    }
//    private void execute ()(ref FrameContext context) {
//        execute!((ref FrameTask task) { task.dg(context); });
//    }




//    private static void executorExamples (ref FrameTaskList tasks, ref FrameContext context) {

//        // (default)
//        tasks.execute!((ref FrameTask task){
//            task.dg( context );
//        });

//        void executeWithContext (ref FrameExecutionContext fec) {
//            tasks.execute!((ref FrameTask task) {
//                fec.enterTask( task.ctxInfo__file ~ ":" ~ task.ctxInfo__line );
//                try {
//                    task.dg (fec.context);
//                } catch (Throwable e) {
//                    fec.error(task.ctxInfo__file, task.ctxInfo__line, e );
//                }
//                fec.exitTask();
//            });
//        }









//        // execute safe (default)
//        foreach (task; tasks) {
//            try {
//                task.dg(context);
//            } catch (Throwable e) {
//                throw new Exception(format("Error executing task at '%s':%d: %s",
//                    task.ctxInfo__file, task.ctxInfo__line, e));
//            }
//        }

//        // execute with context / timing info
//        foreach (task; tasks) {

//        }











//        tasks.execute!( (FrameDelegate dg) {
//            try {
//                dg(context);
//            } catch (Throwable e) {
//                throw new Exception(format("Error executing task at '%s':%d: %s",
//                    node.))
//            }
//        });



//    }


//    // executor examples:





//    private void executeSafe () {

//    }




//    private void execute (ref FrameContext context) {
//        foreach (auto node = head; node; node = node.next) {
//            try {
//                node.dg(context);
//            } catch (Throwable e) {
//                throw new Exception( format("Error executing task at '%s':%d: %s",
//                    node.ctxInfo__file, node.ctxInfo__line, e));
//            }
//        }
//    }

//    // foreach iteration impl
//    int opApply (int delegate(ref FrameTask) dg) {
//        foreach (auto node = head; node; node = node.next) {
//            auto r = dg(*node);
//            if (r) return r;
//        }
//        return 0;
//    }
//}

//struct FrameBatch {
//    FrameInfo frameInfo;
//    FrameTaskList tasks;

//    FixedMemPool!MEMPAGE_SIZE pool;
//    Mempage!MEMPAGE_SIZE* memory;

//    void execute () {
//        tasks.execute(frameInfo);
//        if (memory)
//            pool.releasePages(memory);
//    }
//}


//class FrameWorker {
//    FixedMemPool!MEMPAGE_SIZE pool;
//    PooledAllocator!MEMPAGE_SIZE allocator;
//    FrameTaskList tasks;
//    Frontend      frontend;

//    static struct Frontend {
//        FrameTaskList* tasks = null;
//        void pushTask (uint line = __LINE__, string file = __FILE__)(FrameDelegate dg) {
//            tasks.append!(line, file)(dg);
//        }
//    }

//    this (typeof(pool) pool) {
//        this.pool = pool;
//        this.allocator = new PooledAllocator!MEMPAGE_SIZE(pool);
//        this.frontend.tasks = &tasks;
//    }
//    static FrameBatch collectFrame (R)(FrameInfo info, R workers) {
//        auto batch = FrameBatch(info);
//        foreach (worker; workers) {
//            // collect tasks
//            batch.tasks.append(worker.getAndFlushTasks());

//            // collect memory
//            auto pageList = worker.allocator.cycleNext();
//            if (pageList && batch.memory) {
//                batch.memory = pageList.append(batch.memory);
//            } else if (pageList) {
//                batch.memory = pageList;
//            }
//        }
//    }
//}

















































































































