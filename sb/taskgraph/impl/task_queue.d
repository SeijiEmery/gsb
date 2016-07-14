module sb.taskgraph.impl.task_queue;
import sb.taskgraph.impl.task;
import core.sync.mutex;
import core.atomic;
import std.format;

private immutable size_t SEGMENT_SIZE = 256;
private class Segment (Task) {
    // Internal state used by TaskQueue
    Segment!Task next = null;
    uint         id   = 0;

    this (uint id) { this.id = id; }

    // Task range indices.
    //  next_insert: head insert index. May be atomically incremented or reset to 0, but not decremented.
    //  acquired:    number of tasks that have been acquired by fetchTask; used to detect when segment 
    //       may be dropped/recycled, and when to update the fetch_head hint.
    //  fetch_head:  hint indicating the _minimum_ index to start searching for items with fetchTask()
    //       (all items before this will be skipped). Added for efficiency's sake: searching through
    //       [0, next_insert) is perfectly valid, but inefficient; if we can __guarantee__ that all items
    //       up to N have been acquired, then it's obviously more efficient to just search [N, next_insert),
    //       where N <= next_insert.
    //  
    shared uint next_insert = 0, acquired = 0, fetch_head = 0;

    @property auto remainingInserts () { return SEGMENT_SIZE - next_insert; }
    @property auto remainingFetches () { 
        assert(next_insert >= acquired);
        return next_insert - acquired; 
    }
    void reset () {
        atomicStore(fetch_head, 0);
        atomicStore(next_insert, 0);
        atomicStore(acquired, 0);
        next = null;
    }

    // Task storage
    Task[SEGMENT_SIZE] items;

final:
    /// Return if taskqueue can advance segment (no remaining insertions or fetches available)
    bool canAdvance () {
        return next_insert >= SEGMENT_SIZE && acquired >= SEGMENT_SIZE;
    }
    /// Returns true iff segment is filled and all tasks have been acquired and run;
    /// signals to the taskqueue that this segment can be recycled with reset().
    bool canDiscard () {
        if (!canAdvance)
            return false;
        foreach (task; items)
            if (!task.finished)
                return false;
        return true;
    }

    /// Try inserting a task. Succeeds iff capacity, etc.,
    auto insertTask (Task item) {
        uint ins;

        // Acquire index
        do {
            ins = atomicLoad(next_insert);
            if (ins >= SEGMENT_SIZE)
                return null;
        } while (!cas(&next_insert, ins, ins+1));

        // And write task
        items[ins] = item;

        // return pointer iff struct or value (reference?) otherwise
        static if (is(Task == struct))
            return &(items[ins] = item);
        else
            return items[ins] = item;
    }

    /// Try fetching a task to execute, finding the next available task that
    /// fullfills pred(task) and can be aquired using task.tryClaim.
    /// Returns either a pointer to a Task (if successful) or null (segment is empty 
    /// or pred did not match any tasks). 
    ///
    auto fetchTask () {
        auto fetchRange (uint start, uint end) {
            for (auto i = start; i < end; ++i) {
                if (items[i].unclaimed && items[i].tryClaim) {

                    // Update acquire count and fetch_head
                    auto count = atomicOp!"+="(acquired, 1);

                    // If our acquire count matches our insert count, meaning that
                    // we're guaranteed NOT to have any claimable items before this one,
                    // then update our next_take hint so that all previous items are skipped.
                    //
                    // if (count == next_insert) fetch_head = i;
                    while (
                        count == atomicLoad(next_insert) &&
                        !cas( &fetch_head, fetch_head, i )) {}

                    static if (is(Task == struct))
                        return &items[i];
                    else 
                        return items[i];
                }
            }
            return null;
        }

        // Try acquiring task; this may take multiple calls to fetchRange() as
        // multiple insertions + fetches may be running concurrently, and our start
        // index (unimportant) and end index (critical!) of the task segment may be
        // changing between calls.
        auto front = fetch_head, last = next_insert;
        do {
            auto task = fetchRange(front, last);
            if (task)
                return task;

            // check insert index (may have changed while checking!)
            auto l2 = atomicLoad(next_insert);
            if (l2 == last)
                return null; // did not change

            // If did change (insertion), try checking subrange again
            front = last;
            last  = l2;
        } while (1);
    }
}

/// Implements a thread-safe N-ary producer/consumer queue.
/// The queue is implemented as a linked list of fixed-size segments
/// with separate insert (front) and fetch (back) pointers. Fetch + insert
/// operations have low overhead and are implemented purely using atomics
/// for fetch/insert within a queue segment, and use an infrequently
/// used mutex to lock for cross-segment operations (extending the 
/// queue for insertion, or advancing the fetch pointer forwards).
///
/// TaskQueue is intended to be used with SbTask (sb.taskgraph.impl.task),
/// though any compatible data structure will work, as TaskQueue/Segment
/// are parameterized by @Task.
///
/// Usage is as follows:
///  - insert() pushes a task onto the queue, and returns a pointer/reference
///    to that task (Task* if Task is a struct, or just Task otherwise).
///  - fetch() aquires a task from the queue, with exclusive access so
///    that it can be run on an arbitrary thread.
///
/// @Task must implement
///  - bool tryClaim(): try aquiring exclusive access to the task; return
///      true iff successful (task may run now, and task has not been claimed
///      by anything else); this is trivially implementable w/ a canRun check
///      (delegate, method or external state change), and an atomic CAS operation
///      on some state variable (see SbTask).
///  - bool finished(): return true iff task has been claimed and run; used
///      by TaskQueue to detect when a segment may be recycled
///  - void reset(): reset task state; called when a segment is recycled
///
/// @Task is expected to be implemented as a struct; classes will _in theory_
/// work (and there's some conditional code to handle this), but it hasn't been
/// thoroughly tested; for best results just use SbTask.
///
/// Note: the queue is infinitely resizable but may (could?) eat a large 
/// amount of memory if abused. At present all segments are retained +
/// recycled; this is an advantage as it minimizes memory allocations
/// (and if a struct is used for @Task there will be effectively zero
/// allocations in regular use, which is great for per-frame stuff),
/// but, because of this, a queue with an unbalanced insertion >>>> 
/// fetch ratio will consume an arbitrary amount of memory that cannot 
/// be freed (though this would obviously cause other problems, like a 
/// frozen app if the queue is used for anything performance critical, but the
/// underlying lesson is, if you push 10 million tasks onto a bunch of queues
/// and are memory constrained, you _won't_ get that memory back unless
/// the underlying implementation changes).
///
class TaskQueue (Task) {
    alias TaskSegment = Segment!Task;
    TaskSegment rootHead, insertHead, fetchHead;
    Mutex       segmentOpMutex;
    uint        nextId = 0;

    this () {
        rootHead = insertHead = fetchHead = new TaskSegment(nextId++);
        segmentOpMutex = new Mutex();
    }

    /// Push a task onto the queue, and return a pointer/reference to task
    /// from memory in a queue segment (returns a Task* iff @Task is a struct,
    /// or just Task otherwise).
    auto insertTask (Task task) {
        auto acquireSegment () {
            // Recycle segment from head of queue iff a) we're totally done with that segment,
            // and b) that segment is not the only segment; otherwise, just alloc a new
            // segment.
            auto head = rootHead;
            if (head.next && head != fetchHead && head.canDiscard) {
                rootHead = head.next;
                head.reset();
                return head;
            }
            return new TaskSegment(nextId++);
        }

        auto head = insertHead; // save head ref -- insertHead is shared + mutable!

        // Try inserting into insert head (may fail w/ null if insert head is full).
        auto tref = head.insertTask(task);
        if (tref) return tref;
        else {
            // If head is full, add a new segment to serve as the new insert head.
            synchronized (segmentOpMutex) {
                // But check that other threads haven't added one first!
                if (insertHead == head) {
                    insertHead.next = acquireSegment();
                    insertHead = insertHead.next;
                }
                head = insertHead;   
            }

            // Insert our task into the new insert head. 
            // This should NEVER fail, as the new head should be effectively empty; 
            // if it does, either some really wierd shit is going on with the threads + 
            // mutex locking or SEGMENT_SIZE is set waaaay to low (< num threads, for instance).
            auto taskRef = head.insertTask(task);
            assert(taskRef !is null);
            return taskRef;
        }
    }
    /// Fetch the next available task from the queue as a reference (Task* iff @Task
    /// is a struct); returns null if none available.
    /// Note: returned task _must_ be run and cannot be put back; failure to do
    /// so will cause memory fragmentation (ie. retained, non-recyclable segments)
    /// in queue internals; to guard when a task may / may not be run, add / use a
    /// predicate in the @Task tryClaim() method.
    auto fetchTask () {
        TaskSegment head = fetchHead;
        do {
            auto task = head.fetchTask();
            if (task || !head.next)
                return task;

            if (head.canAdvance) {
                if (head == fetchHead) {
                    synchronized (segmentOpMutex) {
                        while (fetchHead.next && fetchHead.canAdvance)
                            fetchHead = fetchHead.next;
                    }
                } else head = head.next;
            } else head = head.next;
        } while (1);
    }
}

/// build + return a string dump of taskqueue's internal segment structure,
/// along with stats on the # and type of segments, and specifics like the # of
/// free insert slots (from the segments marked for insert), pending tasks
/// waiting for fetch / acquire, etc.
string dumpState (T...)(TaskQueue!T queue) {
    synchronized (queue.segmentOpMutex) {
        auto seg = queue.rootHead;
        string s;

        uint numSegments = 0;
        uint numEmptySegments = 0;
        uint numFullRunningSegments = 0;
        uint numFullAcquiringSegments = 0;
        uint numInsertingSegments = 0;

        uint numFreeInsertSlots = 0;
        uint numWaitForAcquireSlots = 0;

        while (seg) {
            auto prefix = seg == queue.insertHead ?
                (seg == queue.fetchHead ? " IF" : " I") :
                (seg == queue.fetchHead ? " F" : "");

            if (seg.canAdvance) {
                if (seg.canDiscard) {
                    s ~= format("[%d%s] ", seg.id, prefix);
                    ++numEmptySegments;
                } else {
                    s ~= format("[%d%s %d/%d] ", seg.id, prefix, seg.acquired, seg.next_insert);
                    ++numFullRunningSegments;
                }
            } else if (seg.next_insert >= SEGMENT_SIZE) {
                s ~= format("[%d%s %d/%d]", seg.id, prefix, seg.acquired, seg.next_insert);
                ++numFullAcquiringSegments;
                numWaitForAcquireSlots += (SEGMENT_SIZE - seg.acquired);
            } else {
                s ~= format("[%d%s %d/%d]", seg.id, prefix, seg.acquired, seg.next_insert);
                ++numInsertingSegments;
                numFreeInsertSlots += (SEGMENT_SIZE - seg.next_insert);
            }
            seg = seg.next;
            ++numSegments;
        }
        s ~= format("\n segment stats: %s total (%s) | %s inserting (%s free) | %s fetching (%s waiting) | %s wait-for-run | %s empty", 
            numSegments, numSegments * SEGMENT_SIZE,
            numInsertingSegments, numFreeInsertSlots,
            numFullAcquiringSegments, numWaitForAcquireSlots,
            numFullRunningSegments,
            numEmptySegments
        );
        return s;
    }
}


